/*
 * Copyright 2026 Rubens Gomes
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// =====================================================================
// Gradle Version Catalog — build script
// =====================================================================
// This project has NO application source code. Its only deliverable is the
// version catalog defined in `gradle/libs.versions.toml`, which is packaged
// and published as a Maven artifact (com.rubensgomes:gradle-catalog:<version>)
// so downstream JVM projects can share pinned dependency/plugin versions.
//
// Common commands:
//   ./gradlew clean build     # Build the catalog artifact locally
//   ./gradlew clean publish   # Publish the artifact to GitHub Packages
//   ./gradlew release         # Run the full release workflow (main branch)
// =====================================================================

plugins {
    // Packages `gradle/libs.versions.toml` as a publishable Maven artifact
    // (produces the `versionCatalog` software component consumed below).
    id("version-catalog")
    // Enables the `publishing { ... }` DSL for pushing artifacts to a Maven repo.
    id("maven-publish")
    // Automates the release workflow: strip -SNAPSHOT, tag, publish, bump to
    // the next -SNAPSHOT. Configured in the `release { ... }` block below.
    // Version pinned via the version catalog (gradle/libs.versions.toml).
    alias(libs.plugins.release)
}

// ---------------------------------------------------------------------
// Project coordinates & metadata
// ---------------------------------------------------------------------
// All values below are declared in `gradle.properties` and injected here via
// Kotlin's `by project` property delegate. Keeping them out of the build script
// lets the release plugin rewrite `version` in `gradle.properties` without
// touching this file.
//
// NOTE: `group`, `version`, and `description` are deliberately NOT read here.
// Gradle applies any gradle.properties entry whose name matches a built-in
// `Project` property straight onto the project, so `project.group`,
// `project.version`, and `project.description` are already populated before
// this script runs — reading and re-assigning them would be a no-op. Only
// values with no `Project` equivalent need the delegate below.
val developerId: String by project
val developerName: String by project
val title: String by project

// ---------------------------------------------------------------------
// Gradle Version Catalog plugin
// ---------------------------------------------------------------------
// Tells the `version-catalog` plugin where to find the catalog definition.
// The TOML file becomes the payload of the published artifact — consumers
// import it via `from("com.rubensgomes:gradle-catalog:<version>")` in their
// own `dependencyResolutionManagement { versionCatalogs { ... } }` block.
// https://docs.gradle.org/current/userguide/version_catalogs.html
catalog {
    versionCatalog {
        from(files("gradle/libs.versions.toml"))
    }
}

// ---------------------------------------------------------------------
// Maven Publish plugin — publication + target repository
// ---------------------------------------------------------------------
// Defines WHAT gets published (the `maven` publication) and WHERE it goes
// (the `GitHubPackages` repository).
// https://docs.gradle.org/current/userguide/publishing_maven.html
publishing {

    publications {
        // Additional POM metadata pulled from `gradle.properties`. Declared
        // inside `publications` (rather than at the top of the file) because
        // these values are only needed while building the POM.
        val developerEmail: String by project

        val scmConnection: String by project
        val scmUrl: String by project

        val license: String by project
        val licenseUrl: String by project

        // A single Maven publication named "maven". The `version-catalog`
        // plugin contributes a `versionCatalog` software component whose
        // content is the TOML file — that's what actually ships.
        create<MavenPublication>("maven") {
            groupId = project.group.toString()
            // Single source of truth: `rootProject.name` (settings.gradle.kts).
            artifactId = rootProject.name
            version = project.version.toString()

            // Pull the catalog contents (libs.versions.toml) into this publication.
            from(components["versionCatalog"])

            // Generated `pom.xml` metadata — required by Maven Central-style
            // repositories and useful documentation for consumers.
            pom {
                name = title
                description = project.description
                inceptionYear = "2024"

                licenses {
                    license {
                        name = license
                        url = licenseUrl
                    }
                }
                developers {
                    developer {
                        id = developerId
                        name = developerName
                        email = developerEmail
                    }
                }
                scm {
                    connection = scmConnection
                    // Same value as `connection` — this repo does not distinguish
                    // read-only vs. developer (push) SCM URLs.
                    developerConnection = scmConnection
                    url = scmUrl
                }
            }

        }
    }

    repositories {
        // Target repository URL comes from `gradle.properties` (jvmLibsRepoPackages).
        val jvmLibsRepoPackages: String by project

        // GitHub Packages Maven registry. Credentials MUST be provided via
        // environment variables — the release workflow and local publishes
        // both rely on GITHUB_USER (username) and GITHUB_TOKEN (PAT with
        // `write:packages` scope). Missing env vars → publish fails at
        // upload time, not at configuration time.
        maven {
            name = "GitHubPackages"
            url = uri(jvmLibsRepoPackages)
            credentials {
                username = System.getenv("GITHUB_USER")
                password = System.getenv("GITHUB_TOKEN")
            }
        }
    }
}

// ---------------------------------------------------------------------
// Release plugin (net.researchgate.release)
// ---------------------------------------------------------------------
// Automates the SNAPSHOT → release → next-SNAPSHOT lifecycle. Running
// `./gradlew release` performs, in order:
//   1. Strip "-SNAPSHOT" from `gradle.properties` version.
//   2. Commit + tag the release version, push tag to the `release` branch.
//   3. Run `afterReleaseBuild` (wired to `publish` below) → uploads the
//      catalog artifact to GitHub Packages.
//   4. Bump `gradle.properties` to the next -SNAPSHOT and push to `main`.
// https://github.com/researchgate/gradle-release
release {
    with(git) {
        // Release commits/tags are pushed to a dedicated `release` branch so
        // `main` history stays free of the transient non-SNAPSHOT commit.
        pushReleaseVersionBranch.set("release")
        // Guard rail: releasing from a feature branch is almost always a
        // mistake, so the plugin refuses to run unless HEAD is `main`.
        requireBranch.set("main")
    }
}

// Hook publishing into the release flow. Without this, `./gradlew release`
// would tag and bump versions but never actually upload the artifact.
tasks.afterReleaseBuild {
    dependsOn("publish")
}

