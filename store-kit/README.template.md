# {Name}

{tagline}

**[Website](https://{id}.itsash.in)** · **[Download APK](https://github.com/its-ash/{repo}/releases/latest/download/{id}.apk)** · Get it in **[Ash Store](https://store.itsash.in)**

## Features

- {feature}

## Install

- **Ash Store**: install [Ash Store](https://store.itsash.in) once, then install and update {Name} from it.
- **APK**: download the [latest APK](https://github.com/its-ash/{repo}/releases/latest/download/{id}.apk) on your phone and open it. Allow your browser to install unknown apps if Android asks.

Requires Android {min Android version}.

## Develop

Needs Flutter ≥ 3.44 and the shared theme package at `../theme`.

```bash
make run      # run on a connected device
make build    # release APK
make deploy   # bump version, build, tag, push, GitHub release (see store.mk)
```

## Release

`make deploy` follows the Ash Store kit (`store.mk`, `store.json`): it bumps the
version in `pubspec.yaml`, builds, commits, tags `vX.Y.Z`, pushes, and publishes
a GitHub release with `{id}.apk`. Ash Store and the website pick up the new
version from that release.

## Project layout

```
{tree}
```

## License

{license}

Built by [itsash.in](https://itsash.in).
