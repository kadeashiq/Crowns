# Crowns

A digital watch box for iPhone. Keep the watches you own and the ones you want, each on a cushion in a box. Save watches straight from Safari: Share › Crowns, and the watch lands in your box with its photo, price and specs filled in.

SwiftUI · SwiftData + CloudKit · iOS 26 · iPhone first.

## Status

| Phase | Scope | State |
|---|---|---|
| 1 | Data model, App Group, share extension saving end to end | **Ready to try on device** |
| 2 | Box view: cushions, wood, shadows, name plate | — |
| 3 | List view, box switching, detail, matched-geometry lift | — |
| 4 | Compact share sheet, cut-outs, £ conversion, Foundation Models fallback | — |
| 5 | Paywall (StoreKit 2), iCloud sync checks, App Store prep | — |

## Setup

Needs Xcode 26, an iPhone on iOS 26, and a **paid** Apple Developer account (free teams can't use App Groups or CloudKit).

1. **Set your identifiers first.** Open `Config/Crowns.xcconfig` and set `CROWNS_BUNDLE_PREFIX` (default `com.kadeashiq`) and, optionally, `DEVELOPMENT_TEAM`. The App Group (`group.<prefix>.crowns`) and iCloud container (`iCloud.<prefix>.crowns`) are registered with Apple on the first signed build and **can't be deleted afterwards**.
2. Open `Crowns.xcodeproj`. For the **Crowns** and **CrownsShare** targets, open Signing & Capabilities and pick your team. Check that App Groups shows the group ticked on both, and that iCloud › CloudKit shows the container ticked on Crowns. If the container isn't listed, press + and add it with the exact name from step 1.
3. Run the **Crowns** scheme on your iPhone once.

## Trying phase 1

1. In Safari, open a watch listing. Try one of each:
   - an **eBay** listing (ebay.co.uk, and a US listing priced in $)
   - a **Shopify** shop's product page
   - a **brand site** product page (Omega, Tudor, Seiko…)
2. Tap Share › **Crowns**. If it's not in the row, tap More and add it.
3. Check the brand, model, price, photo and box, then tap **Save**.
4. Open Crowns. The watch should be in the box you chose, without relaunching.
5. Also try sharing from the **eBay app** or another browser. Those send only a URL, so Crowns loads the page in a hidden web view. It's slower, but the fields should match.

The sheet is deliberately plain for now. Phase 4 builds the real one.

What phase 1 doesn't do yet: prices in other currencies are saved with the original price (e.g. "$4,250") and no £ figure until phase 4. Photos are saved as they are, with no cut-outs yet.

### When a site comes out wrong

Crowns › the magnifier icon (top right) › **Diagnostics** shows what the extension read from your last 20 shares. Open an entry and export it with the share button. Send me that file; its `snapshotJSON` becomes a test fixture, so the fix stays fixed.

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
- **Default boxes.** Collection and Wishlist are created on first run. If two devices both create them before syncing, the copies are merged by `seedKey`.
- **Full boxes** grow by one row instead of refusing a save.
- The first save from the extension goes to **Wishlist**. After that, it remembers the last box you used.

## Project layout

```
Crowns/          app target
CrownsShare/     share extension
Shared/          compiled into both (model, store, extraction, images)
CrownsTests/     Swift Testing suites + Fixtures/*.snapshot.json
Config/          xcconfig, Info.plists, entitlements
Tools/
  extractor/     Node + jsdom tests for Preprocess.js; regenerates fixtures
  gen_xcodeproj.py
```

`Crowns.xcodeproj` is generated by `python3 Tools/gen_xcodeproj.py`, with target membership by folder. Adding files in Xcode works as normal. Re-running the script also picks up whatever is on disk.

## Tests

- Extractor (JavaScript): `cd Tools/extractor && npm install && npm test`. This runs `Preprocess.js` over saved eBay, Shopify and brand-site pages and writes the snapshots to `CrownsTests/Fixtures/`.
- Interpreter (Swift): ⌘U on the Crowns scheme. Runs on those same snapshots.
