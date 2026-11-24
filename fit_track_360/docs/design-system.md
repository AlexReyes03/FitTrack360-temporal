# FitTrack360 Design System

## Scope

Document for product and engineering (including Flutter). It describes the FitTrack360 survey visual language so the same look can be rebuilt on another platform without depending on CSS or a web UI framework.

**Includes:** tokens, components, states, survey-style screen layout, motion, and Flutter construction recipes (no CSS APIs).

**Excludes:** survey logic, spreadsheet submission, question copy, full app code, and coupling to Bootstrap.

**Expected outcome:** a Flutter (or other) implementer can match geometry and states without inventing missing metrics or calling CSS-only features such as `box-shadow: inset` or `saturate()` on blur.

Look name: **Liquid Glass dark (white/silver)**.

## Principles

1. **Dark only.** Near-black background; this system has no light theme.
2. **Monochrome accent.** Interaction uses white and silver (`#ffffff` → `#d4d4d8`), not brand green, blue, or purple.
3. **Glass surfaces.** Cards use a semi-transparent fill, thin light border, outer drop shadow, and two separate top-edge light effects (rim + specular streak). Content sits over a fixed, softly vignetted backdrop while the column scrolls.
4. **Readable type.** Primary text is near-white; secondary and muted use mid grays. Never dark text on a light glass wash.
5. **Solid CTA.** The primary button and question-number badge carry the strong contrast (white/silver fill, text `#090a0f`).
6. **One job per block.** Header, notice, question, or options: each surface has one purpose; do not mix stats or promos into the same card.
7. **Touch-first states.** On mobile there is no hover. Use **Pressed** (finger down) and **Selected** (committed choice) as separate states. Do not implement desktop hover unless you also ship a pointer platform.

## Flutter constraints (read before tokens)

Flutter’s `BoxShadow` has **no inset flag**. Never specify “inset shadow” as an implementation step. Translate every web inset into one of:

| Visual intent | Flutter construction |
| --- | --- |
| 1 dp light line on top edge | `Stack` + `Positioned(top: 0, left: 0, right: 0, height: 1)` with a solid or horizontal gradient |
| Soft top rim on a card | Same, or a nested top border strip; optional second 1 dp line with `Colors.white.withValues(alpha: 0.03)` as a full-bleed overlay |
| Selected radio “hole” | Three stacked circles (outer stroke, dark ring, bright core). See OptionTile |
| Soft highlight under selected tile | Outer `BoxShadow` only (blur + spread), not inset |

Backdrop blur: use `ClipRRect` + `BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16))`. Do **not** add a saturation `ColorFilter` to mimic CSS `saturate(180%)`. Optional stronger glass: sigma 24. CSS blur radius 28 px is not the same number as Flutter sigma; **16** is the default target, **24** if you want more diffusion.

## Tokens

Units in **dp** (base 16: 1 rem in the web reference ≈ 16 dp). Colors in hex.

### Color

| Token | Hex / value | Use |
| --- | --- | --- |
| `bg.deep` | `#07080c` | Screen base |
| `bg.mid` | `#0d1017` | Mid stop of the vertical backdrop gradient (`#0e1017` acceptable as alias) |
| `text.primary` | `#f8fafc` | Titles and main body |
| `text.secondary` | `#a1a1aa` | Subtitles, hints, secondary labels |
| `text.muted` | `#71717a` | Placeholder |
| `text.onAccent` | `#090a0f` | Text on white/silver |
| `accent.white` | `#ffffff` | CTA, badge, strong selection |
| `accent.silver` | `#d4d4d8` | Far end of the accent gradient |
| `zinc.200` | `#e4e4e7` | Idle option label / intro badge |
| `zinc.100` | `#f4f4f5` | Page-title mid stop; neutral banner text |
| `gray.400` | `#9ca3af` | Page-title end stop |
| `control.track` | `#0b0d13` | Dark ring inside selected radio |
| `control.fillIdle` | `rgba(9,10,15,0.65)` | Idle radio/checkbox fill |
| `glass.border` | `rgba(255,255,255,0.12)` | GlassSurface border |
| `glass.borderStrong` | `rgba(255,255,255,0.28)` | Emphasized border |
| `glass.rim` | `rgba(255,255,255,0.24)` | Top-edge rim paint (not a BoxShadow inset) |
| `glass.rimFaint` | `rgba(255,255,255,0.03)` | Optional full-bleed 1 dp rim under specular |
| `warning.fill` | `#f59e0b` at 14% opacity | StatusBanner warning background |
| `warning.border` | `#fbbf24` at 40% opacity | StatusBanner warning border |
| `warning.text` | `#fde68a` | StatusBanner warning text |
| `danger.fill` | `#ef4444` at 16% opacity | StatusBanner danger background |
| `danger.border` | `#f87171` at 45% opacity | StatusBanner danger border |
| `danger.text` | `#fecaca` | StatusBanner danger text |

