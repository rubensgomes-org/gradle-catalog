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
- `LICENSE` — AI-generated-content notice + MIT License text. Authoritative
  source for every license statement in the repo.
- `DISCLAIMER.md` — reader-friendly copy of the LICENSE notices. Keep it in
  sync with `LICENSE`; `LICENSE` governs where they differ.
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
- **Read `gradle.properties` values with
  `providers.gradleProperty("<name>").get()`** in `build.gradle.kts`. The
  `val <name>: String by project` delegate syntax is deprecated and is
  removed in Gradle 10; every property read in this build was converted
  away from it. Do not reintroduce it.
- **The build must stay deprecation-free.** Check with
  `./gradlew clean build --warning-mode all` after touching
  `build.gradle.kts` or `settings.gradle.kts` — "Deprecated Gradle features
  were used in this build" is a regression, not noise.
- **Every `[libraries]`/`[plugins]` entry uses `version.ref`** — never an
  inline literal version — so a version lives in exactly one place. Keep
  each TOML table alphabetically sorted.
- **A major-version bump can move the module coordinates.** When a
  `version.ref` crosses a major boundary, verify the `module` group and
  artifact id are still correct rather than bumping the number alone.
- **Entries marked `# EOL`** (`oro`, `taglibs-*`) are dead upstream and
  kept only for legacy consumers. Do not try to "fix" them.
- **Publishing requires `GITHUB_USER` and `GITHUB_TOKEN` env vars** (PAT
  with `write:packages`). Local runs need them set manually. In CI,
  `GITHUB_USER` is a plain `env:` value in the workflow and `GITHUB_TOKEN`
  is mapped from `secrets.RUBENS_PAT_TOKEN`.
- **All Actions secrets are ORGANIZATION-level** (`rubensgomes-org`, shared
  with public repos) — this repo defines none of its own. Do not add a repo
  secret or a `gh secret set --repo` step; check what is visible with
  `gh api repos/rubensgomes-org/gradle-catalog/actions/organization-secrets`.
  A secret can never be named `GITHUB_TOKEN`: GitHub reserves the `GITHUB_`
  prefix, so the PAT travels as `RUBENS_PAT_TOKEN` and is renamed to the
  `GITHUB_TOKEN` env var inside the release step.
- **The project is MIT-licensed.** `LICENSE` is authoritative; the license
  name/URL shipped in the POM lives in `gradle.properties`
  (`license`/`licenseUrl`). `build.gradle.kts` and `settings.gradle.kts`
  carry an `SPDX-License-Identifier: MIT` header instead of a full license
  block. A license change must be applied to all of these plus
  `DISCLAIMER.md`, `README.md`, and `llms.txt` in the same commit.
- **`sonarqube` in `gradle/libs.versions.toml` is a catalog entry for
  consumers only.** Do not apply the plugin to this build: the repo has no
  sources, tests, or coverage for it to analyze.

## Common commands

See README.md ("Local Development" and "Releasing" sections) for the
authoritative command list.
