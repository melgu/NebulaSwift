# Pull to refresh leaves the grid pulled down

Status: **fixed in the simulator** by giving every video cell the same height. Not yet confirmed on a device. The underlying mechanism in SwiftUI/UIKit is inferred, not traced.

## Symptom

On iPhone, in the tabs built on `AutoGrid` (My Shows, Watch Later), pulling to refresh sometimes leaves the view pulled down after the reload finishes. A short swipe brings it back.

- Featured and Browse never stick.
- The refresh spinner appears **above** the large title in My Shows and Watch Later, and **below** it in Featured and Browse. The initial loading indicator always appears below the title.
- Pulling before the grid has been scrolled at all sticks. Pulling after scrolling does not.
- On the device, Watch Later stuck on every unscrolled pull. My Shows stuck only sometimes, which suggests a timing or state dependence.

## Cause

Sticking takes two things at once:

1. **Grid cells of different heights.** `VideoPreviewView` let the title take one or two lines, so cells came out 251 pt or 273 pt tall depending on the title.
2. **A refresh that is still running when the pull settles** into its held refreshing position. Watch Later's fetch takes about 1.7–1.8 s in the simulator; My Shows' about 0.3 s.

Neither alone is enough: a 2 s refresh over My Shows' cells didn't stick, and neither did an instant refresh over Watch Later's cells. My Shows' own data sticking "sometimes" on the device fits this: it depends on how long that fetch takes and which titles are on screen.

How the two combine inside SwiftUI's refresh handling is not traced. A plausible reading is that the lazy grid's content size changes while the refresh inset is held (estimated row heights being replaced by measured ones), and the scroll view loses track of the inset it has to give back when the refresh ends.

## Fix

`VideoPreviewView` reserves two lines for the title with `.lineLimit(2, reservesSpace: true)`, and limits the channel name under it to one line, so every cell has the same height. This changes the layout of every video grid and of the Featured rails: one-line titles now leave an empty second line.

`ChannelPreviewView`, `PodcastPreviewView` and `HeroPreviewView` reserve two title lines the same way. Channel previews fill the channel grids (`AutoChannelGrid` in My Shows and Browse), which run on the same `AutoGrid`; podcast and hero previews only appear in the Featured rails, and get it for consistency. `CategoryPreview` is a one-line chip and is left alone.

## Evidence

Measured in the iOS 27.2 simulator (iPhone 17) on 2026-09-27, with temporary logging in `AutoGrid.refreshItems` that recorded how long each refresh took, whether it threw or was cancelled, and whether the list changed. Every pull listed below fired a refresh, and every refresh returned normally: no error, no cancellation, and the list came back equal to the one on screen, so nothing re-rendered.

| Build | Tab | Refresh | Cell heights | Stuck |
|---|---|---|---|---|
| Unchanged app, network fetch | Watch Later | ~1.8 s | vary | 5 of 5 |
| Unchanged app, network fetch | My Shows | ~0.3 s | vary | 0 of 3 |
| Refresh returns the current items instantly | Watch Later | ~0 s | vary | 0 of 3 |
| Refresh sleeps 2 s, returns the current items | My Shows | ~2 s | vary | 0 of 3 |
| Refresh sleeps 2 s, returns the current items | Watch Later | ~2 s | vary | 3 of 3 |
| As above, cells forced to `.frame(height: 300)` | Watch Later | ~2 s | fixed | 0 of 3 |
| As above, title with `.lineLimit(2, reservesSpace: true)` | Watch Later | ~2 s | uniform | 0 of 3 |
| The fix alone, network fetch | Watch Later | network | uniform | 0 of 4 |
| The fix alone, network fetch | My Shows | network | uniform | 0 of 2 |

The earlier single-run lead fits: plain `Text(video.title)` cells with a fixed height didn't stick, because their heights were uniform.

## How to reproduce and measure

The bug reproduced in the iOS 27.2 simulator (iPhone 17) with a logged-in account, using the real Watch Later data.

1. Launch the app. It opens into My Shows.
2. Go back, open Watch Later, and wait for the first load to finish.
3. Pull to refresh without scrolling first.

To check the result without eyeballing screenshots, read the large title's frame from the accessibility hierarchy:

| State | Title `y` |
|---|---|
| At rest | 119.7 pt |
| Stuck | 179.7 pt (60 pt lower, the height of the refresh control) |

In the stuck state the whole content sits 60 pt low (first cell at `y` 244 instead of 184) and no spinner is visible.

To make the bug independent of network timing, temporarily have `refreshItems` sleep 2 s and return the current `items` once the first load is in. With the old cells, Watch Later then sticks on every unscrolled pull.

Notes on driving the simulator through the Xcode MCP device-interaction tools:

- `drag 8 190 8 540` performs the pull. Start it in the left margin (`x = 8`). A pull that starts on a cell sometimes didn't trigger a refresh at all.
- `drag 8 500 8 420` clears a stuck view.
- To capture state without disturbing it, tap an empty spot beside the large title, e.g. (330, 150). **Don't tap the status bar**: that scrolls to the top and clears a stuck view.
- The capture taken as a drag finishes can't tell whether a refresh ran. Check the "Refresh items" debug log from `AutoGrid` instead.

## Ruled out earlier

Each change below was tested in the real app in the simulator on the unscrolled Watch Later pull, and it still stuck. Most were a single run each. None of them made the cells the same height, which is why none of them helped.

| Change | Result |
|---|---|
| Removed `.statisticsAlert` (toolbar `AsyncButton`) | still stuck (also on the device) |
| Removed `.assumeWatchLater()` | still stuck |
| Opened My Shows second instead of first | My Shows didn't stick, so screen order isn't it |
| Added a 2 s delay to every refresh in My Shows | didn't stick; confirmed over 3 runs, see "Cause" |
| Checked for a page-2 request between load and pull | none ran, so paging isn't it |
| Hid the watch-progress bars (`ProgressView` with `.watchTime`) | still stuck |
| Hid the bookmark overlay | still stuck |
| Drew cells as bare `VideoPreviewView`, without the `Button`, `.draggable` and `.contextMenu` | still stuck |
| Replaced the thumbnail and avatar `AsyncImage`s with plain colors | still stuck |
| Kept the `ScrollView` present from the first frame and removed the second `.refreshable` on the grid content | still stuck |

On the device, also without effect:

- Showing the footer `ProgressView` only while a page is loading.
- Keeping the `ScrollView` during the initial load together with `.scrollDisabled(isInitialLoad)`.

## Findings that didn't hold up

An earlier stand-in screen with fake data (`AutoGrid` in the same split view, stack and sidebar setup) seemed to show that removing the second `.refreshable` inside the `ScrollView` fixed the sticking. That rested on single runs with a 1 s fake fetch, and the real app didn't confirm it.

## Open

- **Confirm on a device.** Everything above was measured in the simulator.
- **Channel grids** (`AutoChannelGrid` in My Shows and Browse) now get uniform cells too, but were never seen sticking or tested either way.

## Related

- `35157ab` fixed a separate problem: the grid staying empty behind its spinner after being pushed on iPhone.
- Browse's category row loads in a `.task` that also gets cancelled on push (`NSURLErrorDomain -999` on `/categories/`), the same SwiftUI behavior `35157ab` works around.
- Browse's title doesn't collapse into the navigation bar. Its grid's `ScrollView` sits in a `VStack` under the category row, so the navigation bar doesn't track it.
