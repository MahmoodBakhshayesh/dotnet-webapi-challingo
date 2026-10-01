# Challingo launch checklist

Everything outside the code that Challingo needs before launch: accounts, keys, settings, content, and the
features still to build that depend on them. Secrets go straight into `challingo-api/.env` (local) or
`challingo-deploy/api.env` → `server-files/.env` (server); never paste them in chat or commit them.

Detailed server steps: `challingo-deploy/SETUP-GUIDE.md` (§7.5.2 covers ads and Plus).

---

## 0. Before anything: where you sign up from

Apple, Google Play, AdMob and RevenueCat all pay out only to people or companies with a **legal residence and a
bank account in a supported country**, and US sanctions exclude some countries (for example Iran) entirely.
If you are based in one of those, you need a legal entity or a partner/publisher in a supported country **before**
creating the accounts below. Otherwise the app can still ship free, but subscriptions and ad revenue cannot be paid out.

---

## 1. Accounts to create

| # | Service | Cost | Needed for |
|---|---------|------|------------|
| 1 | **Apple Developer Program** | $99 / year | iOS app, TestFlight, subscriptions, push (APNs) |
| 2 | **Google Play Console** | $25 once | Android app, subscriptions |
| 3 | **RevenueCat** | Free up to $2.5k monthly revenue, then 1% | Plus subscriptions (both stores) |
| 4 | **Google AdMob** | Free (Google keeps its share of ad revenue) | Rewarded ads |
| 5 | **Firebase** (Google) | Free (Spark plan is enough for push) | Push notifications (FCM), optional crash reports |
| 6 | **Domain** (e.g. `challingo.app`) | ~$15–20 / year | API, admin panel, invite links, privacy policy, app-ads.txt |
| 7 | **VPS** (Hetzner, DigitalOcean, …) | ~$10–25 / month to start (2 vCPU, 4 GB RAM) | API, Worker, Postgres, Redis, web admin |
| 8 | **Transactional email** (Amazon SES, Postmark, Resend, Mailgun) | Free tier → ~$1 / 10k emails (SES) | Sign-in codes by email |
| 9 | **Container registry** (GitHub Container Registry or Docker Hub) | Free for private images on GHCR | `build-and-push-*` scripts |
| 10 | Optional: **Sentry** or Firebase Crashlytics | Free tier | Crash and error reports |
| 11 | Optional: off-site backup storage (S3-compatible: Backblaze B2, Hetzner Storage Box) | ~$1–5 / month | Postgres backups |

---

## 2. Apple (App Store Connect)

1. Enroll in the Apple Developer Program (individual, or organization with a D-U-N-S number).
2. **Certificates, IDs & Profiles** → App ID `com.zojaji.challingo` with capabilities: **Push Notifications**,
   **Associated Domains** (for invite links), **In-App Purchase**.
