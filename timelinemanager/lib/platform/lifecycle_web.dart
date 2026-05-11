import 'dart:html' as html;

/// Web: ask the browser to confirm before the tab is closed/reloaded.
void installBeforeUnloadGuard() {
  html.window.onBeforeUnload.listen((event) {
    event.preventDefault();
    (event as dynamic).returnValue = '';
  });
}
