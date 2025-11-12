# 🎯 Minimize/Maximize Panel Feature

## Overview
The data panel now has a **minimize/maximize toggle** for better UX. Users can temporarily hide the panel without losing any data, then restore it with one click.

## Before (Old Behavior) ❌
```
User clicks [X] → Panel closes completely
User wants to see data again → Must scroll through chat to find "View Data Table" button
Data still there but hard to access
```

## After (New Behavior) ✅
```
User clicks [-] → Panel minimizes to floating button
User wants to see data again → Click floating button → Panel restored instantly
Quick and intuitive!
```

## Visual Guide

### Full Panel View
```
┌─────────────────────────────────────────────────────┐
│  Conversation Results                  [-]  [X]     │  ← Two buttons!
│  95 items                                            │
├─────────────────────────────────────────────────────┤
│  [Keywords 95]                                       │
├─────────────────────────────────────────────────────┤
│  0 selected          [Export CSV]                    │
├─────────────────────────────────────────────────────┤
│                                                       │
│  [Data table content here]                           │
│                                                       │
└─────────────────────────────────────────────────────┘
```

### Click Minimize `[-]`

### Minimized State
```
┌──────────────────────────────────────────┐
│                                           │
│  [Chat content fully visible]             │
│                                           │
│                                           │
│                              ┌──────────────┐
│                              │ 📊 1 Result  │  ← Floating button
│                              └──────────────┘
│                                     ↑
│                              Click to restore
└──────────────────────────────────────────┘
```

### Click Floating Button

### Panel Restored!
```
┌─────────────────────────────────────────────────────┐
│  Conversation Results                  [-]  [X]     │
│  95 items                                            │
├─────────────────────────────────────────────────────┤
│  [Keywords 95]                                       │
│  ↑ Exactly as you left it!                          │
└─────────────────────────────────────────────────────┘
```

## Button Behaviors

### Minimize Button `[-]`
- **Location**: Top-right of panel, left of close button
- **Icon**: Horizontal line (minus sign)
- **Action**: Collapses panel to floating button
- **State**: Data fully preserved
- **Tooltip**: "Minimize panel"

### Close Button `[X]`
- **Location**: Top-right of panel, rightmost position
- **Icon**: X (close icon)
- **Action**: Closes panel completely
- **State**: Data preserved but panel dismissed
- **Reopen**: Via "View Data Table" buttons in chat
- **Tooltip**: "Close panel"

### Floating Restore Button
- **Visibility**: Only shows when panel is minimized
- **Location**: Bottom-right of screen (over chat area)
- **Style**: Yellow/amber background (#FFC107)
- **Icon**: Table chart icon 📊
- **Label**: Shows result count (e.g., "3 Results")
- **Action**: Click to maximize/restore panel
- **Tooltip**: "Show conversation results"

## Use Cases

### 1. Reading Chat While Keeping Data Accessible
```
User: "research keywords for seo tools"
Bot: [Returns results]
User: Clicks "View Data Table" → Panel opens
User: Reviews data
User: Clicks [-] to minimize → Continues chatting with full screen
User: Later clicks floating button → Instant access to data
```

### 2. Comparing Multiple Conversations
```
User has panel with 3 result tabs open
User: "Let me ask about something else"
User: Clicks [-] to minimize for unobstructed view
User: Asks new question
User: Restores panel when ready to reference previous results
```

### 3. Mobile/Small Screens
```
On smaller screens, panel takes significant space
User minimizes when chatting
User restores when analyzing data
Best of both worlds!
```

## Technical Implementation

### ChatProvider State
- `_dataPanelMinimized`: Boolean tracking minimize state
- `minimizeDataPanel()`: Sets minimized to true
- `maximizeDataPanel()`: Sets minimized to false
- State persists until:
  - Panel explicitly closed
  - New conversation started
  - User switches conversations

### UI Components
1. **DataPanel widget**: Added optional `onMinimize` callback
2. **chat_screen.dart**: 
   - Conditionally shows panel based on `!chatProvider.dataPanelMinimized`
   - Adds Stack with Positioned floating button when minimized
3. **Floating button**: FloatingActionButton.extended with dynamic label

### State Flow
```
Panel Open & Not Minimized → Full panel visible
                 ↓ Click [-]
Panel Open & Minimized → Floating button visible
                 ↓ Click floating button
Panel Open & Not Minimized → Full panel visible (restored)
```

## Benefits

1. **✅ Better UX**: Quick access without scrolling through chat
2. **✅ Screen Space**: Minimize when you need full chat view
3. **✅ State Preservation**: All data, tabs, selections kept intact
4. **✅ Visual Feedback**: Floating button shows you have data available
5. **✅ Result Count**: Badge shows how many results accumulated
6. **✅ Intuitive**: Standard minimize/maximize pattern users know
7. **✅ Non-destructive**: Different from close, clearly communicates temporary hide

## Comparison to Other Approaches

| Approach | Pros | Cons |
|----------|------|------|
| **Old: Close only** | Simple | Must find chat button to reopen |
| **New: Minimize + Close** | Quick toggle, non-destructive | Two buttons (but clear purpose) |
| **Slide-out drawer** | Smooth animation | Complex to implement |
| **Tab in browser** | Separate context | Breaks flow, hard on mobile |

## User Feedback Expected

- "Much easier to toggle data view!"
- "Love the floating button reminder"
- "Don't have to scroll to find the table button"
- "Minimize is perfect for small screens"

## Next Steps (Future)

- [ ] Add keyboard shortcut (Cmd+B / Ctrl+B) to toggle
- [ ] Animate minimize/maximize transition
- [ ] Remember user preference (always start minimized/maximized)
- [ ] Add "pin" option to keep panel always visible
- [ ] Draggable floating button position