**Screen background (fixed to the viewport; content scrolls over it):**

1. Base fill `bg.deep`.
2. Vertical linear gradient: `bg.deep` (0%) → `bg.mid` (50%) → `bg.deep` (100%).
3. Three radial vignettes (approximate CSS positions):
   - Center `(12%, 8%)`, radius ~38% of the short side, white at 9% → transparent.
   - Center `(88%, 22%)`, radius ~42%, `#a1a1aa` at 8% → transparent.
   - Center `(50%, 85%)`, radius ~45%, white at 5% → transparent.

**Glass fill (surface):** diagonal linear gradient, white opacity 8.5% → 2.5% → 5%.

**Glass fill (question):** softer diagonal, white opacity 5.5% → 1.5%.

**Page title glyph gradient:** `#ffffff` (0%) → `#f4f4f5` (45%) → `#9ca3af` (100%), angle ~135°.

### Typography

Family: system sans (SF Pro / Inter / Segoe / Roboto). Body line-height ≈ 1.55.

| Role | Weight | Size (dp) | Color | Notes |
| --- | --- | --- | --- | --- |
| Brand pill | 700 | 12 | `text.primary` | Uppercase, letter-spacing ~0.12 em |
| Page title | 800 | 28–38 | page-title gradient above | Slight negative tracking |
| Intro badge | 700 | 12.5 | `zinc.200` | Uppercase, letter-spacing ~0.04 em |
| Question title | 700 | 17 | `text.primary` | Line-height ~1.4 |
| Question hint | 400 | 14 | `text.secondary` | |
| Option label | 500 | 15.5 | `zinc.200` | Selected: 600, `accent.white` |
| NPS digit | 700–800 | 15 | `zinc.200` / `text.onAccent` when selected | |
| CTA | 800 | 16 | `text.onAccent` | |
| Banner / end title | 500–800 | 15–22 | by state | End title: white → `text.secondary` gradient |

### Space

| Token | dp | Use |
| --- | --- | --- |
| `space.xs` | 6–8 | Small inner gaps |
| `space.sm` | 9–14 | Badge–text gap, option padding |
| `space.md` | 18–24 | Card padding, space between questions |
| `space.lg` | 28–40 | Screen vertical padding |
| `content.maxWidth` | 760 | Max column width |

GlassSurface padding: 24 dp (mobile) / 32–36 dp (width ≥ 768).  
QuestionBlock padding: 20 dp / 24–26 dp on desktop.  
Gap between OptionTiles: **9 dp**.  
Control-to-label gap inside OptionTile: **14 dp**.  
Bottom margin between QuestionBlocks: 20–24 dp.  
IntroCard bottom margin below the block: 24 dp.  
Primary paragraph under intro badge → secondary paragraph: **8 dp**.

### Radius

