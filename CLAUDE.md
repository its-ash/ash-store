# Ash Store

Android app store for its-ash apps. Flutter, Android only, package `com.itsash.store`.

## Layout
- `lib/src/catalog.dart`: catalog = GitHub search `topic:ash-store user:its-ash` → `store.json` from raw.githubusercontent → `releases/latest`. Cached in app support dir for 15 min; on failure the cache is shown with a warning.
- `lib/src/store_controller.dart`: `StoreController` (ChangeNotifier, exposed by `StoreScope`). Installed versions, download progress, install flow. A pending install resumes when the app returns from the "Install unknown apps" setting.
- `lib/src/packages.dart` ↔ `android/.../MainActivity.kt`: MethodChannel `com.itsash.store/packages` (`installedVersion`, `canInstall`, `openInstallSettings`, `install(path, package)`, `launch`, `uninstall`; native → Dart callback `installResult {package, success, status, message}`). APKs are downloaded to `<cache>/apks/` and installed with a `PackageInstaller.Session` (no ACTION_VIEW). `InstallResultReceiver` (in `MainActivity.kt`) gets the commit result: `STATUS_PENDING_USER_ACTION` launches the system confirm (first installs), anything else is forwarded to Dart, where `StoreController` clears `installing`, refreshes versions and emits `outcomes` (toast in `home_screen.dart`). On API 31+ `setRequireUserAction(USER_ACTION_NOT_REQUIRED)` + `UPDATE_PACKAGES_WITHOUT_USER_ACTION` make updates silent; on API 34+ `setRequestUpdateOwnership(true)`. The first install always needs one OS confirm; Play Protect's scan prompt is Google's and can't be suppressed. No root/device-owner tricks. `packages.dart`: `Packages` delegates to a `PackageBridge` (`Packages.bridge = FakePackages()` in tests).
- UI is Play Store–style (own branding, no Google assets). Accent green `storeGreen` (#01875F) is passed to `UiApp(accent:)` in `main.dart`; the theme lightens it in dark mode. Backgrounds use `colors.surface` (white / near-black).
  - `home_screen.dart`: `UiBottomNav` with 4 tabs kept alive in an `IndexedStack`: Apps (`explore_tab.dart`), Search (`search_tab.dart`), Updates (`updates_tab.dart`, badge = apps with updates), Settings (`settings_screen.dart`, ends with `UiUpdateSection` then `UiDeveloperSection`).
  - Apps tab: search pill (opens Search tab) + store avatar (opens Settings), `UiTabs` For you (featured card of the newest release, one carousel per category, Recently updated) / Top charts (ranked list, stars then newest) / Categories (list → `category_screen.dart`). Pull to refresh everywhere.
  - `app_screen.dart`: store-style detail page (icon, name, "Ash Store" in accent, stats row, Install / Update / Open + Uninstall, progress, optional screenshots from `store.json` `screenshots`, About this app sheet, What's new, links, Similar apps).
  - `browse.dart`: pure helpers (search, top charts, categories, similar). `widgets.dart`: `AppIcon` (squircle), `InstallButton`, `AppRowTile`, `AppCard`, `AppCarousel`, `CatalogGate` (skeleton / error), `StoreNotices` (stale cache, install permission, store self-update), `runInstall`, `updateAll`.
- `store-kit/`: shared publishing kit for every app repo (see `store-kit/STORE.md`). `make store-sync` at the workspace root copies it.

## Rules
- UI uses the shared `theme` package only (`package:theme/theme.dart`). Read `../theme/COMPONENTS.md` first.
- Unauthenticated GitHub API: 60 calls/hour. Don't add per-app API calls to the catalog without caching them.
- Installed apps are detected through the `<queries>` LAUNCHER intent in the manifest; keep it.

## Commands
- Tests: `test/models_test.dart`, `test/store_ui_test.dart` (helpers + all screens at 320 px). Keep new screens overflow-free at 320 px.
- `make run`, `make build`, `make test`, `make analyze`, `make deploy` (from `store.mk`).

## Release (Ash Store)
- This repo uses its own kit: `store.json` (id `ash-store`, `"catalog": true`), `store.mk`, `index.html` + `CNAME` (`store.itsash.in`).
- `make deploy` = bump version → build → commit, tag `vX.Y.Z`, push → GitHub release with `ash-store.apk` → repo topics, homepage, Pages. Never create releases, tags or asset names by hand.
- After editing `store-kit/store.mk` or `store-kit/landing.html`, run `make store-sync` at the workspace root.
