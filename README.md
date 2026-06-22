# L'Équerre

A **menu-bar window manager** for macOS in the class of Lasso / Rectangle — but
sharper, and drawn like a set of architectural plans. Snap any window onto an
invisible 12-column grid with a keystroke, chain the same direction to cycle
through sizes, and save whole arrangements of windows as named **dispositions**
you re-apply with one click.

Native **Swift / SwiftUI + AppKit**, macOS 14+, built with XcodeGen. Part of the
Atelier family; a sibling to L'Accordeur in build conventions. Its name —
*l'équerre*, the draughtsman's set square — is the whole idea: a precise tool
for laying things out at right angles.

The interface is a single **blueprint panel** that drops from a set-square glyph
in the menu bar: indigo graph-paper grid on near-black paper, precise
mono-spaced type, one luminous draughting accent. FR-first (Québécois French),
with English fallback.

---

## Features

### Accessibility-API window control
Uses `AXUIElement` to read the **focused window of the frontmost app** and set
its position and size. On first run a clean explainer screen requests the
Accessibility permission (`AXIsProcessTrustedWithOptions`) with a one-click
**"Ouvrir les Réglages d'accessibilité"** button. The panel polls trust once a
second, so it flips itself to the grid the moment you tick the box — no relaunch.

### Smart grid sizing (invisible 12-column grid)
Halves (L/R/top/bottom), thirds (L/C/R), two-thirds, quarter corners, maximize,
**almost-maximize**, and center (which preserves window size). Every zone is a
fraction of the screen's **visible frame**, so snapping always respects the menu
bar and the Dock, on whichever screen the window is on.

### Chainable verbs (cycle sizes)
Press the same direction repeatedly to cycle: **½ → ⅓ → ⅔ → ½ …**. A per-window
cycle state (keyed by app + window title) advances on each press and resets when
focus moves, exactly like Lasso/Rectangle's "repeat to resize".

### Global hotkeys
System-wide hotkeys via a **hand-rolled Carbon `RegisterEventHotKey` wrapper**
(`HotkeyManager`) — no external SPM dependency. Defaults:

| Action | Shortcut |
|---|---|
| Moitié gauche / droite / haut / bas (cycles ½→⅓→⅔) | `⌃⌥←` `⌃⌥→` `⌃⌥↑` `⌃⌥↓` |
| Tiers gauche / centre / droit | `⌃⌥J` `⌃⌥K` `⌃⌥L` |
| Deux tiers gauche / droit | `⌃⌥⇧←` `⌃⌥⇧→` |
| Coins haut-gauche / haut-droit / bas-gauche / bas-droit | `⌃⌥U` `⌃⌥I` `⌃⌥N` `⌃⌥M` |
| Plein écran (maximize) | `⌃⌥↩` |
| Presque plein (almost maximize) | `⌃⌥A` |
| Centrer | `⌃⌥C` |

Every shortcut is shown next to its action in the menu.

### Named layouts (dispositions)
Capture the current arrangement of every standard window on the active screen as
a named layout ("Montage", "Écriture"), stored as **fractions of the visible
frame** so it re-applies sensibly across resolutions. Re-apply with one click;
windows are matched back to running apps by bundle id (and window title when an
app has several windows). Persisted as JSON in
`~/Library/Application Support/LEquerre/layouts.json`.

### Menu-bar UI + Preferences
A clean popover lists every grid action with its shortcut, the saved layouts
(with a capture field), and a Preferences area to **rebind the six core hotkeys**
(the four directions, maximize, center) with a live key-capture field, set the
**gutter** between tiled windows (0–24 px), and toggle launch-at-login.

### Launch at login
One switch, backed by `SMAppService.mainApp`.

---

## Build & run

Requires [XcodeGen](https://github.com/yonsm/XcodeGen) (`brew install xcodegen`)
and Xcode 15+ command-line tools.

```bash
./install.sh    # build (Release), sign, install to /Applications, add to Login Items, launch
./gen.sh        # just generate LEquerre.xcodeproj from project.yml
./run-mac.sh    # build (Debug) and launch from /tmp, without installing
```

**`./install.sh` is the one you want** for daily use — it produces a signed
`/Applications/LEquerre.app`. Because `project.yml` sets `DEVELOPMENT_TEAM`, the
build is signed with your **Apple Development** identity (a *stable* signature),
so the Accessibility permission you grant once **persists across reinstalls**.
Ad-hoc signing would change the code hash every build and make macOS drop the
grant. Pass `./install.sh --reset-perms` to force a fresh permission prompt.

All scripts keep DerivedData at `/tmp/l-equerre-mac-dd` — **outside iCloud** —
because iCloud's extended attributes break `codesign`. Override with
`LEQUERRE_MAC_DD`.

Run the tests (pure geometry + value-type round-trips, no permission needed):

```bash
xcodebuild -project LEquerre.xcodeproj -scheme LEquerre \
  -destination 'platform=macOS' test
```

---

## First run — the Accessibility permission

A window manager **must** drive *other* apps' windows through the Accessibility
API, which the App Sandbox forbids. So L'Équerre ships **unsandboxed** (exactly
like Rectangle and Lasso) and asks you to grant the permission by hand:

1. **System Settings → Privacy & Security → Accessibility**
2. Enable **L'Équerre** in the list
3. Come back — the grid opens itself

Nothing is read or transmitted; the app only moves your windows onto the grid.

---

## Caveats

- **Not notarized.** Build and run it locally (or from Xcode). Gatekeeper will
  not let an unsigned-for-distribution copy run by double-click on another Mac
  without a right-click → Open.
- **Needs the Accessibility permission** (above) before any snapping works.
- After rebuilding, macOS sometimes wants you to **re-tick** the Accessibility
  box, since the binary changed — toggle it off/on if snapping goes quiet.
- Fullscreen (native green-button) windows can't be tiled by any AX window
  manager; exit fullscreen first.

---

*L'Équerre — Atelier. Built with Claude Opus 4.8.*
