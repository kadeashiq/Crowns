# App Store prep

## Before the first TestFlight build

1. **Identifiers.** `Config/Crowns.xcconfig` → `CROWNS_BUNDLE_PREFIX`. App Group and iCloud container are permanent once registered.
2. **App Store Connect app.** Create it with bundle ID `<prefix>.crowns`. Primary category: Lifestyle.
3. **Price.** In App Store Connect › Pricing and Availability, set a one-off price of **£2.99**. There are no in-app purchases.
4. **CloudKit.** Run the app once on a device signed into iCloud, save a watch, then in CloudKit Console › your container › Schema, **Deploy Schema Changes to Production**. Production builds can't sync until you do. After this, fields can be added but not removed or renamed.
5. **Links.** Privacy policy: https://www.kadeashiq.co/crowns/privacy. Support and marketing: https://www.kadeashiq.co/crowns. The pages live in the `kadeashiq-portfolio` repo.
6. **Push.** `aps-environment` is `development` in `Config/Crowns.entitlements`; Xcode switches it to production when you archive for distribution. Nothing to change.
7. **Archive** with the Crowns scheme (Release). The share extension is embedded automatically.

## App Privacy (nutrition label)

**Data Not Collected.** Watches live in the user's private iCloud database, which the developer can't access, so that doesn't count as collection. The purchase goes through Apple.

The privacy manifests (`Crowns/PrivacyInfo.xcprivacy`, `CrownsShare/PrivacyInfo.xcprivacy`) declare no tracking, no collected data and UserDefaults use (reasons CA92.1, 1C8F.1 for the App Group).

Export compliance: `ITSAppUsesNonExemptEncryption = NO` is already in the Info.plist (HTTPS only).

## Listing copy

- **Name:** Crowns
- **Subtitle:** Your watch collection, sorted
- **Promotional text:** Save any watch from Safari in two taps. Keep what you own and what you want in one simple grid.
- **Description:**

  Every watch you own. Every watch you want. One simple grid.

  Found one you like? Tap Share in Safari, then Crowns. The photo, price and specs come with it.

  • Save from any shop or listing
  • Pick your cover photo
  • Sort watches into boxes
  • Switch between grid and list
  • See every price in pounds
  • Sync with iCloud

  One price. No subscription. No ads.

- **Keywords:** watch,collection,wishlist,horology,watches,box,collector,tracker,timepiece,luxury
- **Review notes:** "To test saving: open any watch listing in Safari, such as an eBay listing, tap ••• then Share, then Crowns."

## Screenshots (6.9")

1. The Collection box, 5–6 watches
2. Share sheet over an eBay listing
3. A watch in detail
4. List view
5. Box editor
