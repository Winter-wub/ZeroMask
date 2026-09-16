## Question

Research how to extract the Tinder Authentication Token from the WKWebView session, and determine the exact API endpoint to poll for new messages/matches via a native iOS `URLSession` (avoiding the overhead of a background WKWebView).

## Type

wayfinder:research

## Status

Closed

## Resolution

- **Token Extraction:** Tinder typically stores its API token in `localStorage` under keys like `TinderWeb-access-token` or similar, or as HTTP cookies. We can extract this in Swift using `webView.evaluateJavaScript("window.localStorage.getItem('...');")` or `WKHTTPCookieStore`.
- **API Endpoint Discovery:** Since undocumented APIs frequently change, the most robust way to find the polling endpoint is to **inject a Javascript interceptor (wrapping `fetch` and `XMLHttpRequest`)** into the `WKWebView` when the app is active. This script will sniff outgoing network requests to `api.gotinder.com` and send the endpoint URL and headers back to our Swift native code via `WKScriptMessageHandler`.
- **Background Execution:** Once the native iOS side captures the Auth Token and the correct URL (e.g. `/v2/updates`), it can use `URLSession` during a `BGAppRefreshTask` to quietly hit the endpoint and parse for new message counts or matches.

This resolves the technical blocker of "how to get the data without waking up the WebView in the background."
