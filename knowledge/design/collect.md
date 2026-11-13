---
type: Design
title: Collecting the items of a long list
description: "`collect` scrolls a list that shows only part of itself at a time (a web timeline, a long table, an iOS or Android list) and returns each item once, with its text and links: how it finds items, tells them apart, scrolls without the real mouse, stops, and picks up where it left off."
tags: [design, collect, lists, virtualised, scrolling, chromium, ios, android, tables, 1.0]
status: draft
generated: { by: claude-code/claude-opus-5-5, at: 2026-10-17T20:30:00Z }
sources:
  - id: issue
    resource: https://github.com/TheRogue76/macos-harness/issues/47
    title: "Collect every item of a scrolling or virtualised list once (#47)"
  - id: tables
    resource: https://github.com/TheRogue76/otto-harness/issues/181
    title: "Tables: collect and read rows of macOS tables and SwiftUI lists (#181)"
---

# Why

Long lists keep only part of themselves in the tree. A web timeline renders
about a dozen posts and drops earlier ones as it scrolls; iOS and Android
list only what's on screen. Reading one means scrolling, reading,
deduplicating and deciding when it's over, which every agent otherwise
writes for itself, slowly, one call per step.[^issue]

# Interface

`collect --role article -a App` (MCP `collect`), with:

| Option (MCP) | Meaning |
| --- | --- |
| `--role`, `--text`, `--id`, `--exact` (`role`, `text`, `id`, `exact`) | Which elements are the items; at least one is needed. `article` names a web page's `<article>`s, the posts of feeds and timelines |
| `--within <ref>` (`within`) | The list or scroll area to read and scroll; default the window |
| `--key <text>` (`key`) | Tell items apart by their first link whose URL contains this (a post's `/status/` permalink) instead of by their text |
| `--max N` (`max`) | Most items to return, default 50, at most 500 |
| `--until <text>` (`until`) | Stop after the first item whose text contains this (a date past the window being read) |
| `--max-seconds S` (`max_seconds`) | Longest time to keep scrolling, default 45 s, so an MCP call returns before clients give up |
| `--continue` (`continue`) | Leave out items this session already got from this list, to carry on after a limit |

Each item comes back with a ref (good while it's still in the tree), its
text as `read` gives it (inline text joined into lines, a line per block)
and its links with their URLs. The result says why it stopped: `max`,
`until`, `end` (no new items after scrolling three times: the end of the
list, or it stopped loading), `time` or `stuck` (it couldn't scroll
further).

# How it works

One loop for every kind of target, with the reading and scrolling plugged
in, so the loop itself is unit-tested against a fake list:

1. Read the list (`--within`, or the window) and find the items with the
   same search `find` uses, in tree order, which is reading order. A first
   read with no items is tried again for 2 s (6 s on simulators and Android)
   before failing: an Android dump taken while a list is still settling
   after a scroll once left the whole list out.
2. Take each item not seen before. Its identity is its `--key` link's URL
   when it has one, else its whole text; an item with neither text nor
   links (a placeholder still loading) is skipped until it has some.
3. Stop at `max` or `until` as soon as they're reached.
4. Scroll from the last item, wait for the list to redraw, and read again.

Scrolling never uses the real mouse, so a scheduled job doesn't interrupt
the user:

- **Mac:** bring the last item into view through accessibility
  (`AXScrollToVisible`). In a virtualised web list that scrolls about half
  a page and makes the page render the next items (a local timeline went
  from posts 0–11 to 5–16), and it works in a covered window. When the last
  item is already in view and nothing moves, a background wheel scroll of
  80% of the list's height follows, when the window can take one (on
  screen, on the current Space, and the user hasn't turned the background
  route off). Otherwise it's `stuck`.
- **iOS Simulator:** the list's page-down action, the same one `find` uses
  to page through a list.
- **Android:** a swipe up most of the main scrollable element's height
  through adb, as `find` does.

Pages that load more over the network take a moment: a scroll that brings
nothing new counts as idle, and three idle scrolls in a row end the run.

# Tables

Tables and outlines on the Mac (NSTableView, SwiftUI `Table` and `List`)
get their own path, from 2.2,[^tables] because their rows out of view are slow to
read and, in SwiftUI, come back missing cells
([table accessibility](/research/table-accessibility.md)):

- **`collect --role row`** on a table (`--within` it, or a window holding
  one, the one with the most rows) starts at the top (unless continuing),
  reads the rows on screen (`AXVisibleRows`), reading again up to twice any
  row missing a cell or a cell's text, then moves the vertical scroll bar
  down by a screenful less a row, since tables refuse to scroll by page or
  to a row. At the bottom it brings the last row into view, for tables that
  load more, and two reads without new rows end it. Each item's text is its
  cells separated by " | ", items are told apart by their position
  (`AXIndex`), so a row whose cells filled in later isn't taken twice, and
  the result names the columns from the headers.
- **`collect` with `cell` or `text` items** in a table adds a `tableItems`
  notice pointing to `--role row`.
- **`read` on a table** (or a scroll area holding one) pages through it the
  same way, puts the scroll bar back where it was, and returns the column
  headers and every row as cells (200 rows in 5–7 s). `--visible` reads only
  the rows on screen and doesn't scroll. Rows still missing cells keep the
  cells they have under their columns, by position, and an
  `incompleteRows` notice says how many.
- **Snapshots and change reports** leave out the rows of tables of 40 rows
  or more that are out of view, with a `rowsOutOfView` notice; other reads
  (`find`, `wait`, `read` of a window) read them last, after the rest of the
  window, so a long table no longer leaves the controls beside it unread.
  The fixture's tables window went from 3 s to 0.2 s per snapshot.

`flows/fixture/tables.yaml` collects each kind of table.

# Limits and rules

- **It scrolls the app**, so the policy treats it as acting (a read-only app
  refuses it) and it claims the window like any action. It checks for a
  stop between scrolls; a stopped run returns an error, and its items
  aren't marked as seen.
- **Seen items** are remembered per agent session, app, window and item
  selector for an hour, for `--continue`.
- **Items scrolled away** keep their text and links in the result but their
  refs end once the list drops them.
- **Chromium pauses minimised and hidden pages**, so a list in one doesn't
  load further; `collect` then ends with `end`. Background wheel scrolls
  also need the window on the current Space
  (`docs/unattended.md` has the setup that works).

[^issue]: Collect every item of a scrolling or virtualised list once (#47)
[^tables]: Tables: collect and read rows of macOS tables and SwiftUI lists (#181)
