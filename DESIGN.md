---
name: mask-of-sex
description: The Cloaked Social Feed — Pixel-perfect Instagram iOS camouflage over Tinder web with PickleWatch sports decoy
colors:
  primary: "#ed4956"
  primary-gradient-start: "#f09433"
  primary-gradient-mid: "#dc2743"
  primary-gradient-end: "#bc1888"
  decoy-brand: "#17a157"
  decoy-brand-light: "#2ec770"
  neutral-bg: "#ffffff"
  neutral-text: "#262626"
  neutral-border: "#dbdbdb"
  neutral-secondary: "#8e8e8e"
typography:
  display:
    fontFamily: "Snell Roundhand, Brush Script MT, cursive"
    fontSize: "26px"
    fontWeight: 600
    lineHeight: 1
    letterSpacing: "0.2px"
  headline:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.4px"
  title:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "-0.2px"
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "normal"
  label:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif"
    fontSize: "12px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "0.1px"
rounded:
  sm: "4px"
  md: "8px"
  lg: "16px"
  pill: "9999px"
  circle: "50%"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
components:
  header-bar:
    backgroundColor: "{colors.neutral-bg}"
    textColor: "{colors.neutral-text}"
    height: "44px"
  post-header:
    backgroundColor: "{colors.neutral-bg}"
    textColor: "{colors.neutral-text}"
    height: "42px"
    padding: "0 12px"
  action-row:
    backgroundColor: "{colors.neutral-bg}"
    textColor: "{colors.neutral-text}"
    height: "44px"
    padding: "0 14px"
  bottom-nav:
    backgroundColor: "{colors.neutral-bg}"
    textColor: "{colors.neutral-text}"
    height: "48px"
  keypad-button:
    backgroundColor: "{colors.neutral-bg}"
    textColor: "{colors.neutral-text}"
    rounded: "{rounded.circle}"
    size: "72px"
  decoy-card:
    backgroundColor: "{colors.neutral-bg}"
    rounded: "{rounded.lg}"
    padding: "16px"
---

# Design System: mask-of-sex

## Overview

**Creative North Star: "The Cloaked Social Feed"**

The visual language of mask-of-sex is built on complete, pixel-accurate fidelity to the native Instagram iOS application. Its entire purpose is to provide an airtight visual camouflage for personal dating exploration. To an outside observer or casual glance over a shoulder, the interface presents the unmistakable visual rhythm, iconography, and spatial composition of scrolling through an ordinary Instagram post.

The aesthetic philosophy centers on absolute understatement and authentic muscle memory: every layout dimension, icon glyph, and interaction state mimics the real mobile client. Supporting this is a secondary athletic decoy identity ("PickleWatch"), which surfaces an innocent, highly believable pickleball statistics dashboard in the iOS App Switcher and provides a fully isolated, panic-proof decoy surface upon entering an alternate PIN.

**Key Characteristics:**
- **Pixel-Accurate Social Mimicry:** Faithful reproduction of Instagram's top chrome, story avatar rings, post headers, action rows, and bottom tabs.
- **Native Touch Ergonomics:** High-fidelity gesture mappings—double-tap to like with bursting heart animation, hard scroll to pass, and magnetic AssistiveTouch-style floating return controls.
- **Dual-Identity Segregation:** Clean separation between the primary Instagram skin and the PickleWatch sports disguise.
- **Semantic System Theme Harmony:** Full native support for Light and Dark modes leveraging iOS system materials and semantic colors.

## Colors

The palette reproduces the restrained editorial neutrality of Instagram punctuated by authentic brand gradients, balanced with the athletic green of the PickleWatch decoy.

### Primary
- **heart-crimson** (`#ed4956`): Used for the active liked state on the action row, badge count pills, and heart burst feedback.
- **social-sunset** (`#f09433` -> `#dc2743` -> `#bc1888`): Three-stop linear gradient at 45° used for unread story rings and profile avatar borders.

