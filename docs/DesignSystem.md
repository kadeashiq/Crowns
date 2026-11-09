# Crowns design system

Flat, black, white and greys. Watches are the only colour on screen; the app icons (`Crowns/Icons/`, made in Icon Composer) is the one thing that sits outside this. Hierarchy comes from drop shadows, not materials, borders or gradients. No wood, suede, brass or Liquid Glass.

The code lives in `Shared/Design/`.

## Colour (`Theme`)

Every colour adapts to light and dark.

| Token | Light | Dark | Use |
|---|---|---|---|
| `canvas` | `#F2F2F3` | `#000000` | The page |
| `surface` | `#FFFFFF` | `#1C1C1E` | Cards, buttons |
| `well` | `#F2F2F3` | `#2A2A2D` | Text fields, photos while loading |
| `ink` | `#0A0A0A` | `#FAFAFA` | Primary text, primary fills, selection |
| `inkSecondary` | `#5E5E63` | `#A8A8AD` | Supporting text |
| `inkTertiary` | `#77777C` | `#7E7E84` | Least important text |
| `onInk` | `#FFFFFF` | `#0A0A0A` | Text and icons on `ink` |

## Elevation (`Elevation`)

The more something matters, the higher it sits.

| Level | Use |
|---|---|
| `.flat` | Anything pressed |
| `.low` | Cards, resting controls |
| `.mid` | Selected controls, primary buttons |
| `.high` | The add button, a watch in its detail sheet |

Use `.surface(_:radius:elevation:)` for a filled background, so the shadow belongs to the shape and text stays crisp.

## Spacing and shape

`Space`: 4, 8, 12, 16, 24, 32, 48. `Radius`: 12, 18, 24, 32, always continuous. Buttons are capsules or circles.

## Type (`Typeface`)

System font on Dynamic Type: `display`, `title`, `heading`, `body`, `button`, `label`, `secondary`, `caption`, `micro`, `price`, `reference`.

## Components

| Component | File | Notes |
|---|---|---|
| `.pill(.primary / .secondary / .quiet)` | `Buttons.swift` | Sinks to flat when pressed |
| `.circle(.primary / .surface / .flat)` | `Buttons.swift` | Icon buttons |
| `CardButtonStyle` | `Buttons.swift` | A whole card as a button |
| `Card`, `FormSection`, `ValueRow`, `RowDivider` | `Components.swift` | Grouped content |
| `ChipButton` | `Components.swift` | System filled capsule; the selected one is black |
| `IconSegments` | `Components.swift` | The black selection slides between options |
| `CountStepper`, `.filledField()`, `SheetHeader` | `Components.swift` | Forms and sheets |
| `WatchImage`, `WatchGrid`, `WatchCell` | `Shared/Box/` | Photos fill their containers, edge to edge |

## Motion (`Motion`)

Screens change through native SwiftUI sheets and nothing else: no custom fades, slides, flying elements or toasts. Content swaps instantly. Only two things are animated by hand, both springs: `press` for touch feedback and `selection` for the indicator on toggles.

## Rules

- Raised means it's yours or it's actionable.
- The grid only ever shows watches. No empty slots or placeholders.
- No colour for meaning. System confirmation dialogs are the only red.
- Sheets have a swipe indicator and no close button.
- Buttons pinned to an edge use `.fadingBar(_:)`: content scrolls under a soft fade, never a solid bar.
- Anything loading shows a native spinner, says what it's doing, and holds its layout with grey placeholders.
- Pick a token. If none fits, add one here first.
