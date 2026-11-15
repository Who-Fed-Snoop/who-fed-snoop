# 🐾 Who Fed Snoop?

**Who Fed Snoop?** is a 1-tap pet feeding tracker and instant partner notifier built for **Keni, Ashley, and Snoop**—designed around the **2-Second Rule** so neither of you ever gets tricked into serving second breakfast again.

- **Domain:** [whofedsnoop.com](https://whofedsnoop.com)
- **Live Web App:** [who-fed-snoop.web.app](https://who-fed-snoop.web.app)
- **GitHub Organization:** [github.com/Who-Fed-Snoop](https://github.com/Who-Fed-Snoop)
- **Original Vision, Product & Business Plan:** [docs/PROJECT_VISION_AND_PLAN.md](docs/PROJECT_VISION_AND_PLAN.md)
- **UI Design Direction & Architectural Decisions:** [docs/DESIGN_DIRECTION_AND_DECISIONS.md](docs/DESIGN_DIRECTION_AND_DECISIONS.md)
- **Productization Gap Analysis & Roadmap:** [docs/PRODUCTIZATION_GAPS_AND_ROADMAP.md](docs/PRODUCTIZATION_GAPS_AND_ROADMAP.md)
- **Developer Loop (Build, Test, Release & Deploy):** [docs/DEVELOPMENT_LOOP.md](docs/DEVELOPMENT_LOOP.md)

---

## Architecture & Project Structure

```text
who-fed-snoop/
├── lib/
│   ├── main.dart                                      # App entry point
│   ├── domain/
│   │   └── models/
│   │       ├── meal_window.dart                       # Automatic Breakfast (4 AM) / Dinner (2 PM) window engine
│   │       ├── feeding_event.dart                     # Deterministic meal event model
│   │       ├── household.dart                         # Household & Member domain models
│   │       └── deep_link_route.dart                   # Deep link parser for whofedsnoop.com (/join, /tap, /s)
│   ├── data/
│   │   ├── repositories/
│   │   │   └── household_repository.dart              # Repository interface + real-time stream implementation
│   │   └── services/
│   │       └── widget_sync_service.dart               # Android Home Screen Widget snapshot sync
│   └── ui/
│       ├── core/
│       │   └── app_theme.dart                         # Hungry Amber vs. Fed Emerald Material 3 theme
│       └── features/
│           ├── feeder/
│           │   ├── view_models/feeder_view_model.dart # MVVM ChangeNotifier (1-tap feed, 10s Undo, partner sim)
│           │   └── views/feeder_view.dart             # Main 1-tap screen + widget preview + 7-day history
│           └── onboarding/
│               └── views/onboarding_sheet.dart        # 6-digit household join code & creation sheet
├── functions/
│   └── src/index.ts                                   # Firebase Cloud Function (FCM push notification trigger)
├── firestore.rules                                    # Hardened Cloud Firestore Security Rules
├── firebase.json                                      # Firebase Hosting (whofedsnoop.com), Functions & Firestore config
└── test/
    ├── domain/meal_window_test.dart                   # Unit tests for meal windows & whofedsnoop.com deep links
    └── ui/feeder_view_test.dart                       # Widget test for 1-tap feed & 10-second Undo
```

## Deep Link Routes on `whofedsnoop.com`

| URL Pattern | Purpose |
| :--- | :--- |
| `https://whofedsnoop.com/join/{CODE}` | **1-Tap Partner Invite:** Opens the app (via Android App Links) or web app and joins the household automatically. |
| `https://whofedsnoop.com/tap/{ID}` | **NFC Food-Bin Sticker ("The Snoop Tap Tag"):** Encoded onto an NTAG213/215/216 sticker on the dog food bin; tapping an unlocked phone logs the active meal automatically. |
| `https://whofedsnoop.com/s/{TOKEN}` | **Dog Sitter Web Pass:** Zero-install web view so a dog sitter or family guest can mark Snoop fed from any browser. |

---

## 🏷️ How to Program & Use Your NFC Stickers ("The Snoop Tap Tag")

You can program any standard **NTAG213, NTAG215, or NTAG216** NFC sticker from Amazon so that tapping your unlocked phone on Snoop's kibble bin automatically logs Breakfast or Dinner and notifies your partner.

### 1. Copy Your Household's NFC Tag URL
1. Open **Who Fed Snoop?** and tap the gold **`Pack: SNOOP4`** button in the top-right corner of the header to open **Snoop's Pack HQ**.
2. Scroll down to **whofedsnoop.com Smart Links (Tap to Copy)**.
3. Tap the **NFC Food-Bin Sticker URL** (`KIBBLE BIN`) card to copy your tag URL to the clipboard:
   ```text
   https://whofedsnoop.com/tap/household_snoop_01
   ```
   *(If you created a custom household, this card will automatically copy `https://whofedsnoop.com/tap/{your_household_id}`.)*

### 2. Write the URL to a Blank NFC Sticker
1. Install the free **NFC Tools** app (by Wakdev) on your phone ([Google Play](https://play.google.com/store/apps/details?id=com.wakdev.wdnfc) / [iOS App Store](https://apps.apple.com/us/app/nfc-tools/id1252962749)).
2. Open **NFC Tools** and switch to the **Write** tab.
3. Tap **Add a record** → choose **URL / URI** *(important: select **URL / URI**, not plain **Text**, so the sticker is formatted as an NDEF URI record that triggers automatic launch)*.
4. Paste your copied link (`https://whofedsnoop.com/tap/household_snoop_01`).
   - **Check the prefix:** Since NFC Tools defaults the dropdown to `https://`, make sure the text field only contains `whofedsnoop.com/tap/household_snoop_01` so the final URI isn't doubled (`https://https://...`).
5. Tap **OK**, then tap **Write / ~42 Bytes**.
6. Hold the back of your phone steady against the blank NFC sticker for 1–2 seconds until you see **Write complete!**.
   - *Tip:* Leave the sticker **unlocked** (do not tap "Lock tag") so you can reprogram or reuse it anytime.

### 3. Stick It on Snoop's Food Station (Avoid Bare Metal!)
- **Ideal surfaces:** Plastic kibble bin lids, the plastic food scoop handle, or the wall/cabinet right above the dog bowl.
- **Warning about metal tins:** Standard Amazon NFC stickers will **not** scan if stuck directly onto bare stainless steel or aluminum (metal detunes the 13.56 MHz antenna). If Snoop's food bin is metal, stick the tag on a plastic lid/handle or place a ~3 mm foam/cardboard spacer between the metal surface and the sticker.

### 4. Daily Tap-to-Feed Workflow
1. **Unlock your phone** (Android and iOS only scan passive NFC tags when the screen is awake and unlocked).
2. **Tap your phone to the sticker** while scooping Snoop's food:
   - **Android (Native App):** Matches the `NDEF_DISCOVERED` / App Links intent filter in `AndroidManifest.xml`, brings **Who Fed Snoop?** to the foreground, logs the active meal window (`Breakfast` between 4:00 AM – 1:59 PM, `Dinner` from 2:00 PM – 3:59 AM), syncs the Android Home Screen Widget, and displays:
     > `🏷️ Instant Tap-to-Feed: Logged Breakfast/Dinner for Snoop!`
   - **Web / iOS / Any Browser:** Opens `https://whofedsnoop.com/tap/household_snoop_01`, automatically logs the active meal for the current window, and syncs across all devices in real time.
3. **Duplicate-Tap Protection & Undo:**
   - **Idempotent Meal IDs:** Regular meals use deterministic IDs (`YYYY-MM-DD_breakfast` / `YYYY-MM-DD_dinner`), so accidentally double-tapping the sticker will **never** log a duplicate meal.
   - **10-Second Undo:** Bumped the sticker by mistake without feeding Snoop? Tap **`UNDO`** in the bottom countdown bar within 10 seconds to revert the log.

### Troubleshooting NFC Scans
| Symptom | Fix |
| :--- | :--- |
| Nothing happens when tapping the sticker | Ensure **NFC** is toggled ON in **Settings → Connected devices → Connection preferences → NFC** (Android) and that your phone screen is **unlocked**. Find your phone's NFC antenna sweet spot (usually near the top-center or camera bar on Pixels/iPhones, or center-back on Samsung Galaxy). |
| Sticker worked before sticking it down, now won't scan | The sticker is likely adhered to a **metal surface**. Peel it off and move it to plastic, wood, drywall, or add a non-metallic spacer. |
| Opens a Google search instead of the URL | The tag was written as a **Text** record or has a duplicate `https://https://` prefix. Re-write the tag in NFC Tools using **Add a record → URL / URI**. |

---

## Development & Release Quickstart

See **[docs/DEVELOPMENT_LOOP.md](docs/DEVELOPMENT_LOOP.md)** for the full developer loop (offline vs. Firebase Emulator vs. live modes, test suites, APK/web/macOS builds, GitHub Releases, and Firebase deploys).

```bash
# 1. Install dependencies & git hooks
flutter pub get
./scripts/install-git-hooks.sh

# 2. Run locally ($0 offline in-memory mode, or omit flag for live Firebase)
flutter run -d chrome --dart-define=USE_IN_MEMORY_REPO=true

# 3. Format, lint, test & verify web release bundle
dart format lib test
./scripts/verify.sh

# 4. Build Android split-ABI APKs & deploy web + Firestore rules
flutter build apk --release --split-per-abi
firebase deploy --only firestore,hosting --project who-fed-snoop
```

