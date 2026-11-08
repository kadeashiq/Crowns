# App Store prep

## Before the first TestFlight build

1. **Identifiers.** `Config/Crowns.xcconfig` → `CROWNS_BUNDLE_PREFIX`. App Group and iCloud container are permanent once registered.
2. **App Store Connect app.** Create it with bundle ID `<prefix>.crowns`. Primary category: Lifestyle.
3. **Subscriptions.** In App Store Connect › Subscriptions, create one group, **Crowns Pro**, with:
   | Product ID | Duration | UK price |
   |---|---|---|
   | `crowns.pro.monthly` | 1 month | £1.99 |
   | `crowns.pro.yearly` | 1 year | £14.99 |
   Display name for both: "Crowns Pro". Description: "Keep more than 3 watches." Add a review screenshot of the paywall.
4. **CloudKit.** Run the app once on a device signed into iCloud, save a watch, then in CloudKit Console › your container › Schema, **Deploy Schema Changes to Production**. Production builds can't sync until you do. After this, fields can be added but not removed or renamed.
5. **Privacy policy.** Publish `docs/privacy.md` and set `CROWNS_PRIVACY_URL`.
6. **Push.** `aps-environment` is `development` in `Config/Crowns.entitlements`; Xcode switches it to production when you archive for distribution. Nothing to change.
7. **Archive** with the Crowns scheme (Release). The share extension is embedded automatically.

## App Privacy (nutrition label)

**Data Not Collected.** Watches live in the user's private iCloud database, which the developer can't access, so that doesn't count as collection. Purchases go through Apple.

The privacy manifests (`Crowns/PrivacyInfo.xcprivacy`, `CrownsShare/PrivacyInfo.xcprivacy`) declare no tracking, no collected data and UserDefaults use (reasons CA92.1, 1C8F.1 for the App Group).

Export compliance: `ITSAppUsesNonExemptEncryption = NO` is already in the Info.plist (HTTPS only).

## Listing copy (draft)

- **Name:** Crowns
- **Subtitle:** Your watch box
- **Promotional text:** Save any watch from Safari in two taps.
- **Description:**

  A watch box for your phone. Keep the watches you own and the ones you want, each on a cushion in a box you can see.

  Save from anywhere. On a shop or eBay listing, tap Share, then Crowns. The photo, price and specs come with it.

  • Boxes in walnut, ebony, oak or oxblood, any size
  • Box view and list view, with your box total
  • Prices in pounds, converted from any currency
  • Syncs with iCloud

  Free for 3 watches. Crowns Pro keeps as many as you like: £1.99 a month or £14.99 a year.

- **Keywords:** watch,collection,wishlist,rolex,omega,horology,watches,box,collector,tracker
- **Review notes:** "To test saving: open any watch listing in Safari (e.g. a product page on omegawatches.com or an eBay listing), tap Share, then Crowns. Subscriptions start after 3 saved watches."

## Screenshots (6.9")

1. The Collection box, walnut, 5–6 watches with cut-outs
2. Share sheet over an eBay listing
3. A watch lifted into detail
4. List view with total
5. Box editor with the four finishes