3. **App Store Connect → My Apps → New App** (name, bundle id, SKU).
4. **Agreements, Tax, and Banking**: sign the **Paid Apps** agreement and add bank + tax info (subscriptions don't work without it).
5. **Subscriptions**: create a subscription group "Challingo Plus" with products, e.g.
   `challingo_plus_monthly`, `challingo_plus_yearly` (prices, localized names, review screenshot).
6. **Keys** (Users and Access → Integrations):
   - **In-App Purchase key** (.p8) → upload to RevenueCat.
   - **APNs auth key** (.p8, note Key ID + Team ID) → upload to Firebase for push.
7. App privacy ("nutrition labels"): data collected (email, user id, gameplay, device id for ads/attribution, purchases).
8. Age rating questionnaire: answer the daily draw honestly (free, no real-money prize → "Simulated Gambling: infrequent/mild"
   is the safe answer; expect 12+).
9. TestFlight for beta testers.

**Apple review requirements to meet before submitting:**
- **In-app account deletion** (guideline 5.1.1(v)) — *to build* (see §9).
- Daily draw: official rules in the app (done: "How it works") plus "Apple is not a sponsor" wording (*to add*), and it must stay free.
- Restore purchases button (done), subscription terms text (done), links to privacy policy + terms on the Plus screen (*to add once URLs exist*).

---

## 3. Google Play Console

1. Create the developer account (personal or organization) and the app (`com.zojaji.challingo`).
2. **Payments profile** (merchant account) — needed for subscriptions.
3. **Subscriptions**: same product ids as Apple (`challingo_plus_monthly`, `challingo_plus_yearly`) with base plans.
4. **Upload key**: create a release keystore (`keytool …`), store it safely, wire it into
   `android/app/build.gradle.kts` (*currently release builds are signed with the debug key — must change*).
5. **Service account** for RevenueCat: Google Cloud → service account with Play Developer API access, JSON key → RevenueCat.
6. **Real-time developer notifications**: Pub/Sub topic RevenueCat gives you → paste in Play Console (Monetization setup).
7. Store listing, **Data safety** form, **content rating** (IARC), **target audience**, **contains ads: yes**,
   privacy policy URL.
8. **Testing rule for new personal accounts**: a closed test with at least **12 testers for 14 days** before production access.

---

## 4. RevenueCat (Plus)

1. Create a project; add the **iOS app** (bundle id + In-App Purchase key) and **Android app** (package + service account JSON).
2. Import the products; create entitlement **`plus`** and attach both products.
3. Offering **`default`** (current) with packages **Monthly** and **Annual**.
4. **Integrations → Webhooks**: URL `https://api.<your-domain>/api/webhooks/revenuecat`, Authorization header = a long random string you choose.
5. Keys:
   - Public SDK keys `appl_…` and `goog_…` → app build (`--dart-define=RC_APPLE_KEY=… --dart-define=RC_GOOGLE_KEY=…`).
   - Secret key `sk_…` → server `Monetization__RevenueCat__SecretApiKey`.
   - The webhook string → server `Monetization__RevenueCat__WebhookAuthorization`.

---

## 5. Google AdMob (rewarded ads)

1. Create the AdMob account (payments profile + tax info).
2. Add two apps (iOS, Android) → note the **app ids** `ca-app-pub-…~…`.
3. One **Rewarded** ad unit per app → note the **ad unit ids** `ca-app-pub-…/…`.
4. On each rewarded unit: **Server-side verification** URL `https://api.<your-domain>/api/webhooks/admob/ssv`.
5. **Privacy & messaging**: publish the **GDPR** consent message, the **US state regulations** message, and the **IDFA (iOS) explainer**.
6. **app-ads.txt**: put the line AdMob gives you at `https://<your-domain>/app-ads.txt`; the same domain must be the
   "website" in both store listings.
7. Settings:
   - App build: `--dart-define=ADMOB_REWARDED_IOS=… --dart-define=ADMOB_REWARDED_ANDROID=…`
   - iOS app id: `ADMOB_APP_ID` in `ios/Flutter/Release.xcconfig` (and Debug if you want real ads in debug)
   - Android app id: `-PadmobAppId=…` (or edit the default in `android/app/build.gradle.kts`)
   - Server (optional): `Monetization__AdMob__AllowedAdUnits=<ios unit>,<android unit>`
8. Optional: add Google's full **SKAdNetwork** id list to `ios/Runner/Info.plist` (only Google's own id is there now).

---

## 6. Firebase (push notifications — feature still to build)

1. Create a Firebase project; add the iOS app (`com.zojaji.challingo`) and the Android app.
2. Download **`GoogleService-Info.plist`** (iOS) and **`google-services.json`** (Android).
3. Cloud Messaging → upload the **APNs auth key** (.p8, Key ID, Team ID).
4. Project settings → Service accounts → **generate a private key (JSON)** for the server (FCM HTTP v1).
5. iOS: enable Push Notifications + Background Modes (remote notifications) in Xcode.

What I'll build once these exist: device-token registration, a notification settings screen (per type, quiet hours by
your local time), and server sends from the Worker:
- a run of a favourite game opening soon,
- "picks close in 1 hour" for the daily draw (13:00 UTC), new digits / you're still in / results,
- stars won (podium, draw), group activity, Grand Challenge on Sunday.

---

## 7. Domain, server and email

