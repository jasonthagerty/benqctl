import QtQuick
import QtTest

import "../package/contents/ui"

// Runner executes real shell commands through Plasma's executable engine.
DdcTestCase {
    id: testCase
    name: "runner"

    Component {
        id: runnerComponent
        Runner {}
    }

    property Runner runner
    property var results: []

    function init() {
        runner = createTemporaryObject(runnerComponent, testCase);
        results = [];
    }

    // A job that records "<label>:<exit code>:<stdout>" when done.
    function job(key, command, label, extra) {
        return Object.assign({
            key: key,
            command: () => command,
            done: (exitCode, stdout) => {
                results = results.concat([`${label}:${exitCode}:${stdout.trim()}`]);
            },
        }, extra || {});
    }

    function test_runs_jobs_one_at_a_time_in_order() {
        runner.enqueue(job("a", "sleep 0.2; echo a", "a"));
        runner.enqueue(job("b", "echo b", "b"));
        runner.enqueue(job("c", "echo c", "c"));
        verify(runner.busy);
        tryCompare(testCase, "results", ["a:0:a", "b:0:b", "c:0:c"]);
        verify(!runner.busy);
    }

    function test_passes_exit_code_stdout_and_stderr() {
        let got = null;
        runner.enqueue({
            key: "x",
            command: () => "echo out; echo err >&2; exit 3",
            done: (exitCode, stdout, stderr) => got = [exitCode, stdout, stderr],
        });
        tryVerify(() => got !== null);
        compare(got, [3, "out\n", "err\n"]);
    }

    function test_drops_duplicate_queued_jobs() {
        runner.enqueue(job("busy", "sleep 0.2", "busy"));
        runner.enqueue(job("read", "echo 1", "first"));
        runner.enqueue(job("read", "echo 2", "second"));
        tryCompare(testCase, "results", ["busy:0:", "first:0:1"]);
        wait(100);
        compare(results.length, 2);
    }

    function test_replace_keeps_only_the_latest_job() {
        runner.enqueue(job("busy", "sleep 0.2", "busy"));
        for (const v of [10, 20, 30]) {
            runner.enqueue(job("write", `echo ${v}`, "write", { replace: true }));
        }
        tryCompare(testCase, "results", ["busy:0:", "write:0:30"]);
    }

    function test_cancel_drops_queued_jobs_by_prefix() {
        runner.enqueue(job("d1/busy", "sleep 0.2", "busy"));
        runner.enqueue(job("d1/read", "echo d1", "d1"));
        runner.enqueue(job("d10/read", "echo d10", "d10"));
        runner.cancel("d1/");
        tryCompare(testCase, "results", ["busy:0:", "d10:0:d10"], 5000, "running job finishes; prefix is exact");
    }

    function test_builds_command_when_job_starts() {
        let bus = 1;
        runner.enqueue(job("busy", "sleep 0.2", "busy"));
        runner.enqueue({ key: "read", command: () => `echo ${bus}`, done: (code, out) => results = results.concat([out.trim()]) });
        bus = 7; // e.g. re-detection moved the display before the job ran
        tryCompare(testCase, "results", ["busy:0:", "7"]);
    }

    function test_command_that_throws_fails_job_and_continues() {
        runner.enqueue({
            key: "bad",
            command: () => { throw new Error("no bus"); },
            done: (exitCode, stdout, stderr) => results = results.concat([`bad:${exitCode}:${stderr}`]),
        });
        runner.enqueue(job("next", "echo ok", "next"));
        tryCompare(testCase, "results", ["bad:-1:Error: no bus", "next:0:ok"]);
    }

    function test_watchdog_abandons_hung_command() {
        runner.timeout = 300;
        let stderr = "";
        runner.enqueue({
            key: "hang",
            command: () => "sleep 5",
            done: (exitCode, stdout, err) => {
                results = results.concat([`hang:${exitCode}`]);
                stderr = err;
            },
        });
        runner.enqueue(job("next", "echo ok", "next"));
        tryCompare(testCase, "results", ["hang:-1", "next:0:ok"], 3000);
        compare(stderr, "ddcutil did not respond within 0.3 seconds.");
    }

    function test_identical_commands_run_again() {
        // Each run is tagged so the engine treats repeats as new sources.
        runner.enqueue(job("one", "echo same", "one"));
        tryCompare(testCase, "results", ["one:0:same"]);
        runner.enqueue(job("two", "echo same", "two"));
        tryCompare(testCase, "results", ["one:0:same", "two:0:same"]);
    }
}
