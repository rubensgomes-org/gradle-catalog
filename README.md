# gradle-catalog

This project implements a
[Gradle version catalog](https://docs.gradle.org/current/userguide/platforms.html)
defining plugins and libraries to be consumed by Java and Kotlin JVM (Java
Virtual Machine) Gradle software development projects.

The catalog is published as a Maven artifact (`com.rubensgomes:gradle-catalog`)
to
[GitHub Packages](https://github.com/rubensgomes-org/mvn-pkgs/packages) for
consumption by Gradle build projects.

## Requirements

- **JDK 25** (Temurin, matches CI)
- **Gradle 9.6.1** (via the included wrapper — no local install needed)

## Repository Layout

This repo contains **no application source code**. The single deliverable is the
TOML catalog; everything else exists to package and publish it.

| Path                                                             | Purpose                                                                                                |
|------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| [`gradle/libs.versions.toml`](gradle/libs.versions.toml)         | **The catalog** — `[versions]`, `[libraries]`, `[bundles]`, `[plugins]`. Almost all edits belong here. |
| [`build.gradle.kts`](build.gradle.kts)                           | Version-catalog packaging, Maven publishing, release wiring.                                           |
| [`gradle.properties`](gradle.properties)                         | Maven coordinates, POM metadata, release/Gradle flags.                                                 |
| [`settings.gradle.kts`](settings.gradle.kts)                     | Plugin management (plugin resolution repositories).                                                    |
| [`.github/workflows/release.yml`](.github/workflows/release.yml) | CI release workflow (push to `main` → tag → publish).                                                  |
| [`CLAUDE.md`](CLAUDE.md)                                         | Agent-facing conventions and guardrails.                                                               |
| [`PROJ_SETUP.md`](PROJ_SETUP.md)                                 | Checklist for bootstrapping a new GitHub/Gradle project like this one.                                 |
| [`llms.txt`](llms.txt)                                           | Machine-readable index of this repo's docs and sources.                                                |
| `.circleci/`                                                     | Legacy, no longer used (see `.circleci/NOT_USED.md`).                                                  |

## Branching Strategy

The project uses two branches:

1. **`main`** — Trunk-Based Development (TBD); tagged for new releases.
2. **`release`** — contains the most recently released code. Updated on every
   release by the `net.researchgate.release` plugin.

## CI/CD

CI/CD is defined in [
`.github/workflows/release.yml`](.github/workflows/release.yml). Every push to
`main` triggers the release workflow, which runs
`./gradlew release` and publishes the resulting artifact to GitHub Packages:

- Browse published packages:
  https://github.com/rubensgomes-org/mvn-pkgs/packages
- Maven repository endpoint (for build scripts, not browsers):
  `https://maven.pkg.github.com/rubensgomes-org/mvn-pkgs`

## What's in the Catalog

The authoritative list is always
[`gradle/libs.versions.toml`](gradle/libs.versions.toml). The summary below is a
map of what you get.

### Bundles

Bundles group libraries that are almost always applied together.

| Bundle                                | Contents                                                     |
|---------------------------------------|--------------------------------------------------------------|
| `libs.bundles.jakarta.bean.validator` | `jakarta-validation-api`, `expressly`, `hibernate-validator` |
| `libs.bundles.jjwt`                   | `jjwt-api`, `jjwt-impl`, `jjwt-jackson`                      |
| `libs.bundles.junit.jupiter`          | `junit-jupiter-api`, `junit-jupiter-engine`                  |
| `libs.bundles.kotlin.junit5`          | `mockk`, `kotlin-test-junit5`, `junit-jupiter-engine`        |
| `libs.bundles.logback`                | `logback-classic`, `logback-core`                            |

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

Entries known to be end-of-life (`oro`, `taglibs-*`) are marked with an inline
`# EOL` comment in the TOML and are kept only for legacy consumers.

The two `*-bom` entries are dependency BOMs — consume them with
`implementation(platform(libs.spring.boot.bom))`, not as plain dependencies.

> **Alias naming:** Gradle maps kebab-case TOML aliases to dotted
> accessors — `junit-platform-launcher` becomes
> `libs.junit.platform.launcher`, `kotlin-jvm` becomes
> `libs.plugins.kotlin.jvm`.

## Consuming This Catalog

The reference consumer is
[`spring-blueprint`](https://github.com/rubensgomes-org/spring-blueprint) — a
Gradle multi-project build (`settings.gradle.kts` at the root, an `app`
subproject holding the build script). The snippets below are taken from it.

### 1. Look up the latest published version

Browse the published versions on the GitHub Packages page:

- https://github.com/rubensgomes-org/mvn-pkgs/packages/2811984

Or check the latest git tag on the [
`release`](https://github.com/rubensgomes/gradle-catalog/tree/release)
branch.

### 2. Import the catalog in `settings.gradle.kts`

> **Important:** GitHub Packages requires authentication even for **reads**.
> Set `GITHUB_USER` and `GITHUB_TOKEN` (a PAT with the `read:packages` scope)
> in your environment before running Gradle.

```kotlin
rootProject.name = "spring-blueprint"
include("app")

pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
    // Do NOT pin plugin versions here. Plugins are applied in the subproject
    // via alias(libs.plugins.*), so the catalog is the single source of
    // truth. A version on the plugin request always wins over a
    // pluginManagement default anyway.
}

// The catalog is not available inside this block — settings plugins are
// resolved before dependencyResolutionManagement runs, so the foojay
// resolver is the one plugin that still carries a literal version.
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

@Suppress("UnstableApiUsage")
dependencyResolutionManagement {

    fun org.gradle.api.artifacts.dsl.RepositoryHandler.githubRepo(url: String?) {
        if (url.isNullOrBlank()) return

        val githubUser = System.getenv("GITHUB_USER")
        val githubToken = System.getenv("GITHUB_TOKEN")

        // A warning, not an error: once the catalog is in the Gradle module
        // cache the build resolves offline. It is the first build on a cold
        // cache that fails, with a 401 that never names the missing variables.
        if (githubUser.isNullOrBlank() || githubToken.isNullOrBlank()) {
            org.gradle.api.logging.Logging.getLogger("settings").warn(
                "GITHUB_USER and/or GITHUB_TOKEN are not set. Artifacts not " +
                        "already in the Gradle cache cannot be downloaded from $url.",
            )
        }

        maven {
            setUrl(url)
            credentials {
                username = githubUser
                password = githubToken
            }
        }
    }

    // https://maven.pkg.github.com/rubensgomes-org/mvn-pkgs, declared once in
    // the root gradle.properties rather than hard-coded here.
    val mavenRepoPackages =
        settings.extra.properties["mavenRepoPackages"] as? String

    repositories {
        mavenCentral()
        githubRepo(mavenRepoPackages)
    }

    versionCatalogs {
        create("libs") {
            from("com.rubensgomes:gradle-catalog:<release-version>")
        }
    }
}
```

If your project already has its own `gradle/libs.versions.toml`, delete it
before importing this catalog — a project cannot have both a local catalog file
and an imported catalog under the same name (`libs`).

### 3. Use the catalog in `build.gradle.kts`

In a multi-project build this is the **subproject** build script
(`app/build.gradle.kts`); the `libs` accessors created in
`settings.gradle.kts` are visible in every project.

```kotlin
plugins {
    // Core Gradle plugins are applied by id — they have no catalog entry.
    id("java")
    id("jacoco")
    id("maven-publish")

    // Third-party plugins come from the catalog, so no version appears here.
    alias(libs.plugins.release)
    alias(libs.plugins.sonarqube)
    alias(libs.plugins.spotless)
    alias(libs.plugins.spring.boot)
    alias(libs.plugins.task.tree)
}

dependencies {
    // BOM — imported as a platform, contributes managed versions only.
    // A platform() import applies ONLY to the configuration it is declared
    // on and to configurations that extend it, so import it once per
    // resolvable root. "compileOnly" and "testRuntimeOnly" need no import
    // (compileClasspath / testRuntimeClasspath extend them); the three below
    // do, because they extend nothing.
    implementation(platform(libs.spring.boot.bom))
    testImplementation(platform(libs.spring.boot.bom))
    annotationProcessor(platform(libs.spring.boot.bom))
    testAnnotationProcessor(platform(libs.spring.boot.bom))
    developmentOnly(platform(libs.spring.boot.bom))

    // Versionless coordinates, resolved by the BOM above.
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Single library from the catalog
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

> **`spring-dependency-management` is optional — and usually unwanted.**
> The catalog still carries `libs.plugins.spring.dependency.management` for
> legacy builds, but `implementation(platform(libs.spring.boot.bom))` is the
> native Gradle mechanism and is what `spring-blueprint` uses. Applying both
> imports the same BOM twice and duplicates the `<dependencyManagement>`
> entries in the generated POM.

## Adding or Updating a Catalog Entry

All catalog changes are edits to
[`gradle/libs.versions.toml`](gradle/libs.versions.toml) — no other file needs
to change.

1. **Bump a version** — edit the value under `[versions]`. Entries shared by
   several modules (e.g. `jackson`, `junit`, `kotlin`) move every library
   referencing them, so check the `[libraries]` block first.
2. **Add a library** — add a `[versions]` entry, then a `[libraries]`
   entry using `version.ref` (never an inline literal version, so the version
   stays in one place).
3. **Add a plugin** — same pattern under `[plugins]`, keyed by plugin id.
4. **Add a bundle** — list existing library aliases under `[bundles]`.
5. Keep every table alphabetically sorted, and verify with:

   ```bash
   ./gradlew clean build
   ```

Watch for **major** upgrades that change a module's group or artifact id (a new
major of a library often relocates its coordinates) — the
`version.ref` bump alone is not enough in that case; the `module` string has to
be updated too.

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

`publish` (and `release`) require `GITHUB_USER` and `GITHUB_TOKEN` (a PAT with
`write:packages`) to be set in the environment.

## Releasing

The `net.researchgate.release` plugin automates the release lifecycle (strip
`-SNAPSHOT` → tag → publish → bump to next `-SNAPSHOT`). Releases are normally
driven by CI on every push to `main`:

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
Java/Kotlin Gradle project on GitHub with the same publishing and release setup
used here.

---
Author: [Rubens Gomes](https://rubensgomes.com/)
