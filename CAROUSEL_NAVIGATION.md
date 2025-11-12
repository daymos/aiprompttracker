# 🎠 Carousel Navigation for Results

## Overview
Instead of showing all results as tabs that can overflow, we now use a **carousel navigation** pattern inspired by modern interfaces. This allows users to navigate through accumulated results one at a time with clear previous/next controls.

## Visual Design

```
┌─────────────────────────────────────────────────┐
│  Conversation Results              [-]  [X]     │
│  95 items                                        │
├─────────────────────────────────────────────────┤
│                                                  │
│   ◀   [ 2/4  Keywords #2 ]   ▶                 │
│                                                  │
├─────────────────────────────────────────────────┤
│  0 selected          [Export CSV]                │
└─────────────────────────────────────────────────┘
```

### Components:
1. **◀ Previous Arrow** - Navigate to previous result (disabled on first)
2. **Counter Badge** - Shows current position (e.g., "2/4")
3. **Result Title** - Name of current result (e.g., "Keywords #2")
4. **▶ Next Arrow** - Navigate to next result (disabled on last)

## Benefits Over Tabs

| Feature | Tabs | Carousel |
|---------|------|----------|
| **Scalability** | Overflow with many results | Always fits, no matter how many |
| **Clarity** | Can be confusing with similar names | Clear counter shows position |
| **Space** | Takes more vertical space | Compact single row |
| **Navigation** | Click specific tab or use arrows | Simple previous/next |
| **Mobile** | Hard to see/tap small tabs | Large, easy-to-tap arrows |

## User Experience

### Scenario: 4 Keyword Research Results

**Result 1** (viewing #4 - newest):
```
◀   [ 4/4  Keywords #4 ]   ▶
          ↑                  ↑
     (active)           (disabled)
```

**User clicks ◀** → Goes to result 3:
```
◀   [ 3/4  Keywords #3 ]   ▶
 ↑                         ↑
(active)              (active)
```

**User clicks ◀ twice** → Goes to result 1:
```
◀       [ 1/4  Keywords #1 ]   ▶
 ↑                              ↑
(disabled)                 (active)
```

## State Management

- **Always starts on newest result** (highest index)
- **Counter shows: current / total** (e.g., 4/4)
- **Arrow states:**
  - ◀ White = can go back, Gray = at first result
  - ▶ White = can go forward, Gray = at last result
- **Result titles numbered** when multiple of same type:
  - "Keywords #1", "Keywords #2", "Keywords #3", "Keywords #4"

## Keyboard Support (Future)

```
← Arrow Key = Previous result
→ Arrow Key = Next result
1-9 Keys = Jump to result number
Home = First result
End = Last result
```

## Visual States

### Active Navigation
```
┌─────────────────────────────────────────┐
│  ◀   [  2/4  Keywords #2  ]   ▶        │
│  ↑       Yellow amber bg      ↑         │
│ White                        White      │
│ arrows                       arrows     │
└─────────────────────────────────────────┘
```

### At First Result
```
┌─────────────────────────────────────────┐
│  ◀   [  1/4  Keywords #1  ]   ▶        │
│  ↑       Yellow amber bg      ↑         │
│ Gray                         White      │
│ disabled                     arrows     │
└─────────────────────────────────────────┘
```

### At Last Result
```
┌─────────────────────────────────────────┐
│  ◀   [  4/4  Keywords #4  ]   ▶        │
│  ↑       Yellow amber bg      ↑         │
│ White                        Gray       │
│ arrows                       disabled   │
└─────────────────────────────────────────┘
```

## Technical Implementation

### State Variables
- `_currentTabIndex` - Current result index (0-based)
- `widget.tabs!.length` - Total number of results
- `_currentTab` - Current result title/label

### Navigation Methods
```dart
void _navigatePrevious() {
  if (_currentTabIndex > 0) {
    _navigateToTab(_currentTabIndex - 1);
  }
}

void _navigateNext() {
  if (_currentTabIndex < widget.tabs!.length - 1) {
    _navigateToTab(_currentTabIndex + 1);
  }
}
```

### UI Rendering
- Only shows when `widget.tabs!.length > 1`
- For single result, no navigation shown (just the data)
- Counter: `${_currentTabIndex + 1}/${widget.tabs!.length}`
- Arrow colors: White if enabled, Gray if disabled
- Center section: Yellow/amber background with rounded corners

## Example Usage

### User Flow
```
1. User: "research keywords for seo tools"
   → Result stored as "Keywords #1"
   → No navigation shown (only 1 result)

2. User: "now research keywords for backlinks"
   → Result stored as "Keywords #2"
   → Carousel appears: [ 2/2  Keywords #2 ]
   → Can click ◀ to see Keywords #1

3. User: "research keywords for content marketing"
   → Result stored as "Keywords #3"
   → Carousel updates: [ 3/3  Keywords #3 ]
   → Can navigate: 1 ← 2 ← 3

4. User: "check rankings for example.com"
   → Result stored as "Rankings #1"
   → Carousel updates: [ 4/4  Rankings #1 ]
   → Can navigate through all 4 results
```

## Comparison to Inspiration

Your inspiration screenshot showed:
```
← [ 2/5 ] Keyword Research Results →
```

Our implementation:
```
◀ [ 2/4  Keywords #2 ] ▶
```

**Enhancements we added:**
- ✅ Numbered suffixes for same-type results
- ✅ Disabled state visual feedback (gray)
- ✅ Larger, more prominent center badge
- ✅ Yellow/amber active result styling
- ✅ Auto-shortens long titles

## Future Enhancements

- [ ] Keyboard arrow key navigation
- [ ] Swipe gestures on mobile
- [ ] Jump to specific result (dropdown menu)
- [ ] Animation when switching results
- [ ] Show result timestamp on hover
- [ ] Quick preview thumbnails
- [ ] Bookmark/favorite specific results

