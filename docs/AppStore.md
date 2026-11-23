# App Store prep

## Before the first TestFlight build

1. **Identifiers.** `Config/Crowns.xcconfig` → `CROWNS_BUNDLE_PREFIX`. App Group and iCloud container are permanent once registered.
2. **App Store Connect app.** Create it with bundle ID `<prefix>.crowns`. Primary category: Lifestyle.
3. **Price.** In App Store Connect › Pricing and Availability, set a one-off price of **£1.99**, with 1.99 in each country's own currency where Apple offers that price. There are no in-app purchases.
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
- **Promotional text:** Keep every watch you own and want in one simple grid. Save them from Safari with Apple Intelligence, or add any watch yourself.
- **Description:**

  Every watch you own. Every watch you want. One simple grid.

  Found one you like? Tap Share in Safari, then Crowns. The photos, price and specs come with it, ready to check and save.

  Saving from Safari needs an iPhone with Apple Intelligence turned on. Pages are read on your iPhone and never sent anywhere. On any iPhone, you can add a watch yourself: its details, a photo, and which box.

  • Save from any shop or listing (with Apple Intelligence)
  • Add any watch by hand, with your own photo
  • Pick the cover photo you like best
  • Sort watches into boxes: Wishlist, Collection, or your own
  • Switch between grid and list
  • Prices converted to pounds
  • Six app icons to choose from
  • Sync with iCloud. Only you can see your watches.

  One price. No subscription. No ads. No account.

- **Keywords:** watch,collection,wishlist,horology,watches,box,collector,tracker,timepiece,luxury
- **Review notes:** "Saving from Safari and Extract from URL need a device with Apple Intelligence turned on (iPhone 15 Pro or later). To test: open any watch listing in Safari, such as an eBay listing, tap ••• then Share, then Crowns. On a device without Apple Intelligence these are hidden by design, and the + button offers Add manually only."

## Screenshots

Seven app screens, no onboarding. Captions (headline / line under it): "Every watch you love, in one box." / "Your collection and wishlist, side by side." · "Know every watch inside out." / "Photo, price and specs, all on one page." · "Seen one you like? Save it in seconds." / "Share from Safari. Crowns brings the details." · "See your wishlist at a glance." / "Every name and price in one tidy list." · "Your photos. Your details." / "Replace any photo and fine-tune every spec." · "An icon to suit your taste." / "Six finishes, from Green to Midnight Blue." · "Just as good after dark." / "Every watch looks its best in Dark Mode." The last sits on black. iPhone shots come from an iPhone Air (1206 × 2622 for the required 6.1"/6.3" slot, 1260 × 2736 for 6.9"); iPad shots from a 13" iPad Pro simulator (2064 × 2752). The watches are invented, so no brand's photos or marks appear.

### Earlier plan (6.9")

1. The Collection box, 5–6 watches
2. Share sheet over an eBay listing
3. A watch in detail
4. List view
5. Box editor
