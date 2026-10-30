# AIRGRAM — Android social app

**ANI STUDIO** · Your world. Your people.

AIRGRAM is an Android-native social app built with Kotlin + Jetpack Compose and a Supabase backend.

## Current build (foundation phase)
- Android app shell with AIRGRAM branding and dark UI
- Email/password sign-up and sign-in through Supabase Auth
- Authenticated public-feed read from `airgram_posts`
- Text post publishing
- GitHub Actions workflow that builds and uploads a debug APK artifact

## Supabase backend
The AIRGRAM foundation migration is applied to the existing Supabase project in Mumbai (`ap-south-1`). AIRGRAM tables use the `airgram_` prefix so they do not collide with other apps in that project.

Included database foundations:
- profiles, posts, up-to-20 media metadata, follows, likes, comments, saved collections
- stories and story views
- conversations, members, messages, notifications
- blocks, reports, drafts
- private `airgram-media` Storage bucket with per-user folder policies
- Row Level Security enabled on every AIRGRAM table

The Android app contains only the Supabase URL and publishable key. Never put a Supabase secret/service-role key in an APK.

## Build the APK
1. Open the **Actions** tab in this repository.
2. Run **Build AIRGRAM APK** (or push a commit to `main`).
3. Open the successful workflow run.
4. Download the `AIRGRAM-debug-APK` artifact and install the APK on an Android device.

This is a debug APK, not a Play Store release. A signed release build needs a private signing key configured as GitHub Actions secrets.

## Roadmap
1. Foundation — auth, profile, backend and app shell
2. Social — media upload, feed, likes, comments, follows, saves, drafts
3. Direct — private/group chats, realtime, attachments and notifications
4. Stories — close friends, highlights, polls, Notes and archive
5. Reels Studio — editing timeline, effects, captions, beat matching and export
6. Explore — search, topics, trends and recommendation controls
7. AI Lab — provider-backed creative tools with usage/cost controls
8. Live & Creator — streaming, analytics, business tools and subscriptions
9. Security — MFA, privacy controls, moderation, export and account deletion
10. Release — testing, performance, accessibility and signed release

Advanced items such as end-to-end encryption, live/video calls, music licensing, AI generation, payments and live streaming are **not implemented yet**. They need dedicated services, security reviews, licensing or payment-provider setup. UI placeholders are not treated as working features.

## Configuration
The project currently targets the AIRGRAM Supabase project already connected by the owner. If you fork this repository, replace `SUPABASE_URL` and `SUPABASE_KEY` in `app/build.gradle.kts` with your own project URL and publishable key. Never use a secret key in client code.

## Tech
- Kotlin, Android SDK 36, min SDK 26
- Jetpack Compose + Material 3
- Supabase Auth, Postgres, RLS and Storage
- GitHub Actions
