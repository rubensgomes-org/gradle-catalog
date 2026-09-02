# Create GitHub Project

Personal checklist for creating a new Java/Kotlin Gradle project and
publishing it to GitHub. Steps are ordered so each phase produces
something the next phase consumes.

## 1. Install prerequisites

`projsetup.sh` automates section 3, and it checks its own prerequisites
before doing anything. Everything below is one of those checks.

### Bash 4 or greater

The script uses associative arrays, a bash 4 feature. macOS ships bash
3.2 at `/bin/bash` and never updates it, so install a current bash and
keep it ahead of `/bin/bash` on `PATH`:

```shell
brew install bash          # macOS; Linux and WSL already ship bash 5
bash --version | head -1   # must report 4.x or later
```

The shebang is `#!/usr/bin/env bash`, so the script uses whichever bash
`PATH` finds first. Invoking it as `/bin/bash projsetup.sh` on macOS
fails with `ERROR: bash 4 or greater required`.

### Git and the GitHub CLI

Both must be on `PATH`; the script refuses to run without either.

```shell
brew install git gh
```

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

### Environment variables

`projsetup.sh` requires all eight of these to be defined and non-empty,
and stops with `ERROR: undefined environment variable(s): ...` naming any
that are missing. It never prints their values.

```shell
export GH_HOST="github.com"
export GH_TOKEN="<classic-pat>"
export GITHUB_TOKEN="${GH_TOKEN}"
export GITHUB_USER="<github-username>"
export GIT_AUTHOR_EMAIL="<you@example.com>"
export GIT_AUTHOR_NAME="<Your Name>"
export GIT_COMMITTER_EMAIL="${GIT_AUTHOR_EMAIL}"
export GIT_EDITOR="vi"
```

`GH_HOST` also determines the URLs the script builds: the repository
homepage becomes `https://${GH_HOST}/${ORG}` and the git remote becomes
`https://${GH_HOST}/${ORG}/${NAME}`.

Keep the two token lines in a file outside any repository and source it
from your shell profile, so a PAT is never committed.

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

`projsetup.sh` performs this entire phase. Run it from inside the project
directory created in section 2:

```shell
./projsetup.sh \
  --description "<some description>" \
  --gitignore Java \
  --name "<add-proj-name>" \
  --org "<some organization>" \
  --tags personal,rubens-gomes,azure
```

| Option | Argument | Notes |
| --- | --- | --- |
| `-d`, `--description` | `DESCRIPTION` | Project description |
| `-g`, `--gitignore` | `GITIGNORE` | Template name, see below |
| `-n`, `--name` | `NAME` | Project name, e.g. `gradle-catalog` |
| `-o`, `--org` | `ORG` | e.g. `rubensgomes-org`, `3cloud-sandbox` |
| `-t`, `--tags` | `TAGS` | Comma separated GitHub topics |
| `-v`, `--verbose` | — | Trace every step on stderr |
| `-h`, `--help` | — | Print the usage text and exit 0 |

Every option except `-v` and `-h` is required; omitting one lists what is
missing and prints the usage. `--tags` may also be repeated
(`-t personal -t azure`) and both forms accumulate.

Gitignore templates (see [github/gitignore](https://github.com/github/gitignore)):
`Gradle`, `Java`, `Kotlin`, `Maven`, `Python`, `Terraform`.

The script runs these steps in order, stops at the first failure with an
`ERROR:` line on stderr and a non-zero exit, and prints `Done.` on
success:

1. `git init -b main`, `git add .`, `git commit -m "initial commit" -a`
2. `gh repo create` — private, MIT licensed, homepage `https://${GH_HOST}/${ORG}`
3. `gh repo edit` — one `--add-topic` per entry in `--tags`
4. `git remote add origin`, `git fetch origin`, `git rebase origin/main`,
   `git push -u origin main` — the rebase is required because
   `--gitignore`/`--license` make GitHub initialize the repository with a
   commit of its own

Note that the repository is created **private**. See section 4 on why
that affects which Actions secrets it inherits.

### Fallback: the equivalent manual commands

Only if the script cannot run. These are what it executes; keep them in
sync with `projsetup.sh`, which is the source of truth.

```shell
GITIGNORE="<gitignore-template>"
DESCRIPTION="<some description>"
ORG="<some organization>"
PROJ_NAME="<add-proj-name>"
URL="https://github.com/${ORG}"

git init -b main
git add .
git commit -m "initial commit" -a

# create a remote GitHub repository
gh repo create "${ORG}/${PROJ_NAME}" \
  --description "${DESCRIPTION}" \
  --gitignore "${GITIGNORE}" \
  --homepage "${URL}" \
  --license "MIT" \
  --private

# add topics to the project
gh repo edit "${ORG}/${PROJ_NAME}" \
  --add-topic personal \
  --add-topic rubens-gomes \
  --add-topic azure

git remote add origin "${URL}/${PROJ_NAME}"

# --gitignore and --license leave an initial commit on the remote, so the
# local history is replayed on top of it before main is pushed
git fetch origin
git rebase origin/main
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