### Secondary (Decoy System)
- **pickle-court** (`#17a157`): Primary brand color for the PickleWatch logo, active court badges, and positive statistical metrics.
- **pickle-court-light** (`#2ec770`): Accent highlight for activity rings, trend charts, and win streaks.

### Neutral
- **feed-canvas** (`#ffffff` / `Color(.systemBackground)`): Primary background fill behind headers, posts, and navigation bars. Automatically adapts to pure dark in Dark Mode.
- **feed-ink** (`#262626` / `Color(.label)`): Primary high-contrast text and icon stroke fill.
- **hairline-neutral** (`#dbdbdb` / `Color(.separator)`): 0.5–1px divider separating the header, post header, media frame, action row, and bottom tab bar.
- **secondary-subtle** (`#8e8e8e` / `Color(.secondaryLabel)`): Timestamp captions, unselected icon tints, and subtle metadata.

### Named Rules
**The Zero-Tinder-Color Rule.** Tinder brand coral (`#FE3C72`), Tinder flame gradients, and bright dating accents are strictly prohibited from appearing anywhere in the UI. If a color accent is visible, it must strictly be Instagram crimson or PickleWatch sports green.

**The System-Semantic Rule.** Native views must bind to semantic iOS colors (`systemBackground`, `label`, `separator`, `secondaryLabel`) rather than hard-coded hexes so Dark Mode transition is seamless and prevents blinding contrast flashes.

## Typography

**Display Font:** Snell Roundhand / Brush Script MT (macOS/iOS cursive fallback) for the Instagram script brandmark; SF Pro Rounded (Bold) for PickleWatch.
**Body Font:** San Francisco (SF Pro Text / SF Pro Display via system font styles).

**Character:** Neutral, clean, and invisible. The typography recedes entirely into the background to keep focus purely on content.

### Hierarchy
- **Display** (Semi-bold, 26px / 34px, line-height 1): Used exclusively for the Instagram wordmark and PickleWatch lock-screen brand mark.
- **Headline** (Bold, 20px, line-height 1.2): Used for decoy dashboard card headers, settings section titles, and PIN prompts.
- **Title** (Semibold, 16px, line-height 1.3): Used for navigation bar titles and modal headers.
- **Body** (Semibold / Regular, 14px, line-height 1.4): Semibold for post usernames; Regular for captions, bios, and standard text.
- **Label** (Bold / Semibold, 10px–12px, line-height 1.2): 10px Bold for notification badge numbers; 12px Semibold for secondary pill tags and button actions.

### Named Rules
**The Authentic Glyphs Rule.** Every icon in the application must use Apple's SF Symbols (`heart`, `bubble.right`, `paperplane`, `bookmark`, `house`, `magnifyingglass`, `ellipsis`) sized between 21pt and 24pt with standard weight. No third-party or custom web icon sets may be introduced.

## Layout

The spatial model replicates standard mobile device screen economics with strict vertical stacking and zero horizontal clutter:
- **Base Grid Unit:** 4pt grid rhythm (4pt, 8pt, 12pt, 14pt, 16pt, 24pt).
- **Header:** 44pt height with 14pt horizontal padding, anchored inside top safe area insets.
- **Post Header:** 42pt height with 12pt horizontal padding, featuring a 30pt circular avatar and 10pt text spacing.
- **Media Frame:** Edge-to-edge full width framing the underlying profile card.
- **Action Row:** 44pt height with 14pt horizontal padding and 18pt inter-icon spacing.
- **Bottom Navigation Bar:** 48pt height evenly distributing 5 navigation slots, respecting bottom home indicator insets.

## Elevation & Depth

Depth is defined by the flat, print-like discipline of social media feeds combined with purposeful native materials for floating controls.

**The Flat-At-Rest Rule.** All primary surfaces are strictly flat at rest. Structural separation is achieved entirely through hairline dividers (`0.5pt` or `1pt solid separator`). Shadows never appear under cards, headers, or navbars.

