# Create GitHub Project

Personal checklist for creating a new Java/Kotlin Gradle project and
publishing it to GitHub. Steps are ordered so each phase produces
something the next phase consumes.

## 1. Install prerequisites

### Java + Gradle (cross-platform, via SDKMAN)

```shell
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java          # latest LTS by default
sdk install gradle        # only needed for `gradle init` below
```

SDKMAN works on macOS, Linux, and WSL — no symlink fiddling. If you
prefer Homebrew (macOS-only):

```shell
brew install openjdk gradle
sudo ln -sfn "$(brew --prefix openjdk)/libexec/openjdk.jdk" \
             /Library/Java/JavaVirtualMachines/openjdk.jdk
```

### GitHub access

- [Generate an SSH key and add it to ssh-agent](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
- [Install the GitHub CLI](https://github.com/cli/cli)
- [Create a Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
  with `repo`, `read:packages`, and `write:packages` scopes. It must be a
  **classic** token — fine-grained tokens cannot authenticate to the
  GitHub Packages Maven registry, and fail with `401 Unauthorized` on
  upload no matter how their permissions are set.

## 2. Create the local Gradle project

```shell
PROJ_NAME="<add-proj-name>"  # e.g., gradle-catalog
mkdir "$PROJ_NAME" && cd "$PROJ_NAME"
gradle init                  # follow the interactive prompts
```

See [Initializing the Project](https://docs.gradle.org/current/userguide/part1_gradle_init.html)
for guidance on the `gradle init` options.

Once the wrapper (`gradlew`) is generated, use `./gradlew` from here on
and (optionally) remove system Gradle.

## 3. Publish to GitHub

```shell
git init -b main
git add .
git commit -m "initial commit"
gh repo create --homepage "https://github.com/rubensgomes" --public "$PROJ_NAME"
git remote add origin "https://github.com/rubensgomes/$PROJ_NAME"
git push -u origin main
```

## 4. Post-creation

### Create the `release` branch

If the project will use the `net.researchgate.release` plugin, create
the `release` branch that the plugin pushes to:

```shell
git checkout -b release
git push -u origin release
git checkout main
```

### Add the PAT to this repo's Actions secrets

If the project's CI publishes to GitHub Packages, the PAT created in step 1
must **also be added to this repository**, as the `RUBENS_PAT_TOKEN` Actions
secret read by `.github/workflows/release.yml`:

```shell
# Prompts for the value — keeps the token out of shell history.
gh secret set RUBENS_PAT_TOKEN --repo "rubensgomes/$PROJ_NAME"
```

**The two are separate copies of the same token.** Creating (or later
rotating) the PAT under
*GitHub profile → Settings → Developer settings → Personal access tokens*
does nothing to the value stored in this repo, and the repo secret cannot
read your profile. Every project that publishes packages needs its own
copy configured under
*repo → Settings → Secrets and variables → Actions*.

**So: every time the PAT is regenerated, re-run the command above for each
project that uses it.** Otherwise the workflow keeps sending the old,
now-revoked token. The symptom is a release that builds fine and then
fails at the very end:

```
> Failed to publish publication 'maven' to repository 'GitHubPackages'
   > Could not PUT '.../gradle-catalog-<version>.toml'.
     Received status code 401 from server: Unauthorized
```

Nothing needs cleaning up after that failure — the release plugin runs
`publish` *before* it commits or tags, so a 401 there leaves no stray tag
and no non-SNAPSHOT version. Update the secret and re-run.

Why a PAT rather than the automatic `secrets.GITHUB_TOKEN`: the artifacts
are published to a **different** repository's registry
(`rubensgomes/jvm-libs`, see `jvmLibsRepoPackages` in `gradle.properties`),
and the auto-provisioned token is scoped only to the repo running the
workflow. The PAT therefore also needs access to that packages repo — not
just to this one.

To check when a repo's secret was last set (values are never displayed):

```shell
gh secret list --repo "rubensgomes/$PROJ_NAME"
```

---
Author: [Rubens Gomes](https://rubensgomes.com/)