| Token | dp | Use |
| --- | --- | --- |
| `radius.card` | 24 | GlassSurface |
| `radius.inner` | 18 | QuestionBlock |
| `radius.option` | 14 | OptionTile |
| `radius.nps` | 12 | NpsCell |
| `radius.input` | 14 | TextField |
| `radius.badge` | 8 | Question number |
| `radius.checkbox` | 6.4 | Idle/selected checkbox corner |
| `radius.pill` | full (999) | BrandPill, PrimaryButton |
| `radius.banner` | 14 | StatusBanner |

### Elevation and blur

| Effect | Value | Flutter note |
| --- | --- | --- |
| Glass blur | sigma **16** (optional 24) | `ClipRRect` + `ImageFilter.blur`; no saturation filter |
| Pill / banner blur | sigma ~8–12 | Optional; keep cheap on Android |
| Card outer shadow | black ~78% opacity, blur ~54, Y ~24, spread negative ~−14 | Outer `BoxShadow` only |
| Specular streak | 1 dp tall, left/right inset **8%** (covers central **84%**), horizontal gradient transparent → white 55% → transparent | `Positioned` child; **not** the same as the rim |
| Top rim | 1 dp, full width, `glass.rim` (and optional faint `glass.rimFaint` underlay) | Second `Positioned` or border paint |
| Selection glow | soft white outer shadow under selected NpsCell / OptionTile | Outer shadow only |

## Components

### BrandPill

**Anatomy:** row: luminous dot (7×7 dp) + brand text in uppercase.

**Dot:** fill gradient `#ffffff` → `#a1a1aa`; soft glow (approximate with a white shadow blur **8 dp**, opacity ~0.8).

**Metrics:** vertical padding ~6 dp, horizontal ~14 dp; pill radius; border `rgba(255,255,255,0.18)`; background gradient white 14% → 4%.

**Top light (no inset shadow):** 1 dp `Positioned` line across the pill top at ~25% white, or a very light top-only gradient in the fill.

**States:** static.

### PageHeader

**Survey anatomy:** BrandPill → page title → metadata line in `text.secondary`.

**Metadata line:** plain text segments separated by `|`, plus an inline **16×16 dp** icon (e.g. stopwatch) baseline-aligned with the trailing duration text (e.g. `3 min`).

**Metrics:** block bottom margin ~28 dp; pill → title gap ~14 dp.

**App screens (`lib/design_system/components/page_header.dart`):** every secondary screen uses `PageHeader` in the `header` slot of `AppScaffoldTemplate` or `FormPageTemplate`.

| Part | Spec |
| --- | --- |
| Back (`GlassBackButton`) | 48×48 dp, `radius.option`, gradient `glassFillStrong` → `glassFillSoft`, border `glassBorderStrong`; Pressed: `glassFillPressed*` + `glassBorderPressed` + 1 dp lift. Icon `arrow_back_rounded` 22 dp. Tooltip and semantics label **«Volver»** |
| Title | `AppTypography.pageTitle`, max 2 lines, `Semantics(header: true)` |
| Subtitle | optional, `AppTypography.body` in `text.secondary` |
| Trailing | optional widget (e.g. compact `SecondaryButton`) |
| Gaps | back → title `space.sm`; title → trailing `space.sm` |

**Back behavior:** `onBack` if given → otherwise `Navigator.maybePop` when the route can pop → otherwise `onBackFallback` (e.g. `context.go('/app')`), so the button is never inert after a deep link. `showBack: false` on root tabs.

**Template slot:** `AppScaffoldTemplate(header:)` pins the header under the top safe area, centered in `content.maxWidth`, padding `space.sm` top / `space.md` sides / `space.xs` bottom; the body scrolls underneath and receives the top inset already consumed. `FormPageTemplate(header:)` places it above the fields inside the scroll column.

### IntroCard

**Anatomy:** GlassSurface with:

1. Intro badge (uppercase label).
2. Primary paragraph (`text.primary`, bottom margin **8 dp**).
3. Secondary paragraph (`text.secondary`).

**Metrics:** bottom margin under the whole card **24 dp**.

### GlassSurface

**Anatomy (layer order, bottom → top):**

