# Third-Party Licenses

This image bundles and builds on the following components. The `LICENSE` file
(MIT) covers only this repo's own work (Dockerfile, CI, Taskfile, scripts).
The CI-generated CycloneDX SBOM (`sbom.cdx.json`) is the authoritative,
machine-readable inventory of *every* package with its exact version + license.

## PostgreSQL — The PostgreSQL License
Copyright (c) 1996–2026, PostgreSQL Global Development Group
Portions Copyright (c) 1994, The Regents of the University of California.
A permissive (BSD/MIT-style) license. Full text:
https://www.postgresql.org/about/licence/

## docker-entrypoint.sh — MIT (vendored)
Copyright (c) 2014 Docker, Inc.
Source: https://github.com/docker-library/postgres
Pinned commit: 32485831e2be041e8a36cf325751ad29c88f8c60
The full MIT text is reproduced in this repo's `LICENSE` (identical terms).

## gosu — Apache License 2.0
Copyright Tianon Gravi <tianon@debian.org>
https://github.com/tianon/gosu/blob/master/LICENSE

## Wolfi / wolfi-base — Apache License 2.0 (build definitions)
https://github.com/wolfi-dev/os/blob/main/LICENSE
Individual apk packages installed at build time carry their own upstream
licenses; see the SBOM for the complete per-package list.
