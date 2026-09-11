# Mobile Web input regression — 2026-09-11

Direct human evidence from the deployed GitHub Pages build showed that the game could launch but the player could not move on the real mobile-Web path.

The failure was not reproduced by the existing smoke because the synthetic `InputEventMouseMotion` set `MOUSE_BUTTON_MASK_LEFT`. On iOS Web, touch-derived mouse motion may arrive with `button_mask == 0` after the pointer has already been captured.

The input rule is now:

- a left-side mouse-compatible press captures the virtual movement pointer;
- subsequent captured mouse motion updates the joystick regardless of `button_mask`;
- explicit mouse-up still releases the joystick;
- native `InputEventScreenTouch` / `InputEventScreenDrag` paths remain unchanged;
- the touch-input smoke must cover a captured mouse motion with `button_mask == 0`.

Do not treat headless input smoke as proof of real-device behavior when direct mobile-Web evidence disagrees. Real-device human evidence wins and must become a regression case where practical.
