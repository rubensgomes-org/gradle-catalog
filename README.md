# gradle-catalog

This project implements a
[Gradle version catalog](https://docs.gradle.org/current/userguide/platforms.html)
defining plugins and libraries to be consumed by Java and Kotlin JVM (Java
Virtual Machine) Gradle software development projects.

The catalog is published as a Maven artifact
(`com.rubensgomes:gradle-catalog`) to
[GitHub Packages](https://github.com/rubensgomes-org/mvn-pkgs/packages) for
consumption by Gradle build projects.

## Requirements

- **JDK 25** (Temurin, matches CI)
- **Gradle 9.6.1** (via the included wrapper — no local install needed)

## Repository Layout

This repo contains **no application source code**. The single deliverable
is the TOML catalog; everything else exists to package and publish it.

| Path | Purpose |
| ---- | ------- |
| [`gradle/libs.versions.toml`](gradle/libs.versions.toml) | **The catalog** — `[versions]`, `[libraries]`, `[bundles]`, `[plugins]`. Almost all edits belong here. |
| [`build.gradle.kts`](build.gradle.kts) | Version-catalog packaging, Maven publishing, release wiring. |
| [`gradle.properties`](gradle.properties) | Maven coordinates, POM metadata, release/Gradle flags. |
| [`settings.gradle.kts`](settings.gradle.kts) | Plugin management (plugin resolution repositories). |
| [`.github/workflows/release.yml`](.github/workflows/release.yml) | CI release workflow (push to `main` → tag → publish). |
| [`CLAUDE.md`](CLAUDE.md) | Agent-facing conventions and guardrails. |
| [`PROJ_SETUP.md`](PROJ_SETUP.md) | Checklist for bootstrapping a new GitHub/Gradle project like this one. |
| [`llms.txt`](llms.txt) | Machine-readable index of this repo's docs and sources. |
| `.circleci/` | Legacy, no longer used (see `.circleci/NOT_USED.md`). |

## Branching Strategy

The project uses two branches:

1. **`main`** — Trunk-Based Development (TBD); tagged for new releases.
2. **`release`** — contains the most recently released code. Updated on
   every release by the `net.researchgate.release` plugin.

## CI/CD

CI/CD is defined in [`.github/workflows/release.yml`](.github/workflows/release.yml).
Every push to `main` triggers the release workflow, which runs
`./gradlew release` and publishes the resulting artifact to GitHub Packages:

- Browse published packages:
  https://github.com/rubensgomes-org/mvn-pkgs/packages
- Maven repository endpoint (for build scripts, not browsers):
  `https://maven.pkg.github.com/rubensgomes-org/mvn-pkgs`

## What's in the Catalog

The authoritative list is always
[`gradle/libs.versions.toml`](gradle/libs.versions.toml). The summary below
is a map of what you get.

### Bundles

Bundles group libraries that are almost always applied together.

| Bundle | Contents |
| ------ | -------- |
| `libs.bundles.jakarta.bean.validator` | `jakarta-validation-api`, `expressly`, `hibernate-validator` |
| `libs.bundles.jjwt` | `jjwt-api`, `jjwt-impl`, `jjwt-jackson` |
| `libs.bundles.junit.jupiter` | `junit-jupiter-api`, `junit-jupiter-engine` |
| `libs.bundles.kotlin.junit5` | `mockk`, `kotlin-test-junit5`, `junit-jupiter-engine` |
| `libs.bundles.logback` | `logback-classic`, `logback-core` |

### Plugins

`foojay`, `jsonschema2pojo`, `kotlin-jvm`, `kotlin-spring`, `lombok`,
`release`, `sonarqube`, `spotless`, `spring-boot`,
`spring-dependency-management`, `task-tree`.

Apply them with `alias(libs.plugins.<name>)` — see the example below.

### Libraries

Roughly grouped:

- **Jakarta / validation** — `jakarta-annotation-api`,
  `jakarta-validation-api`, `hibernate-validator`, `expressly`
- **Spring** — `spring-boot-bom`, `spring-cloud-azure-bom`,
  `springdoc-openapi-starter-webmvc-ui`, `swagger-annotations`,
  `springmockk`
- **JSON / security** — `jackson-databind`, `jjwt-*`, `bcprov-jdk18on`,
  `jasypt-hibernate5`
- **Logging** — `slf4j-api`, `logback-core`, `logback-classic`,
  `kotlin-logging-jvm`, `logbackext-lib`
- **Testing** — `junit-jupiter-*`, `junit-platform-launcher`,
  `kotlin-test-junit5`, `mockk`
- **In-house (`com.rubensgomes`)** — `ms-base-lib`, `ms-ex-lib`,
  `ms-fwk-lib`, `ms-reqresp-lib`, `logbackext-lib`
- **Misc / legacy web** — `commons-configuration2`, `commons-validator`,
  `device-detector`, `displaytag`, `oro`, `taglibs-datetime`,
  `taglibs-string`

Entries known to be end-of-life (`oro`, `taglibs-*`) are marked with an
inline `# EOL` comment in the TOML and are kept only for legacy consumers.

The two `*-bom` entries are dependency BOMs — consume them with
`implementation(platform(libs.spring.boot.bom))`, not as plain
dependencies.

> **Alias naming:** Gradle maps kebab-case TOML aliases to dotted
> accessors — `junit-platform-launcher` becomes
> `libs.junit.platform.launcher`, `kotlin-jvm` becomes
> `libs.plugins.kotlin.jvm`.

## Consuming This Catalog

### 1. Look up the latest published version

Browse the published versions on the GitHub Packages page:

- https://github.com/rubensgomes-org/mvn-pkgs/packages/2811984

Or check the latest git tag on the [`release`](https://github.com/rubensgomes/gradle-catalog/tree/release)
branch.

### 2. Configure `settings.gradle.kts`

> **Important:** GitHub Packages requires authentication even for **reads**.
> Set `GITHUB_USER` and `GITHUB_TOKEN` (a PAT with the `read:packages` scope)
> in your environment before running Gradle.

```kotlin
dependencyResolutionManagement {
    versionCatalogs {
        create("libs") {
            from("com.rubensgomes:gradle-catalog:<release-version>")
        }
    }

    repositories {
        mavenCentral()

        maven {
            url = uri("https://maven.pkg.github.com/rubensgomes-org/mvn-pkgs")
            credentials {
                username = System.getenv("GITHUB_USER")
                password = System.getenv("GITHUB_TOKEN")
            }
        }
    }
}
```

If your project already has its own `gradle/libs.versions.toml`, delete it
before importing this catalog — a project cannot have both a local catalog
file and an imported catalog under the same name (`libs`).

### 3. Use the catalog in `build.gradle.kts`

```kotlin
plugins {
    // Examples of applying plugins defined in the version catalog.
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.spring.boot)
    alias(libs.plugins.spring.dependency.management)
}

dependencies {
    // BOM — imported as a platform, contributes versions only
    implementation(platform(libs.spring.boot.bom))

    // Single library
    implementation(libs.commons.configuration2)
    implementation(libs.jakarta.validation.api)

    // Bundle of related libraries
    implementation(libs.bundles.jakarta.bean.validator)

    // Test bundle
    testImplementation(libs.bundles.kotlin.junit5)

    // Single library on the test runtime classpath
    testRuntimeOnly(libs.junit.platform.launcher)
}
```

## Adding or Updating a Catalog Entry

All catalog changes are edits to
[`gradle/libs.versions.toml`](gradle/libs.versions.toml) — no other file
needs to change.

1. **Bump a version** — edit the value under `[versions]`. Entries shared
   by several modules (e.g. `jackson`, `junit`, `kotlin`) move every
   library referencing them, so check the `[libraries]` block first.
2. **Add a library** — add a `[versions]` entry, then a `[libraries]`
   entry using `version.ref` (never an inline literal version, so the
   version stays in one place).
3. **Add a plugin** — same pattern under `[plugins]`, keyed by plugin id.
4. **Add a bundle** — list existing library aliases under `[bundles]`.
5. Keep every table alphabetically sorted, and verify with:

   ```bash
   ./gradlew clean build
   ```

Watch for **major** upgrades that change a module's group or artifact id
(a new major of a library often relocates its coordinates) — the
`version.ref` bump alone is not enough in that case; the `module` string
has to be updated too.

Then commit and push to `main`; CI releases and publishes a new version
automatically (see [CI/CD](#cicd)).

## Local Development

```bash
./gradlew -q javaToolchains                                     # List installed JDKs
./gradlew wrapper --gradle-version=9.6.1 --distribution-type=bin # Update wrapper
./gradlew clean                                                 # Clean build outputs
./gradlew clean build                                           # Full local build
./gradlew clean publish                                         # Publish to GitHub Packages
```

`publish` (and `release`) require `GITHUB_USER` and `GITHUB_TOKEN` (a PAT
with `write:packages`) to be set in the environment.

## Releasing

The `net.researchgate.release` plugin automates the release lifecycle
(strip `-SNAPSHOT` → tag → publish → bump to next `-SNAPSHOT`). Releases
are normally driven by CI on every push to `main`:

```bash
git commit -am "updated gradle-catalog"
git push
```

To run the release manually from a machine with `GITHUB_USER` and
`GITHUB_TOKEN` (PAT with `write:packages`) set:

```bash
./gradlew --info release
```

> **Do not hand-edit `version` in `gradle.properties`** and do not commit
> to the `release` branch — both are owned by the release plugin. The
> version on `main` must always end in `-SNAPSHOT`.

## New Projects

[`PROJ_SETUP.md`](PROJ_SETUP.md) is the checklist for bootstrapping a new
Java/Kotlin Gradle project on GitHub with the same publishing and release
setup used here.

---
Author: [Rubens Gomes](https://rubensgomes.com/)
