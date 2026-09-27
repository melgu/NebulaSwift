# Pull to refresh leaves the grid pulled down

Status: **open**. The cause is not found yet. This file records what has been measured so far, so the investigation can pick up from here.

## Symptom

On iPhone, in the tabs built on `AutoGrid` (My Shows, Watch Later), pulling to refresh sometimes leaves the view pulled down after the reload finishes. A short swipe brings it back.

- Featured and Browse never stick.
- The refresh spinner appears **above** the large title in My Shows and Watch Later, and **below** it in Featured and Browse. The initial loading indicator always appears below the title.
- Pulling before the grid has been scrolled at all sticks. Pulling after scrolling does not.
- On the device, Watch Later stuck on every unscrolled pull. My Shows stuck only sometimes, which suggests a timing or state dependence.

## How to reproduce and measure

The bug reproduces in the iOS 27.2 simulator (iPhone 17) with a logged-in account. It needs the real Watch Later data; see "What triggers it" below.

1. Launch the app. It opens into My Shows.
2. Go back, open Watch Later, and wait for the first load to finish.
3. Pull to refresh without scrolling first.

To check the result without eyeballing screenshots, read the large title's frame from the accessibility hierarchy:

| State | Title `y` |
|---|---|
| At rest | 119.7 pt |
| Stuck | 179.7 pt (60 pt lower, the height of the refresh control) |

In the stuck state, the scroll view still holds a 156 pt block at its top where the refresh control lives, and the navigation bar's large title stays displaced. That points to the scroll view never being told the refresh ended, or ignoring it.

Notes on driving the simulator through the Xcode MCP device-interaction tools:

- `drag x1 y1 x2 y2` performs the pull. Start it in the left margin (`x = 8`). A pull that starts on a cell sometimes didn't trigger a refresh at all.
- To capture state without disturbing it, tap an empty spot beside the large title. **Don't tap the status bar**: that scrolls to the top and clears a stuck view.
- `AutoGrid` logs "Refresh items" at debug level, which confirms that a pull actually triggered a refresh.

## What triggers it

**The Watch Later list itself.** Pointing My Shows at the Watch Later endpoint (`api.watchLaterVideos`) made My Shows stick as well. With its own data, My Shows never stuck in the simulator.

## Ruled out

Each change below was tested in the real app in the simulator on the unscrolled Watch Later pull, and it still stuck. Most were a single run each.

| Change | Result |
|---|---|
| Removed `.statisticsAlert` (toolbar `AsyncButton`) | still stuck (also on the device) |
| Removed `.assumeWatchLater()` | still stuck |
| Opened My Shows second instead of first | My Shows didn't stick, so screen order isn't it |
| Added a 2 s delay to every refresh in My Shows | didn't stick, so refresh duration isn't it |
| Checked for a page-2 request between load and pull | none ran, so paging isn't it |
| Hid the watch-progress bars (`ProgressView` with `.watchTime`) | still stuck |
| Hid the bookmark overlay | still stuck |
| Drew cells as bare `VideoPreviewView`, without the `Button`, `.draggable` and `.contextMenu` | still stuck |
| Replaced the thumbnail and avatar `AsyncImage`s with plain colors | still stuck |
| Kept the `ScrollView` present from the first frame and removed the second `.refreshable` on the grid content | still stuck |

On the device, also without effect:

- Showing the footer `ProgressView` only while a page is loading.
- Keeping the `ScrollView` during the initial load together with `.scrollDisabled(isInitialLoad)`.

## The one lead

Drawing each Watch Later cell as plain `Text(video.title)` with a fixed height **didn't stick**: the title returned to 119.7 pt after the refresh. The same data drawn with `VideoPreviewView` stuck, even with its images, progress bar and bookmark removed.

This comes from a **single run** and needs repeating before anything is built on it.

## Findings that didn't hold up

An earlier stand-in screen with fake data (`AutoGrid` in the same split view, stack and sidebar setup) seemed to show that removing the second `.refreshable` inside the `ScrollView` fixed the sticking. That rested on single runs with a 1 s fake fetch, and the real app didn't confirm it. It's listed here so it isn't taken as a result.

## Suggested next steps

1. Repeat the plain-text-cell test several times to confirm it doesn't stick.
2. If it holds, add the parts of `VideoPreviewView` back one at a time, measuring each over several pulls:
   - the title and channel `Text`s with `.lineLimit(2)`
   - the duration label, which formats `Date.now ..< Date.now + duration`
   - the `.regularMaterial` backgrounds in the information overlay
   - the `Color.black.aspectRatio(16/9)` frame with `.cornerRadius(8)`
3. If it doesn't hold, look at which Watch Later items differ from My Shows items. For example, bisect the list by limiting the page to fewer videos.

## Related

- `35157ab` fixed a separate problem: the grid staying empty behind its spinner after being pushed on iPhone. It isn't a fix for this bug.
- Browse's category row loads in a `.task` that also gets cancelled on push (`NSURLErrorDomain -999` on `/categories/`), the same SwiftUI behavior `35157ab` works around.
- Browse's title doesn't collapse into the navigation bar. Its grid's `ScrollView` sits in a `VStack` under the category row, so the navigation bar doesn't track it.
