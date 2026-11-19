// Standalone Windows regression test. Run on the UI thread of a console app.
#include "../windows/runner/keyboard_state.h"

#include <cstdio>

int main() {
  BYTE original[256] = {};
  if (!GetKeyboardState(original)) return 1;
  BYTE stale[256];
  CopyMemory(stale, original, sizeof(stale));
  // Simulate the thread state left behind by a swallowed global-hotkey key-up.
  stale[VK_LWIN] |= 0x80;
  stale[VK_LSHIFT] |= 0x80;
  stale[VK_SHIFT] |= 0x80;
  stale[VK_LCONTROL] |= 0x80;
  stale[VK_CONTROL] |= 0x80;
  stale[VK_CAPITAL] = 1;
  stale['A'] = 0x80;
  if (!SetKeyboardState(stale)) return 2;

  voicex::RefreshKeyboardModifiers();
  BYTE recovered[256] = {};
  const bool read_ok = GetKeyboardState(recovered) != 0;
  const int modifiers[] = {VK_LWIN, VK_LSHIFT, VK_SHIFT, VK_LCONTROL, VK_CONTROL};
  bool valid = read_ok && recovered[VK_CAPITAL] == 1 && recovered['A'] == 0x80;
  for (const int key : modifiers) {
    valid = valid && ((recovered[key] & 0x80) != 0) ==
                         ((GetAsyncKeyState(key) & 0x8000) != 0);
  }
  SetKeyboardState(original);
  if (!valid) return 3;
  std::puts("Keyboard modifiers recovered; unrelated keys and lock state preserved.");
  return 0;
}
