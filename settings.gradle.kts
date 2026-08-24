/*
 * SPDX-License-Identifier: MIT
 *
 * Copyright (c) 2026 Rubens Gomes
 *
 * This file may contain content generated or assisted by Artificial Intelligence
 * tools and subsequently reviewed and modified by human contributors.
 * See the LICENSE file for licensing terms and additional AI disclosures.
 */

// The project name shown by Gradle on the command line. This is ALSO the
// published Maven artifactId — build.gradle.kts reads `rootProject.name`
// when building the publication, so it is the single source of truth.
// Keep it matching the root folder name.
rootProject.name = "gradle-catalog"

// Repositories used to resolve Gradle plugins declared in `build.gradle.kts`.
// Plugin versions themselves come from the version catalog
// (`gradle/libs.versions.toml`) via `alias(libs.plugins.<name>)`.
pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
}
