# Releasing

Ririku is distributed for free through GitHub Releases. It is signed ad hoc and not notarized, and the Chrome extension is installed with **Load unpacked** from the copy inside the app (see [decision D-013](../decisions.md)). Releases are built by GitHub Actions from a tag and created as a draft for review.

## Versioning

Ririku uses [Semantic Versioning](https://semver.org). While the version is `0.x`, a minor bump (`0.3.0` → `0.4.0`) may include breaking changes such as new identifiers, and a patch bump is for fixes.

Update the version in all of these places:

| File | Value |
| --- | --- |
| `scripts/build-app.sh` | `CFBundleShortVersionString`, and increase `CFBundleVersion` by one |
| `extension/manifest.json` | `version` (keep it equal to the app version so Setup can detect outdated extensions) |
| `Sources/Ririku/MediaServices.swift` | `User-Agent` sent to LRCLIB |
| `Sources/Ririku/SetupView.swift` | Version text in the Prototype section |
| `CHANGELOG.md` | New section with the release date |
| `README*.md`, `docs/user-guide*.md` | Version mentioned in the status note and translation headers, if changed |

Do not change the bundle identifier, native host name, extension `key`, or socket and cache paths in a normal release. If it is unavoidable, explain the migration in the changelog.

## Checklist

1. Make sure `main` is clean, CI is green, and the [verification commands](README.md#verification) pass locally. Run the manual smoke test on YouTube and YouTube Music.
2. Update the version everywhere in the table above and add the `CHANGELOG.md` section with today's date, then commit.
3. Tag and push:

   ```sh
   git tag v0.3.0
   git push origin v0.3.0
   ```

   The release workflow checks that the tag matches the version in `scripts/build-app.sh`, runs the checks, builds and ad-hoc signs the bundle, packages `Ririku-<version>.zip` with `ditto -c -k --keepParent`, writes `SHA256SUMS.txt`, generates notes with `scripts/release-notes.py` (the changelog section plus install instructions), and creates a **draft** release with both files attached.

4. Download the zip from the draft and test it as a user would: unzip in another folder, move the app to Applications, open it (confirm the Gatekeeper steps in the user guide still match), and complete **Setup → Chrome connection**, ideally with a fresh Chrome profile.
5. Edit the notes if needed, then publish the release.

To rebuild an existing tag, run the **Release** workflow manually with the tag name. Packaging locally works too:

```sh
bash scripts/build-app.sh
ditto -c -k --keepParent build/Ririku.app build/Ririku.zip
shasum -a 256 build/Ririku.zip
```

## Architecture support

Releases are built on Apple silicon and currently contain an `arm64` executable only. A universal (arm64 + x86_64) build with the Command Line Tools has not been validated; state the architecture in the release notes until it is.