1. Clipped rounded rect (`radius.card`).
2. Optional `BackdropFilter` blur (sigma 16).
3. Glass fill gradient + 1 dp border `glass.border`.
4. Outer drop shadow (see tokens).
5. Full-width top rim paint (`glass.rim` / optional faint underlay).
6. Specular streak: 1 dp, **8% inset from left and right**, horizontal transparent → white 55% → transparent.

Do not merge rim and specular into one effect; the CSS reference keeps both.

**Use:** IntroCard, form shell, EndState.

**States:** static; nested content owns interaction.

### QuestionBlock

**Anatomy:**

1. Header: two columns (number badge | copy).
2. Option list and/or NPS grid.
3. Optional **OtherInputSlot** when a choice requires free text (see below).

- **Badge:** ~30×30 dp, radius 8, 2-digit text weight 800, color `text.onAccent`, fill white → silver gradient; soft white outer glow optional.
- **Copy:** title + optional hint aligned to the text column start (hint does **not** sit under the badge).

**Metrics:** question glass fill; border `rgba(255,255,255,0.08)`; optional 1 dp top rim via `Positioned` (white ~10% opacity), not inset shadow; title → options margin ~18 dp.

**States (touch):** default; optional **Pressed** border bump to ~15% white while the finger is down. No hover requirement on mobile. Does not replace option **Selected**.

### OptionTile

**Anatomy:** row: control (20×20 dp) + label. Full row is tappable. Control–label gap **14 dp**.

**Metrics:** padding ~14×18 dp; `radius.option`; background `rgba(255,255,255,0.035)`; border white at 8%. **No translate/lift** on this component (web reference has none).

#### Control (idle)

| Property | Radio | Checkbox |
| --- | --- | --- |
| Size | 20×20 dp | 20×20 dp |
| Fill | `control.fillIdle` | same |
| Border | 1.5 dp, `rgba(255,255,255,0.32)` | same |
| Corner | circle | `radius.checkbox` **6.4 dp** |

#### Control (selected)

**Radio (three layers, outside → inside):**

1. Circle 20 dp, border **1.5 dp** `accent.white`, fill white → silver gradient.
2. Dark ring: simulate the former CSS `inset 0 0 0 3.5px #0b0d13` with a concentric circle of fill `control.track` leaving a bright core, or a stroke/padding stack that yields a **~3.5 dp** dark band.
3. Bright core: white/silver disc ~**10 dp** diameter in the center.

Wrong reading to avoid: “dark core” (that looks like an unchecked radio). The **center is bright**; the **ring is dark**.

**Checkbox:** fill `accent.white`; check glyph `#090a0f`, icon box ~14.4×14.4 dp, stroke weight ~2.6; soft white outer glow optional.

#### Tile states

| State | Visual |
| --- | --- |
| Default | Idle fill/border; label `zinc.200` weight 500 |
| Pressed | Fill ~7.5% white; border ~20% (onTapDown); **no Y lift** |
| Selected | Gradient white 16% → silver 6%; border ~48%; label white weight 600; control as above; optional soft **outer** white shadow |
| Disabled | Opacity ~0.35; ignore presses |
| Focus (keyboard/a11y) | 2 dp outline white ~75%, offset 2 dp |

### OtherInputSlot

Shown inside a QuestionBlock when the selected option needs free text (e.g. “Other”).

**Metrics:** `margin-top` **14 dp**; `padding-top` **14 dp**; top divider 1 dp `rgba(255,255,255,0.08)`; then label + TextField.

Do not place this TextField as a floating orphan outside the question card.

### NpsCell

**Anatomy:** tappable cell with digit 0–10 centered.

**Grid:**

| Breakpoint | Columns | Gap | Cell min height |
| --- | --- | --- | --- |
| Width ≤ 576 dp | 6 | **7 dp** | **46 dp** |
| Wider | 11 | **7 dp** | **46 dp** |

