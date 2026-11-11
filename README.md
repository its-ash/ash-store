# Ash Store

Install and update every its-ash Android app in one place.

**[Website](https://store.itsash.in)** · **[Download APK](https://github.com/its-ash/ash-store/releases/latest/download/ash-store.apk)**

## Features

- **Familiar store layout**: green-accent Apps / Search / Updates / Settings
  tabs, a For you home with carousels, Top charts, Categories, live search and
  full app pages with similar apps.
- **Catalog from GitHub**: lists every `its-ash` repo tagged `ash-store` that
  has a `store.json` and a release APK. No central list to keep up to date.
- **Direct install**: downloads the APK from the app's latest GitHub release
  and installs it itself with Android's PackageInstaller (no browser, no
  installer screen to hunt for). The first install of each app shows one system
  confirmation (an Android rule). Updates of apps the store installed earlier are
  silent on Android 12+ (and stay silent on Android 14+ once the store is the
  update owner). Google Play Protect may still offer to scan an app; that prompt
  belongs to Google and cannot be turned off by an app.
- **Updates**: compares the installed version with the latest release and shows
  an Update button, an Updates tab with a count badge and "Update all". The store updates itself the same way.
- **Open and uninstall** installed apps.
- **Works offline-first**: the catalog is cached for 15 minutes and the cached
  copy is shown if GitHub can't be reached or the rate limit is hit.
- No account and no tracking.

## Install

Download the [latest APK](https://github.com/its-ash/ash-store/releases/latest/download/ash-store.apk)
on your phone and open it. Allow your browser to install unknown apps if
Android asks.

The first time you install an app from the store, Android asks you to allow
Ash Store to **install unknown apps**. The store opens that setting for you,
and the install continues when you come back. After that: one confirm per new
app, silent updates on Android 12+.

## Develop

Needs Flutter ≥ 3.44 and the shared theme package at `../theme`.

```bash
make run      # run on a connected device
make build    # release APK
make test
make deploy   # bump version, build, tag, push, GitHub release (see store.mk)
```

## Release

`make deploy` follows the Ash Store kit (`store.mk`, `store.json`): it bumps the
version in `pubspec.yaml`, builds, commits, tags `vX.Y.Z`, pushes, and publishes
a GitHub release with `ash-store.apk`.

## The store kit

`store-kit/` holds what every app repo shares. Read
[store-kit/STORE.md](store-kit/STORE.md) to list a new app.

| File | Use |
|---|---|
| `store-kit/STORE.md` | How listing, releases, landing pages and signing work. |
| `store-kit/store.mk` | Shared `deploy` / `release` / `bump` targets. Copied into each app by `make store-sync` at the workspace root. |
| `store-kit/landing.html` | Generic landing page that reads `store.json`. |
| `store-kit/README.template.md` | README layout every app follows. |
| `store-kit/store.schema.json` | JSON schema for `store.json`. |

## Project layout

```
lib/
├── main.dart
└── src/
    ├── config.dart            # owner, topic, GitHub URLs, cache time
    ├── models.dart            # StoreManifest, StoreRelease, StoreApp, version compare
    ├── catalog.dart           # GitHub search + store.json + latest release, disk cache
    ├── store_controller.dart  # catalog, installed versions, downloads, install flow
    ├── packages.dart          # MethodChannel to the Android package manager
    ├── home_screen.dart       # list, search, filters, permission and update banners
    ├── app_screen.dart        # app details, install/update/open/uninstall
    └── widgets.dart           # icon, install button, state pill, install flow
android/app/src/main/kotlin/com/itsash/store/MainActivity.kt   # installer bridge
index.html                     # store.itsash.in: lists every app
```

## License

No license file is included yet.

Built by [itsash.in](https://itsash.in).
