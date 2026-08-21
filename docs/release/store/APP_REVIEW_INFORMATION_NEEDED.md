# App Review Information Needed (Guideline 2.1) — draft, not submitted

Do not paste the demo password into git. The live password stays only in App Store Connect Review Information.

## ASC Notes field (keep under 4000 bytes)

```
HiAir is a wellness app for outdoor heat and air quality (not medical diagnosis or emergency care). Target users: adults 13+ who want safer outdoor windows. Core value: live/cached air+heat risk, planner, private symptom journal, optional Apple Health aggregates, Premium insights.

Demo login: use the Sign-in Required fields (appstore.review@hiair.io). Backend: https://api.hiair.io (live).

How to review:
1) Launch → Log in (primary) or Register; Sign in with Apple; Google via in-app ASWebAuthenticationSession (not Safari).
2) Onboarding: persona + DOB (13+). Location/notifications: Continue → system sheets. Health: Continue → system HealthKit sheet (no Skip). Deny still uses the app.
3) Dashboard: risk, metrics, safer windows. Planner / Insights / Symptoms (private journal, not social UGC).
4) Settings → Upgrade to Premium: monthly com.hiair.premium.monthly and yearly com.hiair.premium.yearly. Paywall shows distinct Monthly/Yearly titles, Length, App Store price, auto-renew text, in-app Terms https://hiair.io/terms/ and Privacy https://hiair.io/privacy/. Restore + Manage subscription are on the paywall and in Settings.
5) Settings → Email support hello@hiair.io, site https://hiair.io, export data, Delete account (warns Apple billing continues; optional revoke Sign in with Apple).

IAP path: Settings → Upgrade to Premium. Use a Sandbox Apple Account (Settings → Developer → Sandbox Apple Account), not the device primary Apple ID.

Please review the latest TestFlight build that fixes the prior 183 rejection (SwiftUI PurchaseAction UI anchor on iPad, required title/length/price on each plan card, Terms/Privacy). Prefer build **188+**.

Tested: physical iPhone 17 Pro iOS 26.6; iPhone + iPad simulators iOS 26. External: Supabase, Cloudflare api.hiair.io, Open-Meteo, optional OpenAI, HealthKit, StoreKit.

Not a regulated medical device. No third-party protected content. No public UGC.
```

## Screen recording script (physical device, latest iOS)

Record from a cold launch. One continuous take if possible.

1. Launch HiAir.
2. Register a new email (or demo login if already installed).
3. Sign out → Sign in with Apple (in-app).
4. Sign out → Google (ASWebAuthenticationSession sheet, not Safari).
5. Onboarding: DOB 13+, persona, Continue on location → system location sheet, Continue on Health → system HealthKit sheet (grant or deny once, then show the app still works).
6. Dashboard risk + hourly/safe windows.
7. Planner, Insights, Symptoms (add one private log).
8. Settings → Upgrade to Premium: show monthly/yearly title, period, price, Terms, Privacy, auto-renew text. Open Manage subscription (cancel the sheet). Restore purchases.
9. Settings → support email / site / Terms / Privacy.
10. Settings → Delete account dialog (read the subscription warning). Cancel (do not delete the demo account). Optionally show Delete and revoke Sign in with Apple on a throwaway Apple sandbox user.

Upload the recording in App Store Connect Review Information attachments (or Resolution Center). Notes field cannot hold the video.

## Devices / OS to list in Notes

- Physical: iPhone 17 Pro (iPhone18,1), iOS 26.6 (23G71)
- Simulator used in development: iPhone 17 Pro / iPad Air 11" (M3), iOS 26.5

## Website

Live `https://hiair.io/terms/` and `https://hiair.io/privacy/` — effective 14 August 2026, 13+, `hello@hiair.io`, no draft wording.

## Status

**183 REJECTED** 2026-08-16 (iPad Air 11 M3): Guideline **2.1(b)** sandbox purchase error + **3.1.2(c)** missing title/length/price/Terms/Privacy.

**186** TestFlight VALID — rejection code fixes shipped; ASC version still pointed at build 183 until resubmit.

**187** TestFlight VALID — earlier iPad `confirmIn:scene` hardening.

**188** (this tree): paywall purchases go through SwiftUI `PurchaseAction` so StoreKit can find the iPad fullScreenCover window (Guideline **2.1(b)** on iPadOS 26). Each subscribe card shows title, length, and App Store price (Guideline **3.1.2(c)**). Upload TestFlight only — **do not App Store Submit until owner verifies**.
