#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "app_links/app_links_plugin_c_api.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // The browser returns from Google sign-in by opening
  // io.github.kimhershey.gagyebu://login-callback?code=..., which Windows turns
  // into `gagyebu.exe "<url>"` (the installer registers the URL scheme). If the
  // app is already running, hand the link to that window and exit; it holds the
  // sign-in that is waiting for this code. Without a running instance the link
  // stays on the command line and the app_links plugin reads it at startup.
  //
  // This also keeps the app to one instance: starting it again without a link
  // just brings the running window to the front. Two instances would open the
  // same local database file.
  if (SendAppLinkToInstance()) {
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  // Window title in Korean ("household ledger"). Written as code points so this
  // file stays ASCII and builds the same under any MSVC source code page.
  if (!window.Create(L"\uAC00\uACC4\uBD80", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
