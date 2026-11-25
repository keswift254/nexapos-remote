#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

// One NexaPOS per Windows sign-in. Every copy uses the same key file and the
// same database; on 2026-11-25 three copies ran at once on one PC (one left
// running as administrator by an update) and together emptied the key file.
// Named after the data they share (com.nexapos / NexaPOS in Runner.rc).
constexpr wchar_t kSingleInstanceName[] =
    L"Local\\com.nexapos.NexaPOS.single-instance";

// Takes the single-instance lock [name]. Returns the lock (keep it open while
// NexaPOS runs). Returns nullptr with *already_running = true when another
// copy holds it - including a copy running as administrator, which keeps an
// ordinary one out ("access denied"). Any other failure returns nullptr with
// *already_running = false: a failing lock never stops NexaPOS from starting.
inline HANDLE TakeSingleInstanceLock(const wchar_t* name, bool* already_running) {
  ::SetLastError(ERROR_SUCCESS);
  HANDLE lock = ::CreateMutexW(nullptr, FALSE, name);
  const DWORD error = ::GetLastError();
  *already_running = (lock != nullptr && error == ERROR_ALREADY_EXISTS) ||
                     (lock == nullptr && error == ERROR_ACCESS_DENIED);
  if (*already_running && lock != nullptr) {
    ::CloseHandle(lock);
    lock = nullptr;
  }
  return lock;
}

#endif  // RUNNER_SINGLE_INSTANCE_H_
