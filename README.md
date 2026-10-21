# Chuff

A macOS menu bar light for [Railway](https://railway.com)'s platform status.
One dot next to the clock turns green, amber, or red, and the dropdown shows
which part of Railway is having trouble.

Chuff is built to be left alone. It makes one small request a
minute, stops while the display is asleep, and keeps nothing on disk except
your settings.

Requires **macOS 14 or later** on **Apple silicon**.

---

## Install

**Download the release.** Get `Chuff-1.0.0.zip` from
[Releases](https://github.com/mercuxio/Chuff/releases), unzip it, and
drag `Chuff.app` into `/Applications`.

The app is ad-hoc signed, not notarized, because I don't pay for an Apple
Developer account. macOS quarantines downloaded apps that aren't notarized, so
the first launch fails with "Chuff is damaged and can't be opened" or
"cannot be verified". The app isn't damaged. Clear the quarantine flag once:

```bash
xattr -dr com.apple.quarantine /Applications/Chuff.app
```

Then open it as usual. If you'd rather not run that on a stranger's app, which
is fair, you can build it yourself instead; see [Building](#building).

Chuff has no Dock icon and doesn't appear in the app switcher. Its
whole interface is the menu bar item, and you quit it from the dropdown.

---

## What it does

- **A status light.** The menu bar icon shows the worst status across the
  groups you track: green for operational, amber for a partial outage or
  maintenance, red for a major outage, and grey when it can't tell. An
  unrecognized status from Railway is shown as amber rather than green, so
  something unexpected never looks healthy.
- **A dropdown.** It lists Railway's component groups with their status.
  Expand a group to see the individual components inside it. The footer has
  Refresh now, a link to the full status page, Settings…, a link to buy me a
  coffee, and Quit.
- **Pick what you care about.** Every group is tracked by default, including
  any group Railway adds later. Untick the ones you don't use in the dropdown
  and they stop affecting the icon; Track all groups puts them back.
- **Grey means stale.** If the last good response is old, the icon turns grey
  instead of showing a colour that might be out of date. One missed refresh is
  tolerated; two and a half are not.
- **It updates itself.** Settings has a Check for Updates… button and an
  automatic-check toggle. Updates come from the GitHub release and are
  verified against a signature before anything is installed, so a tampered
  copy on a mirror can't be handed to you as an update.

There are no alerts and no notifications.

### Settings

- **Refresh every**: 1 (the default), 3, 5, or 10 minutes. Longer intervals use
  less data and battery.
- **Monochrome icons**: show the status as a symbol — tick, alert, cross —
  instead of a coloured dot.
- **Open at Login**, via `SMAppService`. If macOS is waiting for you to
  approve the login item, the setting says so and links to Login Items.
- **Check for updates automatically**, plus a button to check right now.

Settings are saved in the app's `UserDefaults`. Status data is never written to
disk.

## Where the status comes from

Chuff reads `https://api.railwaystatus.com/status`, the JSON feed
behind [status.railway.com](https://status.railway.com). It needs no API key and
no account, and it's unofficial: Railway publishes no contract for it and can
change it without notice. Decoding is deliberately lenient, so a new or missing
field doesn't break the app.

- One request at a time, about 3 KB over gzip, with no on-disk cache.
- Polling stops when the display or the machine sleeps, and resumes with an
  immediate refresh on wake.
- A failed request leaves the last good data in place and lets the icon go
  grey once it's stale. The next poll is the retry.

The icon reflects what that feed says, which can lag the real situation. For
incidents, trust the [status page](https://status.railway.com).

---

## Building

```bash
./build.sh
```

`build.sh` compiles a release build and assembles `Chuff.app` in the
repo folder. SwiftPM only produces a bare executable and has no idea what an
app bundle is, so the script builds the folder layout, `Info.plist`, icon,
embedded `Sparkle.framework`, and signature itself. The signature is ad-hoc:
good enough to run the app yourself, not good enough to distribute it.
Distribution would need a Developer ID and notarization.

```bash
./build.sh --install    # build, copy to /Applications, and launch
```

The build uses `--build-system native`, because Swift's default build system
fails to start on a machine with only the Command Line Tools.

## Layout

| Path | What lives there |
| --- | --- |
| `Sources/Chuff` | The menu bar app: the status store and polling, the dropdown, the settings window, and the updater. |
| `Resources/Info.plist` | Bundle metadata, including the Sparkle feed URL and public key. |
| `Tools/GenerateIcon.swift` | Writes the app icon as an Icon Composer bundle, `Resources/AppIcon.icon`. `./scripts/make-icon.sh` compiles it with Xcode's `actool` into the committed `Resources/Assets.car` and `AppIcon.icns`. |
| `appcast.xml` | The update feed installed copies read from the `main` branch. `./scripts/appcast.sh` adds a signed entry for the current version after a release is packaged. |

## Releasing

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in
   `Resources/Info.plist`, and add a section to [CHANGELOG.md](CHANGELOG.md).
2. `./build.sh`
3. `mkdir -p build && ditto -c -k --keepParent Chuff.app build/Chuff-<version>.zip`
4. `./scripts/appcast.sh`, which signs the zip with the EdDSA key in the login
   Keychain and adds an entry to `appcast.xml`.
5. Create the GitHub release `v<version>` with that zip attached, then commit
   and push `appcast.xml`.

The signature covers the zip, so step 4 has to run on the exact file you
upload.

## Status

Version 1.0.0. Chuff isn't affiliated with or endorsed by Railway.

## License

[MIT](LICENSE).
