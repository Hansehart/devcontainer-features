## Notes

This Feature installs `chrome-headless-shell` from the Chrome for Testing public
bucket, plus the shared libraries it loads at startup.

### Portability caveats

- **Debian/Ubuntu only** — the runtime libraries are installed with `apt-get`.
- **Ubuntu 24.04+ package names** — several deps use the `t64` (64-bit `time_t`)
  package names (e.g. `libasound2t64`), which exist on Ubuntu 24.04 "noble" and
  newer. On older Debian/Ubuntu the non-`t64` names would be required.
- **amd64 only** — it downloads the `linux64` build; there is no arm64 handling.
