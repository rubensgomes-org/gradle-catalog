/*
 * Copyright 2025 Rubens Gomes
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
