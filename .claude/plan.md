# Generation Modes + Keyboard UI Redesign

## Overview
Add multiple generation categories ("modes") to the keyboard extension — **Reply** (default), **Refine** (improve typed text), and **Custom** (user-created). Redesign the keyboard reply cards to be minimalist and premium.

---

## Data Model

**New file: `PersuadeKeyboard/GenerationMode.swift`** (main app target)

```swift
struct GenerationMode: Identifiable, Codable {
    let id: UUID
    var name: String              // "Reply", "Refine", or custom
    var icon: String              // SF Symbol name
    var baseSystemPrompt: String  // Internal prompt
    var userInstructions: String  // User's extra instructions appended
    var inputSource: InputSource  // clipboard or textField
    var isBuiltIn: Bool           // Reply & Refine = true (can't delete)

    enum InputSource: String, Codable {
        case clipboard   // reads UIPasteboard (Reply mode)
        case textField   // reads textDocumentProxy (Refine mode)
    }
}
```

- Stored as JSON string in App Group UserDefaults under scoped key `"keyboard_generation_modes"`
- Mirrored struct in keyboard extension (`WebhookClient.swift`) since targets are separate processes
- Default modes created on first launch if none exist
- Migrate existing `custom_system_prompt` → Reply mode's `userInstructions` for backward compat

### Built-in Defaults

**Reply** — `icon: "arrowshape.turn.up.left.fill"`, `inputSource: .clipboard`
> Prompt: Generate exactly 3 short, natural, persuasive reply suggestions with different angles. Return ONLY a JSON array of 3 strings.

**Refine** — `icon: "sparkle.magnifyingglass"`, `inputSource: .textField`
> Prompt: The user drafted a message. Generate exactly 3 improved versions — more persuasive, professional, and impactful while keeping the same intent. Return ONLY a JSON array of 3 strings.

---

## Files to Modify (6 files)

### 1. New: `PersuadeKeyboard/GenerationMode.swift`
- `GenerationMode` struct + `Codable`
- `GenerationModeStore` helper class:
  - `loadModes() -> [GenerationMode]` — reads from App Group, creates defaults if empty
  - `saveModes([GenerationMode])` — writes JSON to App Group
  - `migrateCustomPrompt()` — one-time migration of old `custom_system_prompt` into Reply mode's userInstructions
- Default mode factory methods

### 2. `KeyboardViewController.swift` — Mode selector + per-mode logic
- Add horizontal scrollable **mode selector pills** below the top bar
  - Capsule-shaped: selected = accent bg/dark text, unselected = card2 bg/subtext
  - Each pill: small icon + name, ~32px height
- Track `selectedMode: GenerationMode` state
- **Generate button text** changes per mode: "Generate Reply" vs "Refine" vs custom name
- **Input source** per mode:
  - `.clipboard` → read `UIPasteboard.general.string`
  - `.textField` → read `textDocumentProxy.documentContextBeforeInput`
- **Empty state message** per mode:
  - Reply: "Copy a message to generate replies"
  - Refine: "Type your message first, then tap Refine"
- Pass mode's combined prompt (base + user instructions) to `OpenAIClient.generateReplies()`
- **Replace** action for Refine mode: clear existing text in textDocumentProxy, insert polished version

### 3. `ReplyCardView.swift` — Minimalist premium redesign
- **Text**: 14pt font, `.white.opacity(0.92)`, 4pt line spacing, better readability
- **Buttons**: much smaller (26px height), capsule-shaped, right-aligned
  - Primary: "Insert" (Reply) or "Replace" (Refine) — accent bg, small
  - Secondary: copy icon only, no text label — subtle card2 bg
- **Card**: 14px corner radius, subtle 0.04 opacity border, tighter padding (12px)
- **Overall**: less visual weight, content-first, buttons are secondary

### 4. `WebhookClient.swift` (OpenAIClient) — Mode-aware generation
- Change model from `gpt-4o-mini` → `gpt-4.1-mini`
- Add `systemPrompt` parameter to `generateReplies()` instead of reading from UserDefaults
- Caller passes the combined prompt: `mode.baseSystemPrompt + "\n\n" + mode.userInstructions`
- Add a `KBGenerationMode` struct (mirror of main app's model) for JSON parsing
- Add `KBModeStore` to load modes from App Group

### 5. `PersonalizeKeyboardView.swift` — Mode management UI
- **Remove** the single "System Prompt" TextEditor section
- **Add** "Generation Modes" section:
  - List of mode cards showing icon + name + description
  - Built-in modes (Reply, Refine): tap to expand → "Custom Instructions" TextEditor
    - Shows: "Add your own instructions on top of the default behavior"
    - Cannot change name/icon/base prompt, cannot delete
  - Custom modes: tap to expand → full edit (name, icon picker, system prompt, input source toggle)
    - Can delete with swipe or button
  - **"+ Add Mode"** button at bottom to create custom mode
- Keep theme section as-is (unchanged)
- Save still writes to App Group via UserScopedStorage

### 6. `APIService.swift` — Minor: UserSettings model stays as-is
- No backend changes needed — modes are local-only (stored in App Group)
- The existing `customSystemPrompt` field becomes unused but stays for backward compat

---

## Keyboard Layout (280px)

```
┌──────────────────────────────────┐
│ [logo] Persuade AI    [globe]    │ ← top bar (34px)
├──────────────────────────────────┤
│ [Reply] [Refine] [Custom1] ...   │ ← mode pills, horizontally scrollable (32px)
├──────────────────────────────────┤
│                                  │
│  Empty state / Generated cards   │ ← scrollable content area
│                                  │
├──────────────────────────────────┤
│  [ ✦ Generate Reply ]           │ ← accent button (40px)
└──────────────────────────────────┘
```

## Reply Card (New Design)

```
┌──────────────────────────────────┐
│ Hey, I completely understand     │
│ your concern about pricing.      │
│ Let me walk you through...       │
│                                  │
│              [Insert ↗] [📋]    │ ← small capsule buttons, right-aligned
└──────────────────────────────────┘
```

---

## Edge Cases
- **First launch**: No modes in UserDefaults → create Reply + Refine defaults
- **Existing users**: Migrate `custom_system_prompt` → Reply mode's `userInstructions`
- **Refine with empty text field**: Show error "Type your message first"
- **Replace action**: Move cursor to end, delete all backward, insert new text
- **Memory**: Keyboard extensions have ~30MB limit — modes are tiny JSON, no concern
