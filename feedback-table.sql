-- Feedback Table for Supabase
-- Run this in the Supabase SQL Editor

-- Create feedback table
CREATE TABLE feedback (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- Allow anonymous inserts (anyone can submit feedback)
CREATE POLICY "Anyone can submit feedback" ON feedback FOR INSERT WITH CHECK (true);

-- Only authenticated users (you) can read feedback
CREATE POLICY "Only admins can read feedback" ON feedback FOR SELECT USING (auth.role() = 'authenticated');

-- Optional: If you want to read feedback without auth, use this instead:
-- CREATE POLICY "Anyone can read feedback" ON feedback FOR SELECT USING (true);