1. **DNS**: `api.<domain>` → VPS, `admin.<domain>` → VPS (web admin), root/`www` → a simple site (privacy, terms, support, app-ads.txt, invite-link fallback page).
2. **TLS**: Let's Encrypt via the scaffold's nginx setup (SETUP-GUIDE).
3. **Server env** (`challingo-deploy/api.env` → `sync-server-env` → `server-files/.env`):
   - `POSTGRES_PASSWORD`, `REDIS_PASSWORD` (strong random)
   - `Jwt__Key` (64+ random chars), `Jwt__Issuer`, `Jwt__Audience`
   - `Auth__SeedAdminEmail`, `Auth__SeedAdminPassword` (change from the local one)
   - `Cors__AllowedOrigins__0=https://admin.<domain>`
   - `Competition__InviteBaseUrl=https://<domain>/g/`, `Competition__AllowAdminTimeTravel=false`
   - `Monetization__*` (above), `Monetization__AllowDevRewards=false`
   - `Otp__DevMode=false`, `Otp__LogOnly=false`
4. **Email (sign-in codes)**: verify your domain with the provider (SPF, DKIM, DMARC DNS records), then
   `Email__Enabled=true`, `Email__SmtpHost`, `Email__SmtpPort`, `Email__SmtpUsername`, `Email__SmtpPassword`,
   `Email__FromAddress=no-reply@<domain>`, `Email__FromDisplayName=Challingo`.
5. **Not used by Challingo** (leave off): `Sms__*`, `Auth__EnablePhoneAuth`, `Google__ClientId` (no Google sign-in in the app).
6. **Backups**: `backup-db.sh` runs on the server; copy the dumps off the server (B2 / Storage Box).
7. **Invite links** (`<domain>/g/CODE` opening the app) — *to build once the domain is fixed*: serve
   `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json`, add Associated Domains (iOS) and an
   intent filter (Android).

---

## 8. Content and legal

- **Word Guess answers**: a few hundred approved common 5-letter words (48 runs a day) — paste in Admin → Word Guess answers.
- **Mini Crosswords**: about 6 a day → build a bank of a few hundred in Admin → Crosswords.
- **Remove dev test content**: Word Guess CRANE/SLATE/PLANT/BRICK/CLOUD/GLOBE, crosswords CAT/BOX and SUN/DOT, test guests and the "Office League" group.
- **Privacy policy** and **terms of service** (hosted on your domain): what you collect, ads (AdMob), purchases (RevenueCat), push, account deletion, contact.
- **Daily draw rules page**: free entry, stars have no cash value and can't be bought or exchanged, how winners are chosen, "Apple and Google are not sponsors".
- **Trademark check** for the name "Challingo" before printing it everywhere.
- **Store assets**: app icon (1024×1024), screenshots (6.7" and 6.5" iPhone, Android phone), short and long descriptions, support email/URL.

---

## 9. Still to build before launch (code)

| Item | Why |
|------|-----|
| In-app account deletion (API + app) | Apple requirement 5.1.1(v), Google requirement |
| Push notifications (Firebase) | Engagement: runs, daily draw, results |
| Achievements | Last planned game feature |
| Invite universal links / App Links | `challingo.app/g/CODE` opening the app |
| Privacy/terms links on Plus screen and profile | Store review |
| Android release signing config | Release builds are signed with the debug key today |
| Crash reporting (Sentry or Crashlytics) | See crashes in the wild |
| Production clean-up | Remove dev test content and test accounts |

---

## 10. What to send me (only non-secret values)

- Your **domain** (and whether `api.` / `admin.` subdomains are fine).
- **Apple Team ID**; confirm bundle id `com.zojaji.challingo` and the display name "Challingo".
- **AdMob** app ids and rewarded ad unit ids (iOS + Android).
- **RevenueCat** public SDK keys (`appl_…`, `goog_…`) and your product ids.
- **Support email** and your company/legal name for the privacy policy and terms.
- When ready: the Firebase config files (`GoogleService-Info.plist`, `google-services.json`) — put them in the repo yourself or tell me where they are.

Keep these **out of chat** and put them in the env files yourself: RevenueCat secret key, webhook authorization
string, SMTP password, Firebase service-account JSON, Apple .p8 keys, Android keystore and passwords, database/Redis/JWT/admin secrets.
