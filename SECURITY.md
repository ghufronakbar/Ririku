# Security policy

## Supported versions

Ririku is an early prototype. Only the latest release (or the `main` branch before the first release) receives security fixes.

## Reporting a vulnerability

Please do **not** open a public issue for security problems.

Report privately through GitHub: open the repository's **Security** tab and choose **Report a vulnerability** (GitHub private vulnerability reporting). Include:

- the affected version or commit;
- what an attacker could do and under which conditions;
- steps or a proof of concept to reproduce it;
- any suggested fix.

The maintainer aims to acknowledge reports within 7 days. Please allow time for a fix before disclosing the issue publicly. Ririku is maintained in spare time and has no bug bounty.

## Scope

Areas where reports are especially helpful:

- the local bridge: native messaging host, Unix socket, message validation, and the native host manifest written by Setup;
- the Chrome extension: message handling between the page, content scripts, service worker, and popup;
- handling of untrusted page data (titles, captions, artwork URLs) and LRCLIB responses;
- network requests, redirects, and file writes performed by the app.

Out of scope: issues that require an attacker to already control your macOS user account, and the fact that the app is not notarized or that the extension is installed with Load unpacked (known distribution choices; see the [decision log](docs/decisions.md)). The [architecture document](docs/development/architecture.md#security-and-privacy-boundaries) describes the current security boundaries.