Do **not** rely on `GridView` default `childAspectRatio: 1.0`. Prefer a fixed height (~46 dp) and let width come from the column count, or set aspect ratio from `(cellWidth / 46)`.

Scale labels under the grid (“not at all likely” / “very likely”) in `text.secondary` at 12.5 dp, space-between, top margin ~9 dp.

**States:**

| State | Visual |
| --- | --- |
| Default | Fill 4% white; border 10% |
| Pressed | Fill ~10%; border ~28%; **1 dp lift** (translate up) |
| Selected | White→silver fill; `text.onAccent`; soft outer glow; may keep 1 dp lift |
| Focus | White outline 2 dp |

### TextField

**Anatomy:** label (`text.secondary`, 14 dp, weight 600) + single-line field.

**Metrics:** padding ~12×16 dp; `radius.input`; background `rgba(7,8,12,0.72)`; border white at 18%.

**States:** focus → border ~60% white + 3 dp outer halo at 14% white. Placeholder: `text.muted`.

### PrimaryButton

**Anatomy:** full-width pill, centered label.

**Metrics:** padding ~15×32 dp; border near-white (~85% opacity); fill gradient `#ffffff` → `#e4e4e7` → `#d4d4d8`; light outer shadow; text `text.onAccent` weight 800.

**Top light:** 1 dp highlight near the top edge (paint or nested gradient), not an inset `BoxShadow`.

**Variants:** `primary` (white/silver) and `destructive` (red gradient, white label).

**States:**

| State | Visual |
| --- | --- |
| Default | Metrics above |
| Pressed | **1 dp lift** while down; slightly lighter gradient; on release return to Y 0 |
| Disabled (`onPressed: null`) | Opacity 0.55 |
| Loading (`isLoading: true`) | 18 dp spinner (stroke 2) left of the label in the label color (`text.onAccent`; white on destructive); optional `loadingLabel` (e.g. «Creando cuenta…»); taps ignored (no double submit); **opacity stays 1**: the action is in progress, not forbidden |

**Accessibility:** `Semantics(container: true, button: true, enabled:, label:, excludeSemantics: true)`; while loading `enabled` is false and the label is the loading label.

No separate hover state required on touch devices.

### SecondaryButton

Glass pill for every non-primary action (`lib/design_system/components/secondary_button.dart`).

| Size | Visual height | Tap target | Padding | Label | Icon |
| --- | --- | --- | --- | --- | --- |
| `normal` | 48 dp | 48 dp | 12×24 dp | `secondaryCta` (15.5, w700) | 18 dp |
| `compact` | 36 dp | 48 dp (transparent band) | 8×14 dp | `secondaryCta` at 13 dp | 15 dp |

| Variant / state | Fill | Border | Label |
| --- | --- | --- | --- |
| Neutral | gradient `glassFillStrong` → `glassFillSoft` | `glassBorderStrong` | `text.primary` |
| Neutral pressed | gradient `glassFillPressedStrong` → `glassFillPressedSoft`, 1 dp lift | `glassBorderPressed` | `text.primary` |
| Selected (`selected: true`) | `accent.white` | `accent.silver` | `text.onAccent` |
| Destructive | `dangerFill` | `dangerBorder` (pressed `dangerSolidRim`) | `dangerText` |
| Disabled | opacity 0.55 | — | — |
| Loading | spinner replaces the icon; taps ignored | — | — |

`expand: true` stretches to the available width (stacked under a PrimaryButton or in dialogs). `semanticLabel` overrides the announced label (e.g. «Reintentar conexión»). Same semantics contract as PrimaryButton, plus `selected`.

### TextLink

Tertiary text action with a 48 dp tap target (`TextButton` underneath). Default: `text.primary`, weight 700, underline in `text.secondary`. `subtle: true`: `text.secondary`, weight 600, no underline. Disabled: `text.muted`.

### StatusBanner

**Anatomy:** icon (20 dp) → optional title (15, w700) → message (13.5, line height 1.45) → optional `action` full width below the text, or optional compact `trailing` to the right (e.g. «Reintentar» in the offline banner). Placed under the CTA or beside submit feedback.

