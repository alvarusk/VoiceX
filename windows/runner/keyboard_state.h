#ifndef RUNNER_KEYBOARD_STATE_H_
#define RUNNER_KEYBOARD_STATE_H_

#include <windows.h>

namespace voicex {

// Global hotkeys may consume key-up messages while another app has focus.
// Refresh only this thread's modifier state from the physical keyboard so
// Flutter can synthesize the missing releases on the next input event.
// Keep lock-key toggles and unrelated keys intact; never send global input.
inline void RefreshKeyboardModifiers() {
  BYTE state[256] = {};
  if (!GetKeyboardState(state)) {
    return;
  }
  constexpr int modifiers[] = {VK_SHIFT,   VK_LSHIFT,   VK_RSHIFT, VK_CONTROL,
                               VK_LCONTROL, VK_RCONTROL, VK_MENU,   VK_LMENU,
                               VK_RMENU,  VK_LWIN,     VK_RWIN};
  for (const int key : modifiers) {
    state[key] = static_cast<BYTE>(
        (state[key] & 0x7f) | ((GetAsyncKeyState(key) & 0x8000) ? 0x80 : 0));
  }
  SetKeyboardState(state);
}

}  // namespace voicex

#endif  // RUNNER_KEYBOARD_STATE_H_
