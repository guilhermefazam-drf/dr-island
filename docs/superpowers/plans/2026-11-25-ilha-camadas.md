# Ilha «Camadas», temas e modo compacto: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the island's flat look with the «Camadas» layout, driven by theme tokens (4 themes) and density metrics (Normal / Compacto), for 1–3 columns.

**Architecture:** Pure value types in `DrIslandCore` (`IslandTheme` → `IslandPalette`, `IslandDensity` → `IslandMetrics`, plus small pure rules) are injected into the SwiftUI tree with `EnvironmentKey`s. Every island view reads colours and sizes from the environment; `IslandView.height(of:)` uses the same `IslandMetrics`, so the panel size always matches what is drawn. Shared components (`BlockCard`, `CardHeader`, `ListRow`, `Pill`, `Avatar`, `SegmentedTabs`, `ColumnFade`) are written once and reused by every block (and later by Bento).

**Tech Stack:** Swift 5.10+/SwiftPM, SwiftUI + AppKit, macOS 14+, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-25-ilha-camadas-design.md` (visual reference: `docs/design/ilha-redesign.html`).

## Global Constraints

- macOS 14+, no external dependencies; one type per file; new views follow the `swiftui-pro` skill.
- Testable logic goes in `DrIslandCore`; tests use Swift Testing (`@Suite`/`@Test`/`#expect`) in `Tests/DrIslandCoreTests/`.
- Build the app only with `scripts/bundle.sh debug|release`. Tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.
- User-facing text in European Portuguese; code and comments in English.
- Jira stays read-only: no new requests, nothing bypasses `JiraClient.get`.
- Respect «Reduzir movimento» (already handled), «Reduzir transparência», «Aumentar contraste».
- Widths: Normal 400 / 660 / 870 pt (same as today), Compacto 340 / 560 / 740 pt; `extraColumnWidth` keeps adding per column; `IslandLayoutConfig.maxWidth` and the panel size do not change.
- The island header stays in the notch strip (`NotchMetrics.height`); the Claro theme's black strip is `NotchMetrics.height + 6`.
- Settings defaults: `islandTheme = "grafite"`, `islandDensity = "regular"`, `densityHotKey = "off"`.
- Commits: no `Co-Authored-By` trailer (user rule). Work on branch `feat/ilha-camadas`.
- After any behaviour change, `docs/funcionalidades.md` is updated in the same task or in Task 11.

## Review Focus

1. **Changing theme or density while the island is open**: the island must redraw and resize at once, with no stale colours and no clipped column (panel height comes from `height(of:)`). Covered by Task 3 manual check + Task 9 metrics tests.
2. **Claro theme over a dark system appearance**: text, tooltips (`IslandTipLayer`) and SF Symbols must use palette colours, not `.primary/.secondary` resolved for dark. Pinned by Task 10's `preferredColorScheme(palette.isLight ? .light : .dark)` and the palette contrast test (Task 1).
3. **Tabs when one side is empty or in error**: `includeReviews` off, no approvals, gh/Jira status messages. Must show no tabs (single list) instead of an empty tab. Test `TabChoiceTests.singleListHasNoTabs` (Task 7).
4. **Compact height regression**: Compacto must never be taller than today. Test `IslandMetricsTests.compactNeverTallerThanToday` (Task 9).
5. **Density hotkey equal to the main hotkey**: both registered on the same combo would fire twice. The density picker disables the option currently chosen as the main hotkey and vice versa (Task 9); `HotKeyManager` registers distinct `EventHotKeyID.id` values (1 = island, 2 = density).

---

## File Structure

**Core (new):**
- `Sources/DrIslandCore/ThemeColor.swift`: RGBA value + WCAG contrast.
- `Sources/DrIslandCore/IslandTheme.swift`: enum of themes, `palette`.
- `Sources/DrIslandCore/IslandPalette.swift`: struct of colour tokens.
- `Sources/DrIslandCore/IslandDensity.swift`: `regular | compact`.
- `Sources/DrIslandCore/IslandMetrics.swift`: sizes per density + height helpers.
- `Sources/DrIslandCore/AvatarColor.swift`: stable colour from a name.
- `Sources/DrIslandCore/TabChoice.swift`: which tab a two-list card shows.
- `Sources/DrIslandCore/Greeting.swift`: «Bom dia/Boa tarde/Boa noite».

**Core (modify):** `IslandLayoutConfig.swift` (width by density).

**App (new):** `IslandEnvironment.swift` (env keys + `Color(ThemeColor)`), `BlockCard.swift`, `CardHeader.swift`, `SegmentedTabs.swift`, `ListRow.swift`, `Pill.swift`, `Avatar.swift`, `ColumnFade.swift`, `IslandHeader.swift`, `ThemeAndSizeSection.swift`, `ThemeThumbnail.swift`.

**App (modify):** `IslandView.swift`, `IslandLayout.swift`, `View+BlockCard.swift` (removed at the end), `CardTitle.swift` (removed), `RowTag.swift`/`OwnerTag.swift` (replaced), every `…Block.swift`, `PullRequestRow.swift`, `JiraTaskRow.swift`, `PullRequestSection.swift`, `JiraSection.swift`, `ShortcutsDock.swift`, `IslandTipLayer.swift`, management views, `Brand.swift`, `SettingsKey.swift`, `Settings.swift`, `AppearancePage.swift`, `SettingsLayout.swift`, `HotKeyManager.swift`, `IslandInstance.swift`, `IslandController.swift`, `IslandState.swift`.

