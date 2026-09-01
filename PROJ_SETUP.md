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
# GITIGNORE Templates: (see https://github.com/github/gitignore)
# Gradle
# Java
# Kotlin
# Maven
# Python
# Terraform
GITIGNORE="<>" 
DESCRIPTION="<some description>"
ORG="<some organization>" # e.g., rubensgomes-org, 3cloud-sandbox
PROJ_NAME="<add-proj-name>"  # e.g., gradle-catalog
URL="https://github.com/${ORG}" # e.g., https://github.com/rubensgomes-org

git init -b main
git add .
git commit -m "initial commit"

# create a remote GitHub repository
gh repo create "${ORG}/${PROJ_NAME}" \
  --description "${DESCRIPTION}" \
  --gitignore "${GITIGNORE}" \
  --homepage "${REPO_URL}" \
  --license "MIT" \
  --private

# add tags to the project
gh repo edit "${ORG}/${PROJ_NAME}" \
  --add-topic personal \
  --add-topic rubens-gomes \
  --add-topic azure \
  --add-topic github-actions \
  --add-topic terraform 

git remote add origin "${URL}/$PROJ_NAME"
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

### Actions secrets — nothing to do per repo

The Actions secrets this CI needs are configured **once, at the
`rubensgomes-org` organization level**, and shared with all public repos in
the org. A newly created public repo inherits them automatically; there is
no `gh secret set` step to run.

The one this project's CI uses is `RUBENS_PAT_TOKEN`, read by
`.github/workflows/release.yml` to publish to GitHub Packages.

Confirm what a given repo can see:

```shell
gh api "repos/rubensgomes-org/$PROJ_NAME/actions/organization-secrets" \
  --jq '.secrets[] | "\(.name)  updated=\(.updated_at)"'
```

If that comes back empty for a repo you expect to be covered, the repo is
probably private — the org secrets are shared with *public* repos, so a
private repo has to be added to the secret's repository access list
explicitly.

**Rotating the PAT is now a single update**, under
*org → Settings → Secrets and variables → Actions → `RUBENS_PAT_TOKEN`*
(or `gh secret set RUBENS_PAT_TOKEN --org rubensgomes-org --visibility all`).
Every project picks up the new value on its next run. Note that this is
still a *copy* of the token: regenerating the PAT under *GitHub profile →
Settings → Developer settings → Personal access tokens* does not update the
org secret, so the two can still drift out of sync — there is just one
place to fix now instead of one per repo.

A stale value surfaces as a release that builds fine and then fails at the
very end:

```
> Failed to publish publication 'maven' to repository 'GitHubPackages'
   > Could not PUT '.../gradle-catalog-<version>.toml'.
     Received status code 401 from server: Unauthorized
```

Nothing needs cleaning up after that failure — the release plugin runs
`publish` *before* it commits or tags, so a 401 there leaves no stray tag
and no non-SNAPSHOT version. Update the org secret and re-run.

Why a PAT rather than the automatic `secrets.GITHUB_TOKEN`: the artifacts
are published to a **different** repository's registry
(`rubensgomes-org/mvn-pkgs`, see `mavenRepoPackages` in `gradle.properties`),
and the auto-provisioned token is scoped only to the repo running the
workflow. The PAT therefore also needs access to that packages repo — not
just to this one. Note also that a secret cannot be *named* `GITHUB_TOKEN`:
GitHub reserves the `GITHUB_` prefix and rejects the name, which is why the
PAT is carried under `RUBENS_PAT_TOKEN` and only mapped onto the
`GITHUB_TOKEN` *environment variable* inside the release step.

---
Author: [Rubens Gomes](https://rubensgomes.com/)
