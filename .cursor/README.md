Version bump helper
===================

Place the included script at `.cursor/update-mq4-version.js`.

Usage:
- To bump versions for specific files:
  - `node .cursor/update-mq4-version.js path/to/file1.mq4 path/to/file2.mq4`
- To bump versions automatically for modified .mq4 files (git repo required):
  - `node .cursor/update-mq4-version.js` (it parses `git status --porcelain` and updates changed .mq4 files)

Behavior:
- The script finds the first `#property version   "MAJOR.MINOR"` line and increments MINOR by 1.
- MINOR is kept as two digits (e.g., `2.09` -> `2.10`). If MINOR reaches 100 it rolls into MAJOR.
- A `.bak` backup file is created alongside each edited file.

Notes:
- This is a simple helper. If you want automatic integration with Cursor hooks or CI, tell me how you run your release process and I can add a hook.


