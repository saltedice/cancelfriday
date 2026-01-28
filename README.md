# SALT - Subscribers Against Lawless Tyranny

A weekly coordinated unsubscribe campaign app to protest ICE actions through collective economic action.

## How It Works

- Each week there's ONE target subscription service (Amazon Prime, Netflix, etc.)
- Everyone commits to cancel together at a specific moment (Friday at 12pm EST)
- Users vote for NEXT week's target
- Anonymous - no user data stored, just aggregate counts + fingerprint hashes
- Generates Instagram stories (9x16) to share

## Setup

### 1. Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a free account
2. Create a new project
3. Go to **SQL Editor** and run the contents of `supabase-schema.sql`
4. Go to **Settings > API** and copy:
   - Project URL (e.g., `https://xxxxx.supabase.co`)
   - `anon` public key

### 2. Configure the App

Edit `index.html` and replace the placeholder values at line ~865:

```javascript
const SUPABASE_URL = 'https://your-project.supabase.co';
const SUPABASE_ANON_KEY = 'your-anon-key-here';
```

### 3. Enable Realtime

In Supabase Dashboard:
1. Go to **Database > Replication**
2. Enable replication for `weeks` and `candidates` tables

### 4. Deploy

**Option A: Vercel (Recommended)**
```bash
npm i -g vercel
vercel
```

**Option B: Netlify**
```bash
npm i -g netlify-cli
netlify deploy --prod
```

**Option C: GitHub Pages**
Just push to a GitHub repo and enable Pages in settings.

## Local Development

```bash
npx serve .
```

Then open http://localhost:3000

## Weekly Admin Tasks

### Start a New Week

Run this SQL in Supabase SQL Editor:

```sql
-- Deactivate current week
UPDATE weeks SET is_active = false WHERE is_active = true;

-- Add new week (example: Week 2 with Netflix)
INSERT INTO weeks (week_number, target_id, target_name, target_parent, drop_time, is_active)
VALUES (2, 'netflix', 'Netflix', 'Netflix Inc.', '2025-02-07T17:00:00Z', true);

-- Add candidates for Week 2 voting
INSERT INTO candidates (id, name, parent, type, vote_count, week_number) VALUES
('prime', 'Amazon Prime', 'Amazon.com Inc.', 'Subscription', 0, 2),
('appletv', 'Apple TV+', 'Apple Inc.', 'Streaming', 0, 2),
('disney', 'Disney+', 'The Walt Disney Company', 'Streaming', 0, 2),
('spotify', 'Spotify Premium', 'Spotify AB', 'Subscription', 0, 2),
('hulu', 'Hulu', 'The Walt Disney Company', 'Streaming', 0, 2),
('max', 'Max', 'Warner Bros. Discovery', 'Streaming', 0, 2),
('paramount', 'Paramount+', 'Paramount Global', 'Streaming', 0, 2),
('youtube', 'YouTube Premium', 'Alphabet Inc.', 'Subscription', 0, 2),
('uber', 'Uber One', 'Uber Technologies', 'Convenience', 0, 2),
('doordash', 'DashPass', 'DoorDash Inc.', 'Convenience', 0, 2);
```

## Project Structure

```
salt/
├── index.html          # Main app (single file)
├── supabase-schema.sql # Database schema
├── vercel.json         # Vercel deployment config
├── package.json        # Project metadata
└── README.md           # This file
```

## Privacy

- No personal data is collected
- Browser fingerprints are hashed and only used to prevent duplicate votes/commits
- All data is aggregate counts only
- No cookies, no tracking, no analytics

## License

MIT
