# AIRGRAM Web

React + Vite web client for AIRGRAM, using the existing Supabase project.

## Local development
1. Copy `.env.example` to `.env.local`.
2. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` to the existing project URL and publishable key.
3. Run `npm install`, then `npm run dev`.

## Vercel
Import the repository and set its Root Directory to `web`. Use Vite, `npm run build`, and `dist`. Add:
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY` (publishable key only)
- Optional `VITE_SITE_URL` (production URL)

Then configure Supabase Authentication → URL Configuration:
- Site URL: the final HTTPS production URL.
- Redirect URLs: production `/auth/callback`, plus `https://*-<your-vercel-team>.vercel.app/**` for previews and `http://localhost:5173/**` for local development.

Request a new confirmation email after updating redirects. Old expired OTP links remain expired.
