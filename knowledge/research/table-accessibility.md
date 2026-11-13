---
type: Analysis
title: How Mac tables and SwiftUI lists look to accessibility
description: An NSTableView, a SwiftUI Table and a SwiftUI List all expose every row with its position, the visible rows and column headers, but reading the rows out of view is slow and, in SwiftUI, gives rows missing cells or their text; they also refuse to scroll by page or to a row, while setting the scroll bar's value scrolls them.
tags: [spike, tables, accessibility, swiftui, appkit, collect, read, performance]
status: stable
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-13T23:30:00Z }
verified: { by: claude-code/claude-opus-5-5, at: 2026-11-13T23:30:00Z }
stale_after: 2027-11-13T00:00:00Z
sources:
  - id: spike
    resource: "`otto-dev spike axtable|axstats|axattrs` on the fixture's `--tables` window (200 rows each), macOS 27.2, 2026-11-13"
    title: Table spike output
    author: claude-code/claude-opus-5-5
  - id: issue
    resource: https://github.com/TheRogue76/otto-harness/issues/181
    title: "Tables: collect and read rows of macOS tables and SwiftUI lists (#181)"
---

# Setup

The fixture's `--tables` window (`--tables appkit|table|list` shows one)
holds an NSTableView with view-based cells, a SwiftUI `Table` and a SwiftUI
`List`, each of 200 rows of a keyword and two numbers, 15 or 16 of them on
screen.[^spike] It stands in for Astro's keyword table, where `collect`
returned 250 garbled items for about 29 rows and `find` took 5 s.[^issue]

# What each exposes

| | NSTableView | SwiftUI Table | SwiftUI List |
| --- | --- | --- | --- |
| Role | `AXTable` | `AXOutline` | `AXOutline` |
| `AXRows`, `AXVisibleRows` | all 200; 15 | all 200; 15 | all 200; 16 |
| Row | `AXRow`/`AXTableRow`, `AXIndex` | `AXRow`/`AXOutlineRow`, `AXIndex` | same |
| Cells | 3 `AXCell` each holding the text | 3 `AXCell` each holding a hosting group and the text | 1 `AXCell` holding both texts |
| Headers | `AXHeader`: a group of buttons titled with each column; each `AXColumn`'s `AXHeader` is its button | same | none |
| Whole tree read | 1,423 nodes in 9.2 s | 2,023 nodes in 3.8 s | 817 nodes in 0.5 s |

Getting `AXRows` takes about 10 ms, `AXVisibleRows` under 1 ms, and reading
one row 1 to 20 ms. Snapshotting the window with all three tables used up
the reader's 3 s on the AppKit table's off-screen rows, so the two SwiftUI
tables beside it never appeared.

# Rows out of view are unreliable

Rows on screen always came back whole, over four reads of 15 rows each. Rows
out of view didn't, in the SwiftUI table: the same row read three times in
a row came back with all three cells, then with two, then with three again,
and a full read of the table had 67 to 100 of its 200 rows missing a cell or
a cell's text. That's what made `collect` in Astro return rows each holding
a different subset of their cells. The AppKit table's rows out of view came
back whole, but slowly.

# Scrolling

All three sit in an `AXScrollArea` that lists `AXScrollDownByPage` and its
siblings, but performing them fails with -25205 (`cannotComplete`). Rows
offer no `AXScrollToVisible` (-25206). Setting the area's vertical scroll
bar's `AXValue` (0 at the top, 1 at the bottom) does scroll them: 0.5
showed rows 91–107.

The table's `AXSize` is only the part on screen, although its `AXFrame`
attribute has the whole height (4,812 points), so the harness's
scroll-bar fallback, which works out the document's height from position
and size, moved nothing. A page's step in scroll-bar units comes from row
counts instead: (rows on screen − 1) / (rows − rows on screen).

# What the harness does with this

See [Collecting the items of a long list](/design/collect.md): reads and
snapshots read the rows on screen first, `read` on a table pages through it
on screen through the scroll bar and puts the scroll bar back, and `collect`
with item `row` does the same, a screenful at a time, telling rows apart by
`AXIndex`.

[^spike]: Table spike output
[^issue]: Tables: collect and read rows of macOS tables and SwiftUI lists (#181)