| Variant | Background | Border | Text | Default icon |
| --- | --- | --- | --- | --- |
| Warning | `#f59e0b` @ 14% (`warningFill`) | `#fbbf24` @ 40% (`warningBorder`) | `#fde68a` (`warningText`) | `info_outline_rounded` |
| Neutral | white @ 8% (*) | white @ 20% (*) | `#f4f4f5` (`zinc100`) | `info_outline_rounded` |
| Success | same as Neutral | same as Neutral | same as Neutral | `check_circle_outline_rounded` |
| Danger | `#ef4444` @ 16% (`dangerFill`) | `#f87171` @ 45% (`dangerBorder`) | `#fecaca` (`dangerText`) | `error_outline_rounded` |

(*) Implemented with the closest existing tokens, `glassFillStrong` (10%) and `glassBorderStrong` (28%), until #221 adds neutral banner tokens.

**Success is not green:** the accent is monochrome, so confirmations («Cambios guardados») use the Neutral palette with a check mark.

Radius 14 dp (`radius.banner`); padding 15×18 dp; light blur sigma 10. `icon` overrides the default glyph (e.g. `wifi_off_rounded`, `location_off_rounded`).

**Accessibility:** `Semantics(container: true, liveRegion: true)` by default so screen readers announce it when it appears or changes; `liveRegion: false` for persistent notices. The icon is excluded from semantics.

### GlassDialog

`showGlassDialog(context:, builder:)` opens a `Dialog` whose content is a `GlassSurface` (max width 520 dp, inset `space.md`) over the DS scrim. `GlassDialog(title:, message:, content:, actions:)`: title 20 dp w800 (`Semantics(header: true)`), message `body` in `text.secondary`, actions stacked full width with `space.xs` gaps, primary first.

`showGlassConfirmDialog(context:, title:, message:, confirmLabel:, cancelLabel: 'Cancelar', destructive:)` returns `Future<bool>`: `true` only on confirm; cancel, scrim tap or system back return `false`. With `destructive: true` the confirm button is `PrimaryButton` destructive (red).

**Scrim:** `bgDeep` @ 80% (`glassBarrierColor`). Temporary value: switch to the `scrim` token from #221.

### GlassBottomSheet

`showGlassBottomSheet(context:, builder:, title:)`: modal sheet on `bgMid`, top radius `radius.card`, 1 dp `glassBorder` outline, drag handle in `glassBorderStrong`, DS scrim, bottom safe area. Options use `GlassSheetAction(icon:, label:, onTap:, destructive:)`: 56 dp rows, icon 22 dp, label 15 dp w600 (`dangerText` when destructive). Example: the progress «Cámara / Galería» picker.

### AppSnackBar

`showAppSnackBar(context, message:, variant:, actionLabel:, onAction:)` hides the current snackbar and shows a floating one (no queue of stale messages). Surface from `snackBarTheme`: `bgMid`, radius 14 dp, `glassBorderStrong` outline, no elevation, action in `accent.white`. `variant` reuses the StatusBanner palette for the icon and text color (Danger → `dangerText`).

### Material theme (`fitTrackDarkTheme`)

Material widgets that still appear (pickers, raw dialogs, chips, switches) inherit the monochrome palette from `lib/app/app.dart`:

| Theme | Values |
| --- | --- |
| `colorScheme` | every role in white/silver/zinc (no Material teal) |
| `dialogTheme` | `bgMid`, no surface tint, card radius with `glassBorder`, DS scrim, title 20 w800, content `text.secondary` |
| `snackBarTheme` | floating, `bgMid`, banner radius, `glassBorderStrong`, action `accent.white` |
| `chipTheme` | selected `accent.white` + `text.onAccent` label + check `text.onAccent`; idle `glassFillSoft` + `zinc200` label + `glassBorderStrong`; stadium shape. Fixes the teal selected meal-type chip («Desayuno») |
| `bottomSheetTheme` | `bgMid`, drag handle, top card radius, DS scrim |
| `progressIndicatorTheme` | `accent.white`, linear track `glassFillStrong` |
| `textButtonTheme` | `accent.white` (disabled `text.muted`), min 48×48 dp, w700 |
| `switchTheme` | on: track `accent.white`, thumb `text.onAccent`; off: track `controlFillIdle`, thumb `accent.silver`; outline `glassBorderStrong` |
| `datePickerTheme` / `timePickerTheme` | `bgMid`, selection `accent.white` with `text.onAccent` |

