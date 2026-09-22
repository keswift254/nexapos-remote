#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // A browser return activates the waiting app, without opening its database twice.
  const auto arguments = GetCommandLineArguments();
  if (arguments.size() == 1 &&
      (arguments[0] == "nexapos://checkout-return" ||
       arguments[0] == "nexapos://checkout-return/")) {
    HWND existing = ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", L"NexaPOS");
    if (existing) {
      DWORD process_id = 0;
      ::GetWindowThreadProcessId(existing, &process_id);
      ::AllowSetForegroundWindow(process_id);
      if (::IsIconic(existing)) ::ShowWindow(existing, SW_RESTORE);
      ::SetForegroundWindow(existing);
      return EXIT_SUCCESS;
    }
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

#ifdef NEXAPOS_LEGACY_WINDOWS
  // Windows 7/8 edition only (the legacy build defines this; the Windows 10/11
  // build does not, so nothing changes there). Flutter now uses Impeller by
  // default, and Impeller refuses to run without a GPU surface ("Impeller
  // backend does not support software rendering"). The patched engine below
  // Windows 10 deliberately draws in software, so on those systems the older
  // renderer must be used or the engine gives up and the app never opens.
  project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);
#endif

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"NexaPOS", origin, size)) {
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
