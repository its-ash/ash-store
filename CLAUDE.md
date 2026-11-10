# Ash Store

Android app store for its-ash apps. Flutter, Android only, package `com.itsash.store`.

## Layout
- `lib/src/catalog.dart`: catalog = GitHub search `topic:ash-store user:its-ash` → `store.json` from raw.githubusercontent → `releases/latest`. Cached in app support dir for 15 min; on failure the cache is shown with a warning.
- `lib/src/store_controller.dart`: `StoreController` (ChangeNotifier, exposed by `StoreScope`). Installed versions, download progress, install flow. A pending install resumes when the app returns from the "Install unknown apps" setting.
- `lib/src/packages.dart` ↔ `android/.../MainActivity.kt`: MethodChannel `com.itsash.store/packages` (`installedVersion`, `canInstall`, `openInstallSettings`, `install`, `launch`, `uninstall`). APKs are downloaded to `<cache>/apks/` and shared through the FileProvider `${applicationId}.files`.
- `store-kit/`: shared publishing kit for every app repo (see `store-kit/STORE.md`). `make store-sync` at the workspace root copies it.

## Rules
- UI uses the shared `theme` package only (`package:theme/theme.dart`). Read `../theme/COMPONENTS.md` first.
- Unauthenticated GitHub API: 60 calls/hour. Don't add per-app API calls to the catalog without caching them.
- Installed apps are detected through the `<queries>` LAUNCHER intent in the manifest; keep it.

## Commands
- `make run`, `make build`, `make test`, `make analyze`, `make deploy` (from `store.mk`).

## Release (Ash Store)
- This repo uses its own kit: `store.json` (id `ash-store`, `"catalog": true`), `store.mk`, `index.html` + `CNAME` (`store.itsash.in`).
- `make deploy` = bump version → build → commit, tag `vX.Y.Z`, push → GitHub release with `ash-store.apk` → repo topics, homepage, Pages. Never create releases, tags or asset names by hand.
- After editing `store-kit/store.mk` or `store-kit/landing.html`, run `make store-sync` at the workspace root.
