# Look Check privacy

Standalone app (`com.beckify.lookcheck`). Public URL for App Store Connect: https://beckify.com/privacy

## What leaves the device

**Nothing** when you take a photo or pick one from the library.

**Analyze** POSTs an upright JPEG to `https://api.beckify.com/api/analyze-look`. The app chooses `roastMode` `mean` or `nice` at random and does not show which one. The Beckify API may forward that photo to OpenAI and/or Anthropic. The result is an entertainment verdict plus a comedy roast when the subject appears 18+ and is rated.

## What does not happen

- No account
- No ads, analytics, or tracking
- No appearance rating or roast if anyone appears under 18
- The photo is not stored in Saved Jobs (this app has no job list)

Entertainment only — not medical, dating, or beauty authority.