**Tests (new):** `IslandThemeTests.swift`, `IslandMetricsTests.swift`, `AvatarColorTests.swift`, `TabChoiceTests.swift`, `GreetingTests.swift`; modify `IslandLayoutConfigTests.swift`.

---

### Task 1: Theme tokens in Core

**Files:**
- Create: `Sources/DrIslandCore/ThemeColor.swift`, `Sources/DrIslandCore/IslandPalette.swift`, `Sources/DrIslandCore/IslandTheme.swift`
- Test: `Tests/DrIslandCoreTests/IslandThemeTests.swift`

**Interfaces:**
- Produces:
  - `public struct ThemeColor: Equatable, Sendable { public let r, g, b, a: Double; public init(_ hex: UInt32, alpha: Double = 1); public func over(_ base: ThemeColor) -> ThemeColor; public func contrast(with other: ThemeColor) -> Double }` (`over` = alpha-composite, `contrast` = WCAG 2 ratio on opaque colours).
  - `public struct IslandPalette: Sendable { base: [ThemeColor] /* gradient stops top→bottom, 1+ */, collar, surface, surfaceRaised, border, highlight, text, textSecondary, textTertiary, accent, green, amber, red, purple, pink, orange: ThemeColor; isLight: Bool; public func source(_ block: IslandBlock) -> ThemeColor }`
  - `public enum IslandTheme: String, CaseIterable, Codable, Sendable { case grafite, meiaNoite = "meia-noite", aurora, claro; public var title: String; public var palette: IslandPalette; public init(stored: String?) /* unknown → .grafite */ }`

- [ ] **Step 1: Write the failing tests** in `IslandThemeTests.swift`:

```swift
@Suite struct IslandThemeTests {
    @Test func unknownStoredValueFallsBackToGrafite() {
        #expect(IslandTheme(stored: nil) == .grafite)
        #expect(IslandTheme(stored: "xpto") == .grafite)
        #expect(IslandTheme(stored: "meia-noite") == .meiaNoite)
    }
    @Test func grafiteMatchesTodaysColours() {
        let p = IslandTheme.grafite.palette
        #expect(p.base == [ThemeColor(0x000000)])
        #expect(p.surface == ThemeColor(0xFFFFFF, alpha: 0.055))
        #expect(p.accent == ThemeColor(0x00A6E5))
        #expect(p.green == ThemeColor(0x28C840))
        #expect(p.amber == ThemeColor(0xFEBC2E))
        #expect(p.red == ThemeColor(0xFF5F57))
        #expect(p.isLight == false)
    }
    @Test func everyThemeIsReadable() {
        for theme in IslandTheme.allCases {
            let p = theme.palette
            let card = p.surface.over(p.base.last!)
            #expect(p.text.contrast(with: card) >= 4.5, "\(theme) text")
            #expect(p.textSecondary.contrast(with: card) >= 3, "\(theme) secondary")
        }
    }
    @Test func sourcesHaveTheirColour() {
        let p = IslandTheme.aurora.palette
        #expect(p.source(.claude) == p.orange)
        #expect(p.source(.pullRequests) == p.purple)
        #expect(p.source(.sprint) == p.accent)
        #expect(p.source(.jira) == p.accent)
        #expect(p.source(.backlog) == p.accent)
        #expect(p.source(.focus) == p.green)
        #expect(p.source(.music) == p.pink)
        #expect(p.source(.alerts) == p.amber)
        #expect(p.source(.briefing) == p.amber)
    }
    @Test func onlyClaroIsLight() {
        #expect(IslandTheme.allCases.filter { $0.palette.isLight } == [.claro])
        #expect(IslandTheme.claro.palette.collar == ThemeColor(0x000000))
    }
}
```

