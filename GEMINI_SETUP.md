# 🤖 Gemini AI Integration Guide

## Free AI for Forum Moderation

OvaCare now integrates **Google Gemini AI** for intelligent PCOS forum post moderation. This is completely **free** and requires just a simple API key.

## Quick Setup (2 minutes)

### Step 1: Get Your Free API Key
1. Visit: https://ai.google.dev
2. Click **"Get API Key"**
3. Create/Select a Google Cloud project
4. Copy your API key

### Step 2: Add to .env File
Create or edit `ovacare/.env`:

```env
GEMINI_API_KEY=your_api_key_here
```

Replace `your_api_key_here` with your actual API key from Step 1.

### Step 3: Run the App
```bash
cd ovacare
flutter pub get
flutter run
```

You should see in the console:
```
✅ Gemini AI initialized successfully
🤖 Gemini AI Online
```

## Features

✅ **Free Usage**
- 60 requests per minute (free tier)
- Perfect for forum moderation
- No credit card needed

✅ **Smart Analysis**
- Detects PCOS-relevant content
- Analyzes post quality and safety
- Suggests categories automatically

✅ **Fallback to Offline Mode**
- If API key is missing, uses keyword analysis
- App still works perfectly
- Shows status: "📱 Offline Mode (Keyword Analysis)"

## How It Works

The AI combines two approaches:

1. **Gemini AI** (when API key available)
   - Understands post context and intent
   - Detects health-related content
   - Assesses post safety and quality
   - ~1-2 seconds per analysis

2. **Pure Dart Analysis** (always available)
   - Instant keyword matching
   - Spam detection
   - Readability scoring
   - Works without internet

## Monitoring

Check console logs to see AI status:
- ✅ `Gemini AI initialized successfully` - API key found and working
- ⚠️ `Gemini API error: ...` - Temporary API issue, app continues with offline mode
- 📱 Using offline mode - No API key configured

## Cost

**100% FREE** for this use case:
- Free tier: 60 requests/minute
- 1 request per forum post analysis
- Forum moderation uses ~50-100 requests/month typically
- Completely within free limits

## Troubleshooting

### "Gemini API error: 403"
- Check your API key is correct
- Verify it's enabled in Google Cloud Console
- Make sure .env file is in correct location

### "Gemini API error: 429"
- You've exceeded rate limit (60 requests/min)
- App automatically falls back to offline mode
- No user action needed

### App runs but shows "Offline Mode"
- .env file not found
- GEMINI_API_KEY not set
- Both are fine - app works in offline mode too!

## Optional: Upgrade Limits

If you need more requests:
1. Go to https://console.cloud.google.com
2. Enable billing (free $300 credit available)
3. Set usage limits to stay in free tier

## Support

For API issues:
- Google AI Studio: https://aistudio.google.com
- Documentation: https://ai.google.dev/docs

---

**That's it!** Your PCOS forum now has intelligent AI moderation. 🎉