### EndState

**Anatomy:** centered GlassSurface: title with white → `text.secondary` gradient + `text.secondary` paragraph.

**Metrics:** padding ~40×28 dp; title ~22 dp weight 800.

## Screen layout

Centered column, `content.maxWidth` 760 dp, system horizontal padding + vertical `space.lg`.

Backdrop stays fixed to the viewport; only the column scrolls.

Fixed order:

1. PageHeader  
2. IntroCard  
3. Form GlassSurface: stacked QuestionBlocks (with Optional OtherInputSlot inside a block)  
4. PrimaryButton (and StatusBanner when there is feedback)  
5. EndState replaces the form when the flow ends (success or early exit)

On narrow width: reduce screen padding; NPS uses 6 columns, min cell height 46 dp, gap 7 dp.

## Motion

- Typical duration: **150–180 ms**, soft ease-out.
- **OptionTile:** fill/border only; **no** Y lift.
- **NpsCell / PrimaryButton:** **1 dp** lift on **Pressed** (and NpsCell may keep lift when **Selected**); PrimaryButton returns to Y 0 on release.
- Do not continuously animate backdrop or blur.
- No long bounce or parallax.

## Flutter mapping

- Custom dark `ThemeData` / `ColorScheme`: surfaces `bg.deep`, accent white/silver. Do not use Material’s default green/blue primary as brand accent.
- GlassSurface: `ClipRRect` → `BackdropFilter` (sigma 16) → `DecoratedBox` (gradient, border, **outer** shadows only) → `Stack` for rim + specular `Positioned` lines (specular inset 8% left/right).
- BrandPill / PrimaryButton: `BorderRadius.circular(999)` or `StadiumBorder`.
- OptionTile: custom `InkWell` / `GestureDetector` row; build radio as three concentric circles as specified; checkbox with custom painter or icon at ~14.4 dp.
- OtherInputSlot: `Column` children after the option list, with top `Border` / `Divider` at 8% white.
- NPS: custom grid or `GridView` with **explicit** cross-axis count, **7 dp** spacing, and **~46 dp** extent (avoid default square aspect ratio).
- Glyph gradients: `ShaderMask` only on page title and end title.
- Prefer `onTapDown` / `onTapUp` / `onTapCancel` for Pressed; store selection in app state for Selected.

## Done criteria

The replica matches this system when:

1. The screen is dark (`bg.deep`) with the three vignettes and a **fixed** backdrop while content scrolls; no flat white background.
2. Glass cards show **both** a full top rim and a centered 84%-width specular streak, plus an **outer** drop shadow (no reliance on inset `BoxShadow`).
3. Interactive accent is white/silver only.
4. Each question shows a solid number badge + title; hints hang under the title, not under the badge.
5. Idle controls are filled (`control.fillIdle`) with a 1.5 dp light border; selected **radio** shows bright core + dark ring (not a dark core).
6. OptionTile has no Y lift; NpsCell/PrimaryButton lift 1 dp only on press (per Motion).
7. NPS cells are ~46 dp tall with 7 dp gaps (6 or 11 columns by width), not default 1:1 squares that break the layout.
8. Free-text “other” appears inside the question as OtherInputSlot with the top divider spacing above.
9. StatusBanner uses the exact warning/danger hex stops listed in Tokens.
10. Blur uses Flutter sigma (~16) inside `ClipRRect`, without a saturation color matrix.
