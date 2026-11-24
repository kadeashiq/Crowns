# App Review notes

Pasted into App Store Connect › version › App Review Information › Notes, in
answer to the Guideline 2.1 "Information Needed" request for version 1.0. The
screen recording goes in the Attachment field.

---

1. SCREEN RECORDING
Attached (Crowns-App-Review.mp4). Recorded on an iPhone Air running iOS 27.2.1 with the submitted build. It shows the app's core flow: a watch listing open in Safari is shared to Crowns through the Share sheet, Crowns reads the photos, price and specifications from the page, the details are checked and saved, then Crowns is opened from the Home Screen, where the saved watch appears in its box and its detail page is shown. Crowns has no account registration, login, user-generated content shared with other people, or in-app purchases. It is a one-off paid app, so every feature is available after download.

2. PURPOSE AND AUDIENCE
Crowns is a personal catalogue for watch enthusiasts and collectors. People who follow watches tend to keep the ones they own and the ones they want scattered across screenshots, bookmarks and notes. Crowns keeps them in one place, laid out like a watch box: each watch with its photo, price and specifications, sorted into boxes such as Wishlist and Collection. The value is a tidy, private record of a collection and a wishlist that is quick to add to and pleasant to browse.

3. HOW TO USE IT
No login, credentials or sample files are needed.
- Launch Crowns. A short welcome explains the app, asks whether to keep watches in iCloud, and which box to open on.
- Add a watch by hand: tap +, then Add manually. Enter a brand and model, optionally a photo from the camera or library, then Save. This works on every device.
- Save a watch from Safari (devices with Apple Intelligence turned on, such as iPhone 15 Pro or later): open any watch product page in Safari, for example https://www.christopherward.com/C60-40ADA31S0KK1-B0.html, tap Share (in Safari's toolbar, or in the ••• menu), then Crowns. The photos, price and specs are read from the page; check them and tap Save. In the app, + then Extract from URL does the same with a pasted link.
- Tap any watch to see its details. Edit changes the details or replaces the photo; the arrow button next to the shop link reads the page again.
- The buttons at the top switch between grid and list view and open Settings, where the app icon, iCloud sync and boxes are managed.

4. EXTERNAL SERVICES
- Apple iCloud (CloudKit private database): optional sync of the user's own watches between their devices. Only the user can access it.
- Apple Foundation Models (on-device Apple Intelligence): helps read details from a shared product page. Runs entirely on the device; nothing is sent to a server.
- Frankfurter (api.frankfurter.app), a free, open exchange-rate API: daily rates to convert foreign prices to pounds. The request contains no user data.
- The shop's own website: when the user shares or pastes a link, Crowns loads that page and its photos directly, as a browser would.
There is no analytics, advertising, authentication or payment service. The purchase is handled by the App Store.

5. REGIONAL DIFFERENCES
Crowns works the same in every region where it is available. The one difference depends on the device rather than the region: saving from Safari and Extract from URL appear only where Apple Intelligence is available and turned on; elsewhere the + button offers Add manually only. Prices are shown in pounds everywhere. The app is not offered in mainland China.

6. REGULATION AND THIRD-PARTY MATERIAL
Crowns does not operate in a regulated industry and ships no third-party content. It reads publicly available product pages only when the user chooses to share or paste one, and stores the result privately on the user's device and in their own iCloud for personal reference. The watches shown in the screenshots are invented and do not depict any real brand.
