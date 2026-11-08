# App Store prep

## Before the first TestFlight build

1. **Identifiers.** `Config/Crowns.xcconfig` → `CROWNS_BUNDLE_PREFIX`. App Group and iCloud container are permanent once registered.
2. **App Store Connect app.** Create it with bundle ID `<prefix>.crowns`. Primary category: Lifestyle.
3. **Price.** In App Store Connect › Pricing and Availability, set a one-off price of **£2.99**. There are no in-app purchases.
4. **CloudKit.** Run the app once on a device signed into iCloud, save a watch, then in CloudKit Console › your container › Schema, **Deploy Schema Changes to Production**. Production builds can't sync until you do. After this, fields can be added but not removed or renamed.
5. **Privacy policy.** Publish `docs/privacy.md` and set `CROWNS_PRIVACY_URL`.
6. **Push.** `aps-environment` is `development` in `Config/Crowns.entitlements`; Xcode switches it to production when you archive for distribution. Nothing to change.
7. **Archive** with the Crowns scheme (Release). The share extension is embedded automatically.

## App Privacy (nutrition label)

**Data Not Collected.** Watches live in the user's private iCloud database, which the developer can't access, so that doesn't count as collection. The purchase goes through Apple.

The privacy manifests (`Crowns/PrivacyInfo.xcprivacy`, `CrownsShare/PrivacyInfo.xcprivacy`) declare no tracking, no collected data and UserDefaults use (reasons CA92.1, 1C8F.1 for the App Group).

Export compliance: `ITSAppUsesNonExemptEncryption = NO` is already in the Info.plist (HTTPS only).

## Listing copy (draft)

- **Name:** Crowns
- **Subtitle:** Your watch box
- **Promotional text:** Save any watch from Safari in two taps.
- **Description:**

  A watch box for your phone. Keep the watches you own and the ones you want, each in a simple grid.

  Save from anywhere. On a shop or eBay listing, tap Share, then Crowns. The photo, price and specs come with it.

  • Boxes of any size, each a simple grid
  • Grid view and list view
  • Prices in pounds, converted from any currency
  • Syncs with iCloud

- **Keywords:** watch,collection,wishlist,rolex,omega,horology,watches,box,collector,tracker
- **Review notes:** "To test saving: open any watch listing in Safari (e.g. a product page on omegawatches.com or an eBay listing), tap Share, then Crowns."

## Screenshots (6.9")

1. The Collection box, 5–6 watches
2. Share sheet over an eBay listing
3. A watch lifted into detail
4. List view
5. Box editor