- [ ] **Step 2: Run** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter IslandThemeTests`. Expected: FAIL (types not defined).

- [ ] **Step 3: Implement the three files.** Values (hex, alpha):
  - **grafite**: base `[000000]`, collar `000000`, surface `FFFFFF/.055`, surfaceRaised `FFFFFF/.09`, border `FFFFFF/.0` (today has none), highlight `FFFFFF/.0`, text `F3F3F5`, textSecondary `A1A1AA`, textTertiary `6C6C75`, accent `00A6E5`, green `28C840`, amber `FEBC2E`, red `FF5F57`, purple `BF8BFF`, pink `FF6B9A`, orange `FF9F5A`. (Border/highlight become non-zero in Task 6, when the look changes: border `FFFFFF/.07`, highlight `FFFFFF/.06`.)
  - **meiaNoite**: base `[060A14, 0A1224]`, collar `060A14`, surface `6EA0FF/.07`, surfaceRaised `6EA0FF/.12`, border `8CB4FF/.12`, highlight `A0C8FF/.08`, text `EDF2FF`, textSecondary `98A6C4`, textTertiary `64718F`, accent `3FC0FF`, green `3DDC84`, amber `FFCF4A`, red `FF6B6B`, purple `A99BFF`, pink `FF7EB3`, orange `FFA564`.
  - **aurora**: base `[0A0A10]` (the violet/teal glows are drawn by the view, Task 10), collar `0A0A10`, surface `FFFFFF/.06`, surfaceRaised `FFFFFF/.10`, border `FFFFFF/.10`, highlight `FFFFFF/.10`, text `F6F4FF`, textSecondary `AAA5C2`, textTertiary `716C8A`, accent `9D8CFF`, green `4CE0A0`, amber `FFD166`, red `FF6B81`, purple `C3A6FF`, pink `FF8FC7`, orange `FFB37A`.
  - **claro**: base `[F2F3F6]`, collar `000000`, surface `FFFFFF`, surfaceRaised `F0F2F5`, border `0F141E/.08`, highlight `FFFFFF`, text `15171C`, textSecondary `5B616D`, textTertiary `8D939E`, accent `0088C2`, green `1F9D46`, amber `B7791F`, red `D6322B`, purple `7C4DD6`, pink `D63D74`, orange `D0661F`, `isLight: true`.
  - Titles: «Grafite», «Meia-noite», «Aurora», «Claro». `source`: history/timeline → accent.

- [ ] **Step 4: Run the tests again.** Expected: PASS. If a contrast check fails, adjust only that theme's `textSecondary`/`text` and note it in the commit.

- [ ] **Step 5: Commit**
```bash
git add Sources/DrIslandCore/ThemeColor.swift Sources/DrIslandCore/IslandPalette.swift Sources/DrIslandCore/IslandTheme.swift Tests/DrIslandCoreTests/IslandThemeTests.swift
git commit -m "feat(core): tokens de tema da ilha (4 paletas)"
```

### Task 2: Density metrics in Core (today's values)

**Files:**
- Create: `Sources/DrIslandCore/IslandDensity.swift`, `Sources/DrIslandCore/IslandMetrics.swift`
- Modify: `Sources/DrIslandCore/IslandLayoutConfig.swift:67-76`
- Test: `Tests/DrIslandCoreTests/IslandMetricsTests.swift`, `Tests/DrIslandCoreTests/IslandLayoutConfigTests.swift`

**Interfaces:**
- Produces:
  - `public enum IslandDensity: String, CaseIterable, Codable, Sendable { case regular, compact; public init(stored: String?) /* unknown → .regular */; public var title: String /* «Normal», «Compacto» */ }`
  - `public struct IslandMetrics: Equatable, Sendable` with `Double` fields: `cardPadding, cardGap, cardRadius, rowHeight, rowHasMeta (Bool), listHeader, listRule, cardHeader, tile, titleSize, bodySize, metaSize, ringSize, dockIcon, sectionSpacing`; `public static func forDensity(_ d: IslandDensity) -> IslandMetrics`; `public func card(_ content: Double) -> Double` (= content + 2·cardPadding); `public func listSection(rows: Int) -> Double` (0 when rows == 0, else `listHeader + 2 + rows·rowHeight`); `public func listCard(sections: [Int]) -> Double` (= `card(cardHeader + Σ listSection + (nonEmpty−1)·listRule)`).
  - `IslandLayoutConfig.width(columns: Int, density: IslandDensity = .regular) -> Double` and `func width(density: IslandDensity = .regular) -> Double`; existing `width`/`maxWidth` keep their values (they call the `.regular` variant).

- [ ] **Step 1: Write the failing tests**
```swift
@Suite struct IslandMetricsTests {
    @Test func regularStartsWithTodaysSizes() {
        let m = IslandMetrics.forDensity(.regular)
        #expect(m.cardPadding == 10); #expect(m.rowHeight == 25); #expect(m.cardHeader == 20)
        #expect(m.listHeader == 20); #expect(m.listRule == 13); #expect(m.cardRadius == 12)
        #expect(m.sectionSpacing == 16); #expect(m.rowHasMeta == false)
    }
    @Test func listCardMatchesTodaysFormula() {
        let m = IslandMetrics.forDensity(.regular)
        // Git card today: card(cardTitle + section(3) + section(4) + listRule)
        #expect(m.listCard(sections: [3, 4]) == 20 + (20 + 2 + 75) + (20 + 2 + 100) + 13 + 20)
        #expect(m.listCard(sections: [0, 2]) == 20 + (20 + 2 + 50) + 20)
    }
    @Test func unknownDensityIsRegular() { #expect(IslandDensity(stored: "x") == .regular) }
}
```
Add to `IslandLayoutConfigTests.widthsAndColumnCounts`:
```swift
#expect(IslandLayoutConfig.width(columns: 1, density: .compact) == 340)
#expect(IslandLayoutConfig.width(columns: 2, density: .compact) == 560)
#expect(IslandLayoutConfig.width(columns: 3, density: .compact) == 740)
#expect(IslandLayoutConfig.threeColumns.width(density: .compact) < IslandLayoutConfig.maxWidth)
```

- [ ] **Step 2: Run** `swift test --filter "IslandMetricsTests|IslandLayoutConfigTests"` (with `DEVELOPER_DIR`). Expected: FAIL.

- [ ] **Step 3: Implement.** `.regular` = today's `IslandLayout` values (padding 10, gap 16, radius 12, row 25, listHeader 20, listRule 13, cardHeader 20, tile 16, title 11, body 11, meta 10, ring 84, dockIcon 30, sectionSpacing 16, rowHasMeta false). `.compact` for now returns `.regular` (filled in Task 9). Widths: regular 400/660/870, compact 340/560/740.

- [ ] **Step 4: Run tests.** Expected: PASS (all old `IslandLayoutConfigTests` too).

- [ ] **Step 5: Commit** `feat(core): métricas por densidade e larguras do compacto`.

### Task 3: Inject theme and metrics; settings keys; snapshot overrides

**Files:**
- Create: `Sources/DrIsland/IslandEnvironment.swift`
- Modify: `SettingsKey.swift`, `Settings.swift` (`registerDefaults`), `IslandView.swift` (`details`, `managementPage`, `layoutWidth`, `columnWidth`, `height(of:)`), `IslandLayout.swift`, `IslandController.swift:33-35`, `IslandInstance.swift:111-120`

**Interfaces:**
- Consumes: `IslandTheme`, `IslandPalette`, `IslandDensity`, `IslandMetrics`, `IslandLayoutConfig.width(density:)` (Tasks 1–2).
- Produces:
  - `extension EnvironmentValues { var islandPalette: IslandPalette /* default .grafite */; var islandMetrics: IslandMetrics /* default .regular */ }`
  - `extension Color { init(_ c: ThemeColor) }`; `extension ShapeStyle where Self == Color { static func token(_ c: ThemeColor) -> Color }` (optional sugar).
  - `SettingsKey.islandTheme = "islandTheme"`, `SettingsKey.islandDensity = "islandDensity"`, `SettingsKey.densityHotKey = "densityHotKey"`.
  - `enum IslandOverrides { static var theme: IslandTheme?; static var density: IslandDensity?; static var columns: Int?; static var snapshotDelay: Double /* default 3 */ }` reading `DR_ISLAND_THEME`, `DR_ISLAND_DENSITY`, `DR_ISLAND_COLUMNS`, `DR_ISLAND_SNAPSHOT_DELAY` (put it in `IslandEnvironment.swift` or its own file `IslandOverrides.swift`, one type per file).

- [ ] **Step 1: Take the «before» snapshot.** `scripts/bundle.sh debug`, then run the app with `DR_ISLAND_SNAPSHOT=/tmp/…/before.png DR_ISLAND_FAKE=0.42` (scratch dir), wait for the file, kill the app.
- [ ] **Step 2: Implement** the keys, defaults, overrides and environment injection. `IslandView` reads `@AppStorage(SettingsKey.islandTheme)`/`islandDensity`, applies overrides, and sets `.environment(\.islandPalette, …)` / `.environment(\.islandMetrics, …)` on `details` and `managementPage`. `layoutWidth` uses `layout.width(density:)`; `height(of:)` and `naturalHeight` use `IslandMetrics` (`listCard(sections:)` replaces the local `section` closure). `IslandLayout` keeps density-independent constants; density-dependent ones are deleted and call sites read the metrics. `DR_ISLAND_COLUMNS` resizes the decoded layout with `resized(to:)` for that launch only. Snapshot delay replaces the hard-coded `3` in `IslandController.start()`.
- [ ] **Step 3: Run tests** (`swift test`). Expected: PASS.
- [ ] **Step 4: Build and take the «after» snapshot** with the same command. Expected: visually identical to «before» (open both; only clock/relative times may differ).
- [ ] **Step 5: Manual check:** with the app running, `defaults write pt.doutorfinancas.dr-island islandDensity compact` then back to `regular`: no crash, island resizes (compact = same sizes for now, but narrower widths).
- [ ] **Step 6: Commit** `feat(island): injeta tema e métricas no ambiente; overrides de snapshot`.

### Task 4: Migrate every island view to the tokens (no visual change)

**Files:**
- Modify: every view under `Sources/DrIsland/` drawn inside the island: `IslandView.swift`, `ClaudeBlock.swift`, `UsageBar.swift`, `FocusBlock.swift`, `MusicBlock.swift`, `AlertsBlock.swift`, `BriefingBlock.swift`, `TimelineBlock.swift`, `BacklogBlock.swift`, `UsageHistoryChart.swift`, `PullRequestRow.swift`, `ReviewIcon.swift`, `JiraTaskRow.swift`, `PullRequestSection.swift`, `JiraSection.swift`, `ListSectionHeader.swift`, `ListNote.swift`, `ListRule.swift`, `ListExpander.swift`, `RowTag.swift`, `OwnerTag.swift`, `SprintBar.swift`, `CardTitle.swift`, `View+BlockCard.swift`, `ShortcutsDock.swift`, `IslandTipLayer.swift`, `IslandPageDots.swift`, `StreamChip(s).swift`, management views (`Management*.swift`, `Burndown*`, `Bugs*`, `Flow*`, `Velocity*`, `HourlyLineChart.swift`), `Brand.swift` (`color(forFraction:amber:red:palette:)`), `PRChange+Color.swift` (tone colours from palette).
- Not touched: Settings pages (they use the system appearance).

**Interfaces:**
- Consumes: `\.islandPalette`, `\.islandMetrics`, `Color(ThemeColor)` (Task 3).
- Produces: `Brand.color(forFraction: Double, amber: Double, red: Double, palette: IslandPalette) -> Color`; `PRChange.Tone.color(in palette: IslandPalette) -> Color`.

- [ ] **Step 1: Migrate view by view.** Mapping: `.white.opacity(0.9)`/`.primary` → `palette.text`; `.secondary` → `textSecondary`; `.tertiary`/`.white.opacity(0.5…0.6)` → `textTertiary`; `Color.white.opacity(0.055)` card fill → `surface`; `.white.opacity(0.12…0.14)` tracks/capsules → `surfaceRaised`; `Brand.blue` → `accent`; `Brand.green/amber/red` → `green/amber/red`; `Color.black` island fill → `base`; sizes from `IslandLayout.*` → `metrics.*`. Commit every few files once they compile (`scripts/bundle.sh debug`).
- [ ] **Step 2: Verify no literals remain.** Run `grep -n "white.opacity\|Color.white\|\.secondary\|\.tertiary\|Brand\.\(blue\|green\|amber\|red\)" Sources/DrIsland/*.swift | grep -v "Settings\|Page.swift\|SettingsAbout"`. Expected: only the mini island's black base and the notch ring (spec: they keep black) and the splash.
- [ ] **Step 3: Snapshot** (overview and `DR_ISLAND_PAGE=management DR_ISLAND_FAKE_MANAGEMENT=1`). Expected: visually identical to Task 3's «before».
- [ ] **Step 4: Run tests.** Expected: PASS.
- [ ] **Step 5: Commit** `refactor(island): views usam tokens de tema e métricas`.

### Task 5: Shared components

**Files:**
- Create: `Sources/DrIsland/BlockCard.swift`, `CardHeader.swift`, `SegmentedTabs.swift`, `ListRow.swift`, `Pill.swift`, `Avatar.swift`, `ColumnFade.swift`, `Sources/DrIslandCore/AvatarColor.swift`
- Test: `Tests/DrIslandCoreTests/AvatarColorTests.swift`

**Interfaces:**
- Produces:
  - `public enum AvatarColor { public static func index(for name: String, count: Int) -> Int }` (stable hash: sum of unicode scalars of the lowercased, trimmed name, mod count; empty name → 0). App keeps a list of 8 avatar hues.
  - `struct BlockCard<Content: View>: View { init(active: Bool = false, @ViewBuilder content: () -> Content) }`: surface fill, `border` stroke 1 pt, `highlight` 1 pt top inner line, radius/padding from metrics, shadow only when `palette.isLight` (`y: 4, radius: 14, opacity .05`). `active`: fill `accent @ .14`, stroke `accent @ .35`. Also `extension View { func blockCard(active: Bool = false) -> some View }` now wraps `BlockCard` so call sites keep compiling.
  - `struct CardHeader<Accessory: View>: View { init(title: String, icon: String, source: IslandBlock, count: Int? = nil, @ViewBuilder accessory: () -> Accessory) }`: tile (size `metrics.tile`, radius `tile·0.3`, fill `source colour @ .20`, symbol in source colour at `tile·0.6`), title (`titleSize`, semibold, `text`), count capsule (`metaSize`, `surfaceRaised`), accessory trailing. Height `metrics.cardHeader`.
  - `struct SegmentedTabs: View { struct Tab: Identifiable { id: String; title: String; count: Int; badge: Color? }; init(tabs: [Tab], selection: Binding<String>) }`: capsule track `surfaceRaised`, selected segment `surface` with shadow; badge = 6 pt dot.
  - `struct ListRow<Leading: View, Trailing: View>: View { init(key: String?, title: String, meta: String?, tint: Color? = nil, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) }`: key in monospaced `metaSize` `textTertiary`; title `bodySize` `text`, one line, tail truncation; meta under the title only when `metrics.rowHasMeta`; height `metrics.rowHeight`; `tint` = the existing row-change background (rounded 5, `−6` horizontal padding).
  - `struct Pill: View { init(_ text: String, _ color: Color) }`: fill `color @ .18`, text in `color`, `metaSize − 0.5` semibold. `RowTag` becomes a typealias-free wrapper calling `Pill` (keep the type name so existing call sites compile; delete it in Task 8).
  - `struct Avatar: View { let name: String?; let isMine: Bool }`: hides like `OwnerTag` (`SettingsKey.showOwner`, `Owner.label`); circle of `metrics.tile − 6` with initials, fill from `AvatarColor`, mine → `accent`; tooltip = full name / «Teu».
  - `struct ColumnFade: ViewModifier` + `extension View { func columnFade(active: Bool) -> some View }`: a bottom mask (`LinearGradient` black→clear over 42 pt) applied only when `active`.

- [ ] **Step 1: Write the failing test**
```swift
@Suite struct AvatarColorTests {
    @Test func stableAndInRange() {
        #expect(AvatarColor.index(for: "Luís Costa", count: 8) == AvatarColor.index(for: " luís costa ", count: 8))
        #expect((0..<8).contains(AvatarColor.index(for: "Sara Oliveira", count: 8)))
        #expect(AvatarColor.index(for: "", count: 8) == 0)
    }
}
```
- [ ] **Step 2: Run** `swift test --filter AvatarColorTests`. Expected: FAIL.
- [ ] **Step 3: Implement `AvatarColor` and the components.**
- [ ] **Step 4: Run tests and build** (`swift test`, `scripts/bundle.sh debug`). Expected: PASS and build OK. The look only changes where `blockCard()` was already used, with grafite border/highlight still zero.
- [ ] **Step 5: Commit** `feat(island): componentes base (card, cabeçalho, abas, linha, pill, avatar, fade)`.

### Task 6: Camadas look: new Normal metrics, island header, Claude/Foco/Música

**Files:**
- Create: `Sources/DrIsland/IslandHeader.swift`, `Sources/DrIslandCore/Greeting.swift`
- Modify: `IslandMetrics.swift` (`.regular` values), `IslandTheme.swift` (grafite border/highlight), `IslandView.swift` (replace `watermark` + buttons overlay with `IslandHeader`), `ClaudeBlock.swift`, `FocusBlock.swift`, `MusicBlock.swift`
- Test: `IslandMetricsTests.swift`, `IslandThemeTests.swift`, `Tests/DrIslandCoreTests/GreetingTests.swift`

**Interfaces:**
- Produces: `public enum Greeting { public static func text(for date: Date, calendar: Calendar = .current) -> String }` (05:00–11:59 «Bom dia», 12:00–19:59 «Boa tarde», otherwise «Boa noite»). `struct IslandHeader: View` (logo; greeting + «· qua, 25 nov» only when the column count ≥ 2 and density is regular; right side: live/offline status, Gestão when shown, restart, settings).

- [ ] **Step 1: Update tests.** In `IslandMetricsTests`, replace `regularStartsWithTodaysSizes` with:
```swift
@Test func regularIsCamadas() {
    let m = IslandMetrics.forDensity(.regular)
    #expect(m.cardPadding == 14); #expect(m.cardGap == 12); #expect(m.cardRadius == 18)
    #expect(m.rowHeight == 34); #expect(m.rowHasMeta); #expect(m.cardHeader == 26); #expect(m.tile == 24)
    #expect(m.titleSize == 13); #expect(m.bodySize == 13); #expect(m.metaSize == 11.5); #expect(m.ringSize == 84)
}
```
Update `listCardMatchesTodaysFormula` to the new numbers (recompute with the formula). In `IslandThemeTests.grafiteMatchesTodaysColours` add `#expect(p.border == ThemeColor(0xFFFFFF, alpha: 0.07))`. Add `GreetingTests` with 08:00 → «Bom dia», 12:00 → «Boa tarde», 19:59 → «Boa tarde», 20:00 → «Boa noite», 04:59 → «Boa noite».
- [ ] **Step 2: Run tests.** Expected: FAIL.
- [ ] **Step 3: Implement.** `.regular`: padding 14, gap 12, radius 18, row 34, rowHasMeta true, listHeader 20, listRule 13, cardHeader 26, tile 24, title 13, body 13, meta 11.5, ring 84, dockIcon 30, sectionSpacing 12. Claude block inside `BlockCard` with `CardHeader(title: "Claude", icon: "sparkle", source: .claude) { reset label }`, ring or bar per `claudeGauge`, bars «Sessão» and «Semana · 5d 14h» with value at right, forecast chip only with `rowHasMeta`. Foco: one-line card (tile, «Foco · ronda N de 4», dots when `rowHasMeta`, time, play). Música: one-line card; with nothing playing, a single row «Nada a tocar» with `metrics.rowHeight`. Update their `contentHeight` helpers / `IslandLayout` sizes to come from metrics.
- [ ] **Step 4: Run tests + snapshot** (`DR_ISLAND_COLUMNS=2`). Expected: tests PASS; Claude/Foco/Música look like the lab's «A · Camadas».
- [ ] **Step 5: Commit** `feat(island): cabeçalho e blocos Claude, Foco e Música no layout Camadas`.

### Task 7: Lists with tabs: Git, Jira, Sprint

**Files:**
- Create: `Sources/DrIslandCore/TabChoice.swift`
- Modify: `IslandState.swift` (`gitTab`, `jiraTab`), `IslandView.swift` (`.pullRequests`, `.jira`, `.sprint` cases and their `height(of:)`), `PullRequestRow.swift`, `JiraTaskRow.swift`, `PullRequestSection.swift`, `JiraSection.swift`, `OwnerTag.swift` → use `Avatar`
- Test: `Tests/DrIslandCoreTests/TabChoiceTests.swift`

**Interfaces:**
- Produces:
  - `public enum TwoListTab: String, Sendable { case first, second }`
  - `public enum TabChoice { public static func tabs(firstCount: Int, secondCount: Int, secondEnabled: Bool) -> [TwoListTab] /* [] = single list, no tabs */; public static func onOpen(current: TwoListTab, firstUnseen: Int, secondUnseen: Int) -> TwoListTab }`
  - `IslandState.gitTab: TwoListTab = .first`, `IslandState.jiraTab: TwoListTab = .first` (session only).
- Rules: tabs only when `secondEnabled` and both lists have rows (status messages count as rows only for the first list). `onOpen`: switch to the other tab only when the current has 0 unseen and the other > 0.

- [ ] **Step 1: Write the failing tests**
```swift
@Suite struct TabChoiceTests {
    @Test func singleListHasNoTabs() {
        #expect(TabChoice.tabs(firstCount: 3, secondCount: 4, secondEnabled: false).isEmpty)
        #expect(TabChoice.tabs(firstCount: 3, secondCount: 0, secondEnabled: true).isEmpty)
        #expect(TabChoice.tabs(firstCount: 0, secondCount: 2, secondEnabled: true).isEmpty)
        #expect(TabChoice.tabs(firstCount: 3, secondCount: 4, secondEnabled: true) == [.first, .second])
    }
    @Test func openingSwitchesToTheTabWithNews() {
        #expect(TabChoice.onOpen(current: .first, firstUnseen: 0, secondUnseen: 2) == .second)
        #expect(TabChoice.onOpen(current: .first, firstUnseen: 1, secondUnseen: 2) == .first)
        #expect(TabChoice.onOpen(current: .second, firstUnseen: 0, secondUnseen: 0) == .second)
    }
}
```
- [ ] **Step 2: Run** `swift test --filter TabChoiceTests`. Expected: FAIL.
- [ ] **Step 3: Implement.** Git card: `CardHeader(title: "Pull requests", icon: "arrow.triangle.pull", source: .pullRequests) { SegmentedTabs("Meus N" / "A rever N") }`; with no tabs (`TabChoice.tabs` empty) show the non-empty list (or the first one) with its count. Tab badge = colour of the loudest unseen change among that list's rows (`prStore.unseen`). Call `TabChoice.onOpen` when `state.expanded` becomes true. Jira card: tabs «Tasks N» / «Aprovações N» (`approvalRows`). Sprint card: header = sprint name (one sprint) with accessory «dia X/Y» + `SprintBar`; sublists «As minhas · N» and «Aprovações · N» via `ListSectionHeader`; several sprints stay stacked. `PullRequestRow` → `ListRow(key: "#n", title:, meta: repository [· author when reviewRequested] [· "N threads"])`, keeping CI/conflict/review icons in `leading`, `Pill`s + `Avatar` in `trailing`, mutes opacity, tips and context menu unchanged. `JiraTaskRow` → `ListRow(key:, title: summary, meta: issueType [· priority | · assignee for approvals])`, kind symbol in `leading`, status `Pill` (colour by `category`), `Avatar`. Heights in `height(of:)`: Git/Jira use `listCard(sections: [visible tab rows])` (single section, no list header when tabs are shown: add `IslandMetrics.listCard(rows:)` = `card(cardHeader + rows·rowHeight)`, with a test).
- [ ] **Step 4: Run tests, build, snapshot.** Expected: PASS; Git card with tabs, rows on two lines.
- [ ] **Step 5: Manual check:** turn off «Incluir pedidos de review» in Definições → Git card shows a single list with no tabs.
- [ ] **Step 6: Commit** `feat(island): listas Git/Jira com abas e linhas com meta`.

### Task 8: Remaining blocks, alerts vs briefing, columns, dock

**Files:**
- Modify: `IslandView.swift` (`isVisible`, `details`), `AlertsBlock.swift`, `BriefingBlock.swift`, `BacklogBlock.swift`, `TimelineBlock.swift`, `UsageHistoryChart.swift`, `ShortcutsDock.swift`; delete `CardTitle.swift`, `View+BlockCard.swift`, `RowTag.swift`, `OwnerTag.swift` once unused.

**Interfaces:**
- Consumes: components (Task 5), metrics.

- [ ] **Step 1: Implement.** `isVisible(.alerts)` adds `&& !briefingActive`. Alerts: `CardHeader(title: "Avisos", icon: "bell", source: .alerts, count:) { «ver tudo» }`, rows = dot in source colour, origin in small caps (`metaSize − 1`, bold, `textTertiary`), title, time. Briefing: same rows, header «Desde ontem · HH:MM» with «ok». Backlog/History/Timeline: `BlockCard` + `CardHeader`, content unchanged. `details`: remove the 1 pt divider (column gap = `metrics.cardGap · 2`), column spacing = `metrics.cardGap`, apply `.columnFade(active: naturalHeight(of: column) > maxColumnHeight)`. Dock: theme surface/border, icon size `metrics.dockIcon`.
- [ ] **Step 2: Verify** `grep -rn "CardTitle\|RowTag\|OwnerTag\|blockCard(" Sources/DrIsland` returns nothing; build passes.
- [ ] **Step 3: Snapshot 1, 2 and 3 columns** (`DR_ISLAND_COLUMNS=1|2|3`). Expected: no clipped card; a column taller than half the screen fades at the bottom; no duplicate alerts when the briefing is active.
- [ ] **Step 4: Run tests.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(island): restantes blocos, avisos/resumo sem repetição, fade nas colunas`.

