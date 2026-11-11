# Pastry's design record

This is a **historical record of how Pastry was built**, not a live plan.
All ten features shipped; the unticked checkboxes in the plans are how they
were written before the work, and were never ticked back.

It is kept because the useful part of a rewrite is not the result but the
reasons — particularly the places where the design turned out to be wrong.

## What is here

**[`superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md`](superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md)**
is the design document, and the one worth reading. It was updated whenever
reality disagreed with it, so it records what was decided *and* what had to
change. Among the things it had to be taught:

- An `LSUIElement` agent application is never `NSApp.isActive`, and the
  cooperative `NSApp.activate()` does not activate one at all.
- Key codes are physical positions, so a hotkey is layout-dependent — and a
  key's *name* has to come from the current keyboard layout, not a table.
- macOS does not report hotkey conflicts: two applications can register the
  same combination and both receive it.
- A status menu tracks without activating the app, so nothing inside it can
  take keyboard focus until the app is activated and the menu reopened.

**`superpowers/plans/`** holds one implementation plan per feature, in order.
Each opens with the constraints it worked under and a section on what was
expected to fight back — which is usually the most accurate part.

The `For agentic workers` line at the top of each plan is addressed to the
tooling that executed it and can be ignored.

The plans say `master` throughout, because that is what the default branch
was called while the work was done. It was renamed to `main` afterwards. The
plans are left as they were written rather than edited to match — a record
that has been tidied up after the fact is worth less than one that has not.
