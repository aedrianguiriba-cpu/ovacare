-- Fix RLS policies to allow voting on posts/comments
-- Run this in your Supabase SQL Editor

-- Drop old restrictive policies
drop policy if exists "forum_posts_update" on forum_posts;
drop policy if exists "forum_comments_update" on forum_comments;

-- Create new policies that allow voting
-- Posts: owner can update content, anyone authenticated can update votes/comments_count
create policy "forum_posts_update_owner" on forum_posts
  for update using (auth.uid() = user_id);

create policy "forum_posts_update_votes" on forum_posts
  for update using (auth.uid() is not null);

-- Comments: owner can update content, anyone authenticated can update votes
create policy "forum_comments_update_owner" on forum_comments
  for update using (auth.uid() = user_id);

create policy "forum_comments_update_votes" on forum_comments
  for update using (auth.uid() is not null);