### Task 9: Compact mode

**Files:**
- Modify: `IslandMetrics.swift` (`.compact`), `HotKeyManager.swift`, `IslandController.swift` (observe density hotkey), `AppearancePage.swift`
- Create: `Sources/DrIsland/ThemeAndSizeSection.swift`
- Test: `IslandMetricsTests.swift`

**Interfaces:**
- Produces: `Notification.Name.islandDensityHotKey`; `ThemeAndSizeSection: View` (used by `AppearancePage`, extended in Task 10).

- [ ] **Step 1: Write the failing tests**
```swift
@Test func compactValues() {
    let m = IslandMetrics.forDensity(.compact)
    #expect(m.cardPadding == 9); #expect(m.cardGap == 8); #expect(m.cardRadius == 12)
    #expect(m.rowHeight == 22); #expect(!m.rowHasMeta); #expect(m.cardHeader == 20); #expect(m.tile == 18)
    #expect(m.titleSize == 11.5); #expect(m.bodySize == 11.5); #expect(m.metaSize == 10.5)
    #expect(m.ringSize == 52); #expect(m.dockIcon == 22)
}
@Test func compactNeverTallerThanToday() {
    let c = IslandMetrics.forDensity(.compact)
    for rows in 0...10 {
        let today = 20.0 + (rows == 0 ? 0 : 20 + 2 + Double(rows) * 25) + 20   // today's one-list card
        #expect(c.listCard(sections: [rows]) <= today)
        #expect(c.listCard(rows: rows) <= today)
    }
}
```
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** `.compact` (values above; listHeader 16, listRule 9, sectionSpacing 8). `HotKeyManager`: register a second hotkey from `SettingsKey.densityHotKey` with `EventHotKeyID(signature: 0x54494C44, id: 2)`; in the Carbon handler read the `kEventParamDirectObject` `EventHotKeyID` and post `.islandHotKey` for id 1, `.islandDensityHotKey` for id 2. On `.islandDensityHotKey`, toggle `islandDensity` in UserDefaults. `ThemeAndSizeSection` (first section of «Aparência», title «Tema e tamanho»): segmented «Tamanho» (Normal | Compacto) and picker «Atalho para alternar o tamanho» with `HotKeyOption.allCases`, disabling the option equal to `SettingsKey.hotKey` (and `GeneralPage`'s picker disables the density one).
- [ ] **Step 4: Run tests + snapshot** with `DR_ISLAND_DENSITY=compact DR_ISLAND_COLUMNS=2`. Expected: PASS; island 560 pt wide, one-line rows, small ring, smaller dock.
- [ ] **Step 5: Manual check:** set the density hotkey to ⌃⌥Espaço, press it twice → island toggles compact/normal; main hotkey still opens the island.
- [ ] **Step 6: Commit** `feat(island): modo compacto com atalho`.

### Task 10: Themes: Meia-noite, Aurora, Claro, accessibility, thumbnails

**Files:**
- Create: `Sources/DrIsland/ThemeThumbnail.swift`
- Modify: `IslandView.swift` (island fill, `preferredColorScheme`), `IslandTipLayer.swift`, `ThemeAndSizeSection.swift`, `IslandEnvironment.swift`

**Interfaces:**
- Consumes: `IslandTheme.palette` (Task 1).
- Produces: `extension IslandPalette { func adjusted(increaseContrast: Bool, reduceTransparency: Bool) -> IslandPalette }` in Core (pure; add 2 tests in `IslandThemeTests`: increased contrast raises `textSecondary` contrast on the card; reduced transparency makes `surface.a == 1` by compositing over `base.last`).

- [ ] **Step 1: Write the failing tests** for `adjusted` (as above).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Island fill: `LinearGradient(base stops)`; for Claro, a black band of `metrics.height + 6` at the top above the light body (header text uses fixed light colours on it); for Aurora, two radial glows (violet `7A5CFF @ .28` top-left, teal `00BEC8 @ .20` top-right) over the base, skipped when reduce transparency is on. Replace `.preferredColorScheme(.dark)` in `details`/`managementPage` with `palette.isLight ? .light : .dark`. `IslandTipLayer`: background `surfaceRaised` over base, text `text`, border `border`. Read `@Environment(\.colorSchemeContrast)` and `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency` to call `adjusted`. Mini island and notch ring: only accent/semantic colours from the palette, base stays black. `ThemeThumbnail`: 64×40 rounded rectangle with base, a small card and an accent dot; selected = accent ring; four in an `HStack` in «Tema e tamanho» with the titles under them.
- [ ] **Step 4: Run tests; snapshot each theme** (`DR_ISLAND_THEME=grafite|meia-noite|aurora|claro`, normal and compact). Expected: PASS; Claro's top strip blends with the notch; tooltips readable in Claro.
- [ ] **Step 5: Manual check:** Ajustes do Sistema → Acessibilidade → Ecrã → «Aumentar contraste» and «Reduzir transparência» on → island still readable, Aurora glows gone.
- [ ] **Step 6: Commit** `feat(island): temas Meia-noite, Aurora e Claro, com acessibilidade`.

### Task 11: Documentation and final pass

**Files:**
- Modify: `docs/funcionalidades.md`, `README.md`, `CLAUDE.md` (debug env vars list), `Sources/DrIsland/SettingsLayout.swift` (footer text: widths per density)

- [ ] **Step 1: Update docs:** themes, compact mode and hotkey, tabs and the open-on-news rule, alerts hidden while the briefing is active, music one-line empty state, column fade, new env vars (`DR_ISLAND_THEME`, `DR_ISLAND_DENSITY`, `DR_ISLAND_COLUMNS`, `DR_ISLAND_SNAPSHOT_DELAY`). Layout footer: «Normal: 400 / 660 / 870 pt; Compacto: 340 / 560 / 740 pt».
- [ ] **Step 2: Full test run** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`. Expected: all PASS.
- [ ] **Step 3: Release build** `scripts/bundle.sh release`. Expected: «Built DrIsland.app».
- [ ] **Step 4: Snapshot matrix** 4 themes × 2 densities × 1/2/3 columns into the scratch dir; inspect for clipping, unreadable text, wrong widths.
- [ ] **Step 5: Commit** `docs: temas, modo compacto e layout Camadas`.
