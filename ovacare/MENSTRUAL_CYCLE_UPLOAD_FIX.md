# Menstrual Cycle Database Upload - Troubleshooting Guide

## Problem: Menstrual cycles not uploading to Supabase

This guide helps diagnose and fix data upload issues.

## Root Cause: RLS (Row Level Security) Policies

The most common reason data won't upload is that **Supabase RLS policies aren't configured correctly** for your `menstrual_cycles` table.

## Solution: Set Up RLS Policies

### Step 1: Open Supabase Dashboard
1. Go to [supabase.com](https://supabase.com)
2. Log in and select your project
3. Go to **SQL Editor** (left sidebar)

### Step 2: Run the RLS Setup Script
1. Copy all the SQL from: `SUPABASE_MENSTRUAL_CYCLES_RLS.sql`
2. Paste it into the SQL Editor
3. Click **Run**

### Step 3: Verify the Setup
You should see message: `"menstrual_cycles table setup complete"`

## Troubleshooting Steps

### 1. Check Console Logs When Adding a menstrual entry
Look for the debug output:
```
=== MENSTRUAL CYCLE SYNC DEBUG ===
User ID: [uuid]
Cycles to sync: 1
Supabase service initialized: true
🔄 Starting menstrual cycle sync for 1 entries...
📤 Calling Supabase replaceMenstrualCycles...
✅ Successfully synced 1 menstrual cycles to database
=== END SYNC DEBUG ===
```

### 2. If you see  any of these errors:

#### "user ID is null or empty"
- **Problem**: User not logged in or HealthDataProvider not initialized
- **Solution**: Make sure you're logged in and wait for the app to load

#### "No menstrual cycles to sync"
- **Problem**: No cycles added yet
- **Solution**: Add a cycle first through the app

#### "Error syncing menstrual cycles"  
- **Problem**: Usually Supabase RLS policy issue
- **Solution**: Run the RLS setup script (see above)

#### "Insert test failed"
- **Problem**: Supabase can't write to the table  
- **Solution**: 
  1. Check RLS policies are enabled
  2. Verify you ran the RLS setup script
  3. Check Supabase project settings

### 3. Manual Diagnostics

Add this debug code to check database connectivity:

```dart
// In your app, after login:
final health = context.read<HealthDataProvider>();
final diagnostics = await health.getDiagnostics();

print('=== Diagnostics ===');
print('User logged in: ${diagnostics['user_logged_in']}');
print('User ID: ${diagnostics['user_id']}');
print('Can connect: ${diagnostics['can_connect']}');
print('Can insert: ${diagnostics['can_insert']}');
print('Can delete: ${diagnostics['can_delete']}');
print('Errors: ${diagnostics['errors']}');
```

This will tell you exactly which operations are failing.

## Verify Table Schema

Go to Supabase Dashboard → Tables → `menstrual_cycles`  

You should see these columns:
- `id` (bigint, primary key)
- `user_id` (uuid, references auth.users)
- `start_date` (date) 
- `end_date` (date)
- `flow` (integer)
- `notes` (text)

## Check RLS Is Enabled

1. Go to Supabase Dashboard
2. Click **Auth** → **Policies**
3. Select `menstrual_cycles` table
4. You should see 4 policies:
   - ✅ Allow users to view their own cycles (SELECT)
   - ✅ Allow users to insert their own cycles (INSERT)
   - ✅ Allow users to update their own cycles (UPDATE)
   - ✅ Allow users to delete their own cycles (DELETE)

If policies are missing or red ❌, run the RLS setup script again.

## Need More Help?

Check these things:
1. ✅ User is authenticated (logged in)
2. ✅ Supabase project is configured with `.env` file
3. ✅ `menstrual_cycles` table exists in Supabase
4. ✅ RLS policies are created and enabled
5. ✅ `auth.uid()` matches the `user_id` in the table

If everything looks correct but still not working:
- Try logging out and logging back in
- Clear app cache and restart
- Check Supabase project status (no outages)
- Verify internet connection
