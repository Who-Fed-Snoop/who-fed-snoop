# 🐾 Who Fed Snoop?

**Who Fed Snoop?** is a 1-tap pet feeding tracker and instant partner notifier built for **Keni, Ashley, and Snoop**—designed around the **2-Second Rule** so neither of you ever gets tricked into serving second breakfast again.

- **Domain:** [whofedsnoop.com](https://whofedsnoop.com)
- **GitHub Organization:** [github.com/Who-Fed-Snoop](https://github.com/Who-Fed-Snoop)

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
| `https://whofedsnoop.com/tap/{ID}` | **NFC Food-Bin Sticker ("The Snoop Tap Tag"):** Encoded onto an NTAG213 sticker on the dog food bin; tapping an unlocked phone logs the active meal automatically. |
| `https://whofedsnoop.com/s/{TOKEN}` | **Dog Sitter Web Pass:** Zero-install web view so a dog sitter or family guest can mark Snoop fed from any browser. |

## Getting Started

```bash
# 1. Install Flutter dependencies
flutter pub get

# 2. Run unit and widget tests
flutter test

# 3. Run the app on Android or Chrome
flutter run
```

