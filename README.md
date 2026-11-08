# Crowns

A digital watch box for iPhone. Keep the watches you own and the ones you want, in simple grids. Save watches straight from Safari: Share › Crowns, and the watch lands in your box with its photo, price and specs filled in.

SwiftUI · SwiftData + CloudKit · iOS 26 · iPhone first.

## Status

All five phases are written and build on Xcode 27. The look is flat, black, white and greys; see `docs/DesignSystem.md`.

| Phase | Scope |
|---|---|
| 1 | Data model, App Group, share extension saving end to end |
| 2 | Grid of watches, each photo edge to edge on a raised card |
| 3 | List view, box chips and swipe, detail in a sheet, Move / Edit / Remove, box editor |
| 4 | Compact share sheet, photo carousel with a single photo picked to import, £ conversion, Foundation Models fallback |
| 5 | iCloud sync status, privacy manifests, icon, App Store notes (`docs/AppStore.md`) |

## Setup

Needs Xcode 26, an iPhone on iOS 26, and a **paid** Apple Developer account (free teams can't use App Groups or CloudKit).

1. **Set your identifiers first.** Open `Config/Crowns.xcconfig` and set `CROWNS_BUNDLE_PREFIX` (default `com.kadeashiq`) and, optionally, `DEVELOPMENT_TEAM`. The App Group (`group.<prefix>.crowns`) and iCloud container (`iCloud.<prefix>.crowns`) are registered with Apple on the first signed build and **can't be deleted afterwards**.
2. Open `Crowns.xcodeproj`. For the **Crowns** and **CrownsShare** targets, open Signing & Capabilities and pick your team. Check that App Groups shows the group ticked on both, and that iCloud › CloudKit shows the container ticked on Crowns. If the container isn't listed, press + and add it with the exact name from step 1.
3. Run the **Crowns** scheme on your iPhone once.

## Trying it

**Saving from Safari**
1. Open a watch listing: an eBay listing (one priced in £ and one in $), a Shopify shop, a brand site.
2. Share › **Crowns** (if missing: More › add it).
3. Tap a thumbnail or swipe to pick the one photo to import.
4. Save. The first save goes to Wishlist; after that, the last box you used.
5. Also share from the eBay app or another browser: these send only a link, so it takes a few seconds longer.

**In the app**
- Chips switch boxes; so does swiping sideways. Long-press a chip to edit its box. The arrows beside the + drag boxes into any order.
- The toggle top right switches Grid and List, and is remembered.
- Tap a watch: it opens in a sheet. Swipe any sheet down to close it.
- The + at the bottom adds a watch: paste a link or choose a photo.

**Sync**: with two devices on the same iCloud account, a watch saved on one should appear on the other within a minute or so with the app open. Settings › iCloud shows the status and last sync.

**Foundation Models doesn't run in the Simulator**: the model fallback is skipped. Use a device.

### When a site comes out wrong

Settings › **Diagnostics** (debug and TestFlight builds) shows what the extension read from your last 20 shares. Open an entry and export it with the share button. Send me that file; its `snapshotJSON` becomes a test fixture, so the fix stays fixed.

### Debugging the extension

Run the Crowns scheme, then Debug › Attach to Process by PID or Name › `CrownsShare`, and share from Safari. Breakpoints and `Logger` output (subsystem `Crowns`) then work in the extension.

## How saving works

```
Safari ── Share ──▶ Preprocess.js runs in the live page ──▶ JSON snapshot
other apps ─ URL ─▶ hidden WKWebView runs the same script ─┘
                                                          │
                     ListingInterpreter (Swift): page specs ▸ JSON-LD ▸ Shopify
                     product JSON ▸ Open Graph / microdata ▸ title heuristics
                                                          │
                     still thin and no structured data? ──▶ LinkPresentation
                                                          │
                     ImageFetcher: downloads at CDN max size, ImageIO-thumbnails to
                     1600px, drops logos/banners ──▶ WatchRecorder ──▶ SwiftData
```

- **One store, two processes.** The SwiftData store lives in the App Group. The app opens it with CloudKit mirroring. The extension opens the same file without CloudKit, which keeps it light, and the app exports the extension's writes to iCloud the next time it runs. On returning to the foreground, the app re-queries if the extension saved something.
- **Memory.** Images are never fully decoded in the extension. ImageIO makes thumbnails straight from the downloaded bytes.
- **Schema.** `CrownsSchemaV1` is versioned and CloudKit-safe: every field is optional or defaulted, nothing is unique, and images use external storage. After the CloudKit schema is deployed to production, add a V2 rather than editing V1.
- **Default boxes.** Wishlist and Collection are created on first run. If two devices both create them before syncing, the copies are merged by `seedKey`.
- **Full boxes** grow by one row instead of refusing a save.
- The first save from the extension goes to **Wishlist**. After that, it remembers the last box you used.
- **Prices** are always £. Foreign prices are converted with daily ECB rates (Frankfurter), cached for a day and reused offline; the original is kept, e.g. "$4,250 converted".

## Project layout

```
Crowns/          app: main screen, detail, box editor, settings, sync monitor
CrownsShare/     share extension (just the view controller)
Shared/          compiled into both: model, store, extraction, images,
                 box rendering, add-watch sheet
CrownsTests/     Swift Testing suites + Fixtures/*.snapshot.json
Config/          xcconfig, Info.plists, entitlements
docs/            privacy policy draft, App Store prep
Tools/
  extractor/     Node + jsdom tests for Preprocess.js; regenerates fixtures
  gen_xcodeproj.py
```

`Crowns.xcodeproj` is generated by `python3 Tools/gen_xcodeproj.py`, with target membership by folder. Adding files in Xcode works as normal. Re-running the script also picks up whatever is on disk.

## Tests

- Extractor (JavaScript): `cd Tools/extractor && npm install && npm test`. This runs `Preprocess.js` over saved eBay, Shopify and brand-site pages and writes the snapshots to `CrownsTests/Fixtures/`.
- Interpreter (Swift): ⌘U on the Crowns scheme. Runs on those same snapshots.
