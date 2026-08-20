# CLAUDE.md

Agent-facing notes for working on this repo. For user-facing setup, usage,
and release commands, see [README.md](README.md).

## What this repo is

A Gradle version catalog packaged as a Maven artifact
(`com.rubensgomes:gradle-catalog`) — no application source code, only build
configuration. The single deliverable is `gradle/libs.versions.toml`.

## File layout

- `gradle/libs.versions.toml` — **the catalog** (versions, libraries,
  plugins, bundles). Almost all edits belong here.
- `build.gradle.kts` — publishing + release wiring.
- `gradle.properties` — Maven POM metadata + coordinates + release plugin flags.
- `settings.gradle.kts` — plugin management.
- `.github/workflows/release.yml` — CI release workflow (push to `main` → release).
- `.circleci/config.yml` — legacy, no longer used (see `.circleci/NOT_USED.md`).

### Docs

- `README.md` — user-facing: requirements, repo layout, catalog contents,
  consumer setup, how to add/bump an entry, local build, releasing.
- `PROJ_SETUP.md` — checklist for bootstrapping a *new* project like this
  one (prereqs, `gradle init`, `gh repo create`, `release` branch, PAT
  secret). Not needed for day-to-day work here.
- `llms.txt` — machine-readable index of the docs and sources above.

When the catalog's structure changes (a new bundle, a new plugin, a
renamed alias), update the "What's in the Catalog" section of `README.md`
in the same change. Routine version bumps do not need a README edit —
README deliberately lists no version numbers.

## Conventions & guardrails

- **Do not manually edit `version` in `gradle.properties`.** The
  `net.researchgate.release` plugin owns it (strip `-SNAPSHOT` → tag →
  publish → bump). Manual edits will collide with the release commit.
- **Do not commit to the `release` branch.** It is written to only by the
  release plugin.
- **`version` must always end in `-SNAPSHOT` on `main`.** The release plugin
  will not merge to the `release` branch otherwise (upstream bug — see the
  comment in `gradle.properties`).
- **When bumping dependency or plugin versions, edit only
  `gradle/libs.versions.toml`.** Do not add new metadata elsewhere.
- **Every `[libraries]`/`[plugins]` entry uses `version.ref`** — never an
  inline literal version — so a version lives in exactly one place. Keep
  each TOML table alphabetically sorted.
- **A major-version bump can move the module coordinates.** When a
  `version.ref` crosses a major boundary, verify the `module` group and
  artifact id are still correct rather than bumping the number alone.
- **Entries marked `# EOL`** (`oro`, `taglibs-*`) are dead upstream and
  kept only for legacy consumers. Do not try to "fix" them.
- **Publishing requires `GITHUB_USER` and `GITHUB_TOKEN` env vars** (PAT
  with `write:packages`). The release CI job supplies these from repo
  secrets; local runs need them set manually.

## Common commands

See README.md ("Local Development" and "Releasing" sections) for the
authoritative command list.
