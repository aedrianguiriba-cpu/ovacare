# Supabase RLS Policy Setup - Quick Copy/Paste Guide

## In 3 Simple Steps

### Step 1: Open Supabase SQL Editor
- Go to [supabase.com](https://supabase.com)
- Click your OvaCare project
- Click **SQL Editor** (left sidebar)
- Click **New Query**

### Step 2: Copy & Paste This Script

```sql
-- MENSTRUAL CYCLES TABLE
ALTER TABLE menstrual_cycles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select their own menstrual cycles"
    ON menstrual_cycles
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own menstrual cycles"
    ON menstrual_cycles
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own menstrual cycles"
    ON menstrual_cycles
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own menstrual cycles"
    ON menstrual_cycles
    FOR DELETE
    USING (auth.uid() = user_id);


-- SYMPTOMS TABLE
ALTER TABLE symptoms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select their own symptoms"
    ON symptoms
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own symptoms"
    ON symptoms
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own symptoms"
    ON symptoms
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own symptoms"
    ON symptoms
    FOR DELETE
    USING (auth.uid() = user_id);


-- MEDICATIONS TABLE
ALTER TABLE medications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select their own medications"
    ON medications
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own medications"
    ON medications
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own medications"
    ON medications
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own medications"
    ON medications
    FOR DELETE
    USING (auth.uid() = user_id);


-- HYDRATION TABLE (if exists)
ALTER TABLE hydration ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select their own hydration"
    ON hydration
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own hydration"
    ON hydration
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own hydration"
    ON hydration
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own hydration"
    ON hydration
    FOR DELETE
    USING (auth.uid() = user_id);


-- WEIGHT ENTRIES TABLE (if exists)
ALTER TABLE weight_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select their own weight entries"
    ON weight_entries
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own weight entries"
    ON weight_entries
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own weight entries"
    ON weight_entries
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own weight entries"
    ON weight_entries
    FOR DELETE
    USING (auth.uid() = user_id);
```

### Step 3: Click **Execute** (Blue Button)

Wait for success message:
```
✓ Successfully executed 1 command.
```

## Verification

1. Go to **Authentication** → **RLS**
2. Each table should now show policies
3. All showing "enabled" status ✅

## That's It!

The app should now be able to:
- ✅ Save menstrual cycles
- ✅ Save symptoms
- ✅ Save medications
- ✅ Save hydration
- ✅ Save weight entries

All data will sync automatically when you add it!

## Troubleshooting

### Error: "relation does not exist"
Some tables might not exist in your database. That's okay - just comment out those sections (add `--` before them) and re-run.

### No error but still not working?
1. Clear app cache
2. Reinstall app
3. Log in again
4. Add test entry
5. Check Supabase table directly

### Still stuck?
Check `DATABASE_SYNC_DEBUGGING.md` for detailed diagnostics.