### Shadow Vocabulary
- **heart-burst-depth** (`box-shadow: 0 2px 12px rgba(0, 0, 0, 0.45)`): Applied to the double-tap heart pop animation for high-contrast visibility against any photo background.
- **floating-control-resting** (`box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15)`): Applied to the draggable AssistiveTouch return button in decoy mode.
- **floating-control-active** (`box-shadow: 0 4px 10px rgba(0, 0, 0, 0.30)`): Applied during dragging interactions with a 1.1x scale transform.

### Named Rules
**The Native Material Rule.** Floating controls and overlay surfaces must use iOS system materials (`.regularMaterial`, `UIBlurEffect`) rather than simulated CSS backdrop filters, ensuring natural native depth blur.

## Shapes

- **Circular (`50%` / `.circle`):** Avatars (30pt post avatar, 26pt profile tab), 56pt floating return button, 16pt PIN indicators, 72pt numeric keypad touch targets.
- **Capsule (`rounded: pill`):** Notification badge indicators (`igBadge`) with horizontal padding.
- **Rounded Inset (`16pt`):** Decoy dashboard statistic cards (`PickleDashboard`) and modal sheets.
- **Hairline Strokes:** 1.5pt borders for avatar rings and PIN circle outlines.

## Components

### Header Bar
- **Height:** 44pt.
- **Leading:** Instagram brandmark (22pt font size).
- **Trailing:** Recs action (`heart`, 22pt) and Matches action (`bubble.right`, 21pt) with real-time numeric badge overlay.

### Post Header
- **Height:** 42pt.
- **Elements:** 30pt circular avatar filled with `social-sunset` gradient, username in 14pt semibold text, trailing ellipsis options button (triggering settings).

### Action Row
- **Height:** 44pt.
- **Elements:** Like (`heart`), Chat (`bubble.right`), Super Like (`paperplane`), Spacer, Pass/Bookmark (`bookmark`).
- **States:** Like toggles fill to `#ed4956` with spring animation.

### Bottom Navigation Bar
- **Height:** 48pt.
- **Slots:** Home (`house`), Explore (`magnifyingglass`), Decoy Switcher (`play.rectangle`), Likes You (`heart`), Profile (circular avatar with text stroke).

### Floating Return Control (`DraggableFloatingButton`)
- **Dimensions:** 56pt diameter circle.
- **Material:** `.regularMaterial` with 0.5pt border stroke (`Color.primary.opacity(0.12)`).
- **Behavior:** Free dragging with magnetic edge snapping to left or right margin upon release, persisting position across app launches.

### PIN Keypad (`LockView`)
- **Keypad Buttons:** 72×72 pt circular targets arranged in a 3×4 grid with 18pt vertical and 26pt horizontal spacing.
- **PIN Indicator Dots:** 16×16 pt circles, 1.5pt stroke, filled on active entry.

## Do's and Don'ts

### Do:
- **Do** map every user touch interaction 1:1 to underlying Tinder web actions without background automation or synthetic delays.
- **Do** enforce complete session isolation for the secondary decoy PIN (`PickleLiveView`) using non-persistent website data stores.
- **Do** ensure all interactive touch targets meet or exceed Apple's 44×44 pt minimum bounds.
- **Do** test both Light Mode and Dark Mode against iOS system semantic colors.
- **Do** show the innocent `PickleDashboard` instantly when transitioning to the iOS App Switcher.

### Don't:
- **Don't** ever display Tinder logos, flame glyphs, or Tinder coral (`#FE3C72`).
- **Don't** allow web scrollbars, text selection highlights, or cursor pointers to leak through the WKWebView.
- **Don't** add desktop-style card shadows or heavy border radii to the feed layout.
- **Don't** create bespoke web-style modal dialogs when native iOS sheets (`.sheet`) provide HIG-compliant gestures.
