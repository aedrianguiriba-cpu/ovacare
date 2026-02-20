-- Setup RLS Policies for menstrual_cycles table
-- Run this in your Supabase SQL Editor to enable data syncing

-- First, ensure the table exists with correct structure
CREATE TABLE IF NOT EXISTS menstrual_cycles (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  flow integer default 0,
  notes text default '',
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  unique(user_id, start_date)
);

-- Enable RLS on the table
ALTER TABLE menstrual_cycles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow users to view their own cycles" ON menstrual_cycles;
DROP POLICY IF EXISTS "Allow users to insert their own cycles" ON menstrual_cycles;
DROP POLICY IF EXISTS "Allow users to update their own cycles" ON menstrual_cycles;
DROP POLICY IF EXISTS "Allow users to delete their own cycles" ON menstrual_cycles;

-- Create policies (most restrictive first)
-- SELECT: Users can only view their own menstrual cycles
CREATE POLICY "Allow users to view their own cycles" ON menstrual_cycles
  FOR SELECT USING (auth.uid() = user_id);

-- INSERT: Users can only insert menstrual cycles for themselves
CREATE POLICY "Allow users to insert their own cycles" ON menstrual_cycles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- UPDATE: Users can only update their own menstrual cycles
CREATE POLICY "Allow users to update their own cycles" ON menstrual_cycles
  FOR UPDATE USING (auth.uid() = user_id);

-- DELETE: Users can only delete their own menstrual cycles
CREATE POLICY "Allow users to delete their own cycles" ON menstrual_cycles
  FOR DELETE USING (auth.uid() = user_id);

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON menstrual_cycles TO authenticated;

-- Optional: Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_menstrual_cycles_user_id ON menstrual_cycles(user_id);
CREATE INDEX IF NOT EXISTS idx_menstrual_cycles_dates ON menstrual_cycles(user_id, start_date DESC);

-- Verify the setup
SELECT 'menstrual_cycles table setup complete' as status;
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables 
WHERE tablename = 'menstrual_cycles';
