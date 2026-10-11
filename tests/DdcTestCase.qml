import QtQuick
import QtTest

// TestCase plus what the widget expects from Plasma, and fixture loading.
TestCase {
    // Plasma injects i18n into widgets; mimic its %1-style substitution.
    function i18n(text, ...args) {
        return args.reduce((s, arg, i) => s.replace(`%${i + 1}`, arg), text);
    }

    function fixture(name) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl(`fixtures/${name}`), false);
        xhr.send();
        verify(xhr.responseText !== "", `fixture ${name} is empty or unreadable`);
        return xhr.responseText;
    }
}
