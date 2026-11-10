# Ash Store kit

How every its-ash Android app is published, so that it shows up in Ash Store,
has its own landing page with a download button, and ships with `make deploy`.

## How an app gets listed

Ash Store (and the store website) builds its catalog from GitHub at runtime:

1. **Find apps**: search repos owned by `its-ash` with the topic `ash-store`.
2. **Read the manifest**: `store.json` at the root of the repo's default branch.
3. **Find the APK**: the repo's latest GitHub release, asset `<id>.apk`
   (falls back to any `.apk` asset).

No central list to edit. Tag a repo, add `store.json`, publish a release, and
the app appears in the store.

## Every app repo has

| File | What it is |
|---|---|
| `store.json` | Store manifest (below). |
| `store.mk` | Shared release targets. Copied from `store-kit/store.mk`; do not edit in place. |
| `Makefile` | Sets `STORE_ID` (and `APP_DIR`, `EXTRA_ASSETS` if needed), defines `run` and `build`, ends with `include store.mk`. |
| `index.html` | Landing page served by GitHub Pages. Either a custom page, or `store-kit/landing.html` (reads `store.json`, needs no edits). |
| `CNAME` | `<id>.itsash.in`. `*.itsash.in` already points at GitHub Pages. |
| `README.md` | Follows `store-kit/README.template.md`. |
| `.gitignore` | Contains `dist/`. |

## store.json

```json
{
  "id": "linkdrop",
  "name": "LinkDrop",
  "repo": "its-ash/linkdrop",
  "package": "com.itsash.linkdrop",
  "tagline": "Share a link. Get the file.",
  "description": "Longer text for the store page and landing page.",
  "category": "Tools",
  "icon": "assets/icon/icon.png",
  "homepage": "https://linkdrop.itsash.in/"
}
```

| Key | Required | Meaning |
|---|---|---|
| `id` | yes | Slug. Release asset is `<id>.apk`. Must equal `STORE_ID` in the Makefile. |
| `name` | yes | Display name. |
| `repo` | yes | `owner/name` on GitHub. |
| `package` | yes | Android `applicationId`. The store uses it to read the installed version. |
| `tagline` | yes | One line. Also used as the GitHub repo description. |
| `description` | no | A short paragraph. |
| `category` | no | `Tools`, `Productivity`, `Security`, `Utilities`, `Lifestyle`, … |
| `icon` | no | Repo-relative path (or URL) to a square PNG, 192 px or larger. |
| `homepage` | yes | Landing page URL. Set as the repo homepage. |
| `listed` | no | `false` hides the app from the store. |
| `catalog` | no | `true` only for Ash Store: its landing page lists every app. |

Keep one key per line: `store.mk` reads it with `sed`.

## make deploy

```
make deploy = store-check → bump → build → release
```

- `store-check`: `store.json` is valid, `gh` is logged in, you are on `main`.
- `bump`: patch +1 and build number +1 in `pubspec.yaml` (`1.0.3+4` → `1.0.4+5`).
- `build`: the app's own target.
- `release`:
  1. copies the APK to `dist/<id>.apk` and writes `dist/<id>.apk.sha256`;
  2. commits everything (`git add -A`; message from `copilot` when available,
     otherwise `release: vX.Y.Z`), tags `vX.Y.Z`, pushes `main` and the tag;
  3. `gh release create vX.Y.Z dist/<id>.apk dist/<id>.apk.sha256 --generate-notes --latest`;
  4. `store-meta`: adds the `ash-store`, `android` and `flutter` topics, sets the
     homepage and description from `store.json`, and turns on GitHub Pages.

The stable download link for any app is:

```
https://github.com/its-ash/<repo>/releases/latest/download/<id>.apk
```

## Add a new app

1. Add `store.json` (see above) and `dist/` to `.gitignore`.
2. Write the Makefile: `STORE_ID := <id>`, `run`, `build`, `include store.mk`.
3. At the workspace root run `make store-sync` (copies `store.mk`, and
   `landing.html` as `index.html` if the app has no landing page).
4. Add `CNAME` with `<id>.itsash.in`.
5. Write the README from `README.template.md`.
6. `make deploy`.

## Signing

Android installs an update only when it is signed with the same key as the
installed copy. Today every app's release build uses the **debug key** of the
machine that builds it (`~/.android/debug.keystore`). That works as long as
all releases are built on this Mac. If you build on another machine or move to
a real release key, users must uninstall once before the store can update the
app. Moving all apps to one shared release keystore is the long-term fix.

## Limits

- Unauthenticated GitHub API calls are limited to 60 an hour per IP. The store
  caches the catalog for 15 minutes and falls back to the cached copy.
- The store reads public repos only.
