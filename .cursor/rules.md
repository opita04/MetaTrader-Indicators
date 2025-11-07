# Cursor Project Rules

This repository uses Cursor for day‑to‑day development. The guidance below codifies how we work in this codebase so changes stay consistent, minimal, and easy to review.

## Principles
- Prefer simple solutions; iterate on existing patterns before introducing new ones.
- Touch only code directly related to the task; avoid cross‑cutting refactors unless explicitly requested.
- Keep files tidy and organized; avoid files over ~200 lines if a clean extraction is obvious.
- Consider all environments (dev/test/prod). Never hardcode secrets or change `.env` without approval.
- Do not mock or stub production data paths; mocks are for tests only.
- Remove dead/duplicate logic when replacing an implementation; don’t leave two code paths.

## Editing & Change Management
- Make focused edits with clear intent; avoid drive‑by formatting.
- Preserve existing indentation, whitespace style, and naming where practical.
- When adding options/inputs, default them to safe values and document them.
- If a change requires background services, explicitly note start/stop steps in the PR description.
- Avoid adding scripts intended for single‑use tasks.

## Debugging & Logging
- Use temporary debug logs sparingly and behind a flag; remove them before merging unless requested.
- Add targeted logs to validate assumptions when triaging issues; propose removal in the PR once fixed.

## Tests & Verification
- Write tests for major functionality and for fixes that change behavior.
- Keep tests deterministic; avoid network/time dependencies unless mocked.
- Document manual verification steps in the PR when automated tests are impractical.

## Performance & Safety
- Be mindful of heavy loops and external calls (e.g., indicator iCustom/iMA in MQL); cache where reasonable.
- Validate array indexes, buffer bounds, and timeframe/series alignment before access.
- Fail safely: prefer neutral behavior over throwing or blocking the terminal/application.

## API/Dependency Changes
- Don’t add new dependencies or external tools without clear justification and approval.
- If you must introduce a new approach, remove the superseded one in the same PR to prevent duplication.

## Documentation Requirements
- Update in‑code comments only for non‑obvious rationale, invariants, and edge cases (no narrations).
- For new settings/inputs, document name, type, default, and effect (and side effects) in the file header or module README.
- Keep this rules file current when team‑wide conventions change.

## PR Hygiene
- One logical change per PR; small, reviewable diffs.
- Include a concise summary of the problem, the chosen solution, alternatives considered, and validation results.
- Reference any related issues/tickets.

## Cursor‑specific Conventions
- Store project rules and Cursor docs under `.cursor/`.
- When large or multi‑step features are requested, track the work with a lightweight TODO list in the PR/issue.
- Use code fences and file/line references in review notes for clarity.

## MQL‑specific Notes (if applicable)
- Guard bar indices and series access (`bar >= 0 && bar < Bars`).
- Confirm series synchronization across timeframes (`iBarShift`, `iBars` checks).
- Limit historical processing for performance; only compute the necessary window.
- Prefer neutral outputs (e.g., `EMPTY_VALUE`) when upstream indicators are unavailable or invalid.
- MetaTrader 4 compiler location: `C:\ProgramData\Metatrader\MetaTrader 4 IC Markets`

--- 

If a rule conflicts with explicit user instructions for a task, follow the explicit instruction and note the deviation in the PR description.


