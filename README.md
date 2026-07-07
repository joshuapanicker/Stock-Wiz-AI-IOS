# StockWiz for iOS

Native SwiftUI client for the StockWiz platform. It shares authentication, portfolios, preferences, alerts, brokerage connections, and market services with the web application through Supabase and the existing FastAPI backend.

## Getting started

1. Open `StockWiz.xcodeproj` in Xcode.
2. In `StockWiz/Resources/AppConfig.plist`, replace the three placeholder values with:
   - the deployed FastAPI base URL (without `/api`),
   - the Supabase project URL,
   - the public Supabase anon/publishable key.
3. Select an iPhone simulator and run the `StockWiz` scheme.

Never add the Supabase service-role key, Plaid secret, or Anthropic key to this repository. Those credentials belong only on the backend.
