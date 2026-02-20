# Database Sync Debugging Guide

## Current Issue: Data Not Uploading to Supabase

You've reported that menstrual cycle data is not syncing to the Supabase database even though the code appears correct.

## Quick Diagnostics Checklist

### Step 1: Check Debug Logs on Login
When you log in to the app, look for these messages in the console/debug output:

```
🔐 DEBUG: authProvider.userId = [USER_ID_HERE]
🔐 DEBUG: authProvider.isLoggedIn = true
🔐 DEBUG: authProvider.userEmail = [EMAIL_HERE]
🔑 === SETTING CURRENT USER ID ===
🔑 Provided userId: [USER_ID_HERE]
🔑 Current Supabase auth user: [USER_ID_HERE]
✅ Supabase service reinitialized for user: [USER_ID_HERE]
📥 Loading data for user: [USER_ID_HERE]
```

**What to look for**:
- Does `userId` match `Current Supabase auth user`? If not, there's an authentication issue.
- Is `isLoggedIn` showing as `true`? If false, login failed but app proceeded anyway.
- Does the loading process complete without errors?

### Step 2: Add a Menstrual Cycle Entry
1. Log in to the app
2. Add a new menstrual cycle (set start date and optionally end date)
3. **Check the console log for messages like**:

```
=== MENSTRUAL CYCLE SYNC DEBUG ===
Adding cycle to local list...
Triggering background sync...
🔄 _syncMenstrualCyclesToSupabase() called
Current user ID: [USER_ID_HERE]
Number of cycles to sync: 1
Attempting to sync menstrual cycles...
```

**If sync appears to work**, you should see:
```
✅ Successfully synced 1 menstrual cycles to database
```

**If sync fails**, you should see:
```
❌ ERROR: [ERROR_MESSAGE_HERE]
```

### Step 3: Verify Data in Supabase
1. Go to your Supabase Dashboard
2. Navigate to **SQL Editor** → **New Query**
3. Run this query:

```sql
SELECT id, user_id, start_date, end_date, flow, notes, created_at
FROM menstrual_cycles
WHERE user_id = '[YOUR_USER_ID]'
ORDER BY created_at DESC
LIMIT 10;
```

**Results**:
- **If empty**: Data isn't being written to the database at all (RLS or code issue)
- **If has data**: Database write is working! Check if app displays correct count.

## Root Cause Analysis

### Possible Issue 1: Supabase RLS Policies Not Configured (MOST LIKELY)

**Symptoms**:
- Log shows successful sync but data doesn't appear in Supabase
- Error messages like "permission denied" or "new row violates row-level security policy"

**Solution**:
Execute this script in Supabase SQL Editor:

```sql
-- Enable RLS on menstrual_cycles table
ALTER TABLE menstrual_cycles ENABLE ROW LEVEL SECURITY;

-- Create policy for authenticated users to select their own data
CREATE POLICY "Users can select their own menstrual cycles"
    ON menstrual_cycles
    FOR SELECT
    USING (auth.uid() = user_id);

-- Create policy for authenticated users to insert their own data
CREATE POLICY "Users can insert their own menstrual cycles"
    ON menstrual_cycles
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Create policy for authenticated users to update their own data
CREATE POLICY "Users can update their own menstrual cycles"
    ON menstrual_cycles
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Create policy for authenticated users to delete their own data
CREATE POLICY "Users can delete their own menstrual cycles"
    ON menstrual_cycles
    FOR DELETE
    USING (auth.uid() = user_id);
```

**After running**:
- Go to **Supabase Dashboard** → **RLS** section
- Check that `menstrual_cycles` table shows "4 policies"
- Try adding a cycle again

### Possible Issue 2: User ID Mismatch

**Symptoms**:
- Login debug logs show different user IDs
- Data syncs (no errors) but appears under wrong user

**Solution**:
1. Check Supabase Auth logs in dashboard
2. Verify user's UUID matches what code is using
3. Clear app cache and re-login

### Possible Issue 3: Network/Connection Issues

**Symptoms**:
- Sync logs show network timeouts
- "Unable to reach Supabase" type errors

**Solution**:
1. Check internet connection
2. Verify Supabase project is online and accessible
3. Check Supabase status page for outages

### Possible Issue 4: Table Doesn't Exist or Schema Mismatch

**Symptoms**:
- Errors like "relation menstrual_cycles does not exist"
- Column name mismatches

**Solution**:
Verify table schema:

```sql
-- Check if table exists
SELECT * FROM information_schema.tables 
WHERE table_name = 'menstrual_cycles';

-- Check column names and types
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'menstrual_cycles'
ORDER BY ordinal_position;
```

Expected columns:
- `id` (UUID, primary key)
- `user_id` (UUID, foreign key)
- `start_date` (DATE)
- `end_date` (DATE, nullable)
- `flow` (TEXT, nullable)
- `notes` (TEXT, nullable)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

## Advanced Debugging

### Enable Detailed Logging
Add this to your app before login:

```dart
// In main.dart, in build method:
print('🔍 Full debugging mode enabled');
```

### Test Sync Manually
In the app, you can manually trigger sync:

```dart
// Call this method to test syncing
final provider = Provider.of<HealthDataProvider>(context, listen: false);
final result = await provider.syncMenstrualCycles();
print('Sync result: $result');

// Or try one-by-one sync if batch sync fails:
final result2 = await provider.syncMenstrualCyclesOneByOne();
print('One-by-one sync result: $result2');
```

### Check Supabase Logs
1. Supabase Dashboard → **Logs** → **Database**
2. Look for INSERT/UPDATE queries to `menstrual_cycles`
3. Note any error messages

## Step-by-Step Resolution

1. **First**: Check debug logs from Step 1 - verify user ID is set correctly
2. **Second**: Apply RLS policies from Step 3 if missing
3. **Third**: Add a test cycle and watch console logs
4. **Fourth**: Check Supabase database for the data
5. **Fifth**: If still stuck, run detailed logs and share error messages

## Success Indicators

You'll know it's working when you see:

```
✅ Successfully synced 1 menstrual cycles to database
```

AND

Running this query in Supabase returns your data:
```sql
SELECT * FROM menstrual_cycles 
WHERE user_id = '[YOUR_USER_ID]' 
ORDER BY created_at DESC 
LIMIT 1;
```

## Next Steps

1. Check your console logs for the debug output above
2. If you see permission errors, run the RLS SQL script
3. If user IDs don't match, verify Supabase authentication
4. If you're stuck, provide the error messages from your console logs

The fix is likely just applying the RLS policies to your Supabase tables!
