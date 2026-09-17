# Releasing

Ririku is distributed for free through GitHub Releases. It is signed ad hoc and not notarized, and the Chrome extension is installed with **Load unpacked** from the copy inside the app (see [decision D-013](../decisions.md)). Releases are currently prepared by hand; automating them with GitHub Actions is planned.

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

1. Make sure `main` is clean and the [verification commands](README.md#verification) pass. Run the manual smoke test on YouTube and YouTube Music.
2. Update the version and `CHANGELOG.md`, then commit.
3. Build and package:

   ```sh
   bash scripts/build-app.sh
   codesign --verify --deep --strict build/Ririku.app
   ditto -c -k --keepParent build/Ririku.app build/Ririku.zip
   shasum -a 256 build/Ririku.zip
   ```

   `ditto -c -k --keepParent` creates a zip that keeps the `Ririku.app` folder and its bundle contents intact.

4. Test the zip as a user would: download or copy it to another folder, unzip, move the app to Applications, open it (confirm the Gatekeeper steps in the user guide still match), and complete **Setup → Chrome connection** with a fresh Chrome profile if possible.
5. Tag the commit (`git tag v0.3.0 && git push origin v0.3.0`) and create a GitHub release for the tag.
6. In the release notes, include the changelog section, the SHA-256 checksum, the supported macOS version and architecture, a link to the [install steps](../user-guide.md#install), and a note that the app is not notarized and the extension must be reloaded after updating.
7. Attach `Ririku.zip`.

## Architecture support

Releases are built on Apple silicon and currently contain an `arm64` executable only. A universal (arm64 + x86_64) build with the Command Line Tools has not been validated; state the architecture in the release notes until it is.
