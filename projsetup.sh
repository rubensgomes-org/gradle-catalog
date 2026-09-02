#!/usr/bin/env bash
######################################################################
# File: projsetup.sh
#
# Description:
#   A simple bash shell script to facilitate the creation of GitHub
#   repository projects.
#
# OS Platform: UNIX (e.g., macOS, Linux).
# Note:
#   GNU bash, version 4+ or greater required to support key-value maps
#
# Author: Rubens Gomes
#######################################################################

# exit immediately if any command exits with a non-zero status.
set -o errexit
# treat an expansion of an unset variable as an error.
set -o nounset
# a pipeline fails with the status of its last failing command, not its last.
set -o pipefail

# the oldest bash major version this script supports.
declare -ir BASH_MAJOR_VERSION=4

# the following tools must be installed.
declare -ar REQUIRED_TOOLS=(
  "git"
  "gh"
)

# the following environment variables must be defined.
declare -ar ENVIRONMENT_VARS=(
  "GH_HOST"
  "GH_TOKEN"
  "GIT_AUTHOR_EMAIL"
  "GIT_AUTHOR_NAME"
  "GIT_COMMITTER_EMAIL"
  "GIT_EDITOR"
  "GITHUB_TOKEN"
  "GITHUB_USER"
)

# variable to be set from CLI argument options
declare DESCRIPTION=""
declare GITIGNORE=""
declare NAME=""
declare ORG=""
declare -a TAGS=()
declare -i VERBOSE=0

#####################################################################
# Writes a diagnostic message, but only when the verbose flag was
# given on the command line.  Callers may invoke this freely: it is
# silent until check_options() has seen -v.
# Globals:
#   VERBOSE
# Arguments:
#   The message to write.
# Outputs:
#   Writes the message to stderr when VERBOSE is set, so that it
#   never contaminates the stdout of this script.  Writes nothing
#   otherwise.
# Returns:
#   0.
#####################################################################
function log_verbose() {
  if (( VERBOSE )); then
    printf 'INFO: %s
' "$*" >&2
  fi

  return 0
}

#####################################################################
# Checks that the running bash interpreter is at least
# BASH_MAJOR_VERSION. Key-value maps (associative arrays) require
# bash 4 or greater.
# Globals:
#   BASH_MAJOR_VERSION
# Arguments:
#   None.
# Outputs:
#   Writes the required and running versions to stderr when too old.
# Returns:
#   0 if the running major version is high enough, 1 otherwise.
#####################################################################
function check_bash_version() {
  local running_major_version="${BASH_VERSINFO[0]:-0}"

  if (( running_major_version < BASH_MAJOR_VERSION )); then
    printf 'ERROR: bash %d or greater required, but running bash %s\n' \
      "${BASH_MAJOR_VERSION}" "${BASH_VERSION:-unknown}" >&2
    return 1
  fi

  log_verbose "running bash ${BASH_VERSION:-unknown}"

  return 0
}

#####################################################################
# Checks that every tool in REQUIRED_TOOLS is installed and reachable
# in the user's PATH.
# Globals:
#   REQUIRED_TOOLS
# Arguments:
#   None.
# Outputs:
#   Writes the name of each missing tool to stderr.
# Returns:
#   0 if all tools were found, 1 otherwise.
#####################################################################
function check_tools() {
  local tool
  local tool_path
  local missing_tools=()

  for tool in "${REQUIRED_TOOLS[@]}"; do
    if tool_path="$(command -v "${tool}")"; then
      log_verbose "found required tool: ${tool} (${tool_path})"
    else
      missing_tools+=("${tool}")
    fi
  done

  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    printf 'ERROR: required tool(s) not found in PATH: %s\n' \
      "${missing_tools[*]}" >&2
    return 1
  fi

  return 0
}

#####################################################################
# Checks that every variable named in ENVIRONMENT_VARS is defined and
# non-empty in the shell running this script.
# Globals:
#   ENVIRONMENT_VARS
# Arguments:
#   None.
# Outputs:
#   Writes the name of each undefined variable to stderr. Values are
#   never printed: several of them hold access tokens.
# Returns:
#   0 if all variables were defined, 1 otherwise.
#####################################################################
function check_environment_vars() {
  local variable_name
  local undefined_vars=()

  for variable_name in "${ENVIRONMENT_VARS[@]}"; do
    if [[ -n ${!variable_name:-} ]]; then
      log_verbose "environment variable is defined: ${variable_name}"
    else
      undefined_vars+=("${variable_name}")
    fi
  done

  if [[ ${#undefined_vars[@]} -gt 0 ]]; then
    printf 'ERROR: undefined environment variable(s): %s\n' \
      "${undefined_vars[*]}" >&2
    return 1
  fi

  return 0
}

#####################################################################
# Checks that mandatory options as displayed in the usage()
# are passed in the CLI.  The corresponding variables (e.g.,
# DESCRIPTION, GITIGNORE, NAME, ORG) are set accordingly.
#
# The following options and arguments are expected:
#
#   -d, --description DESCRIPTION
#   -g, --gitignore GITIGNORE
#   -h, --help
#   -n, --name NAME
#   -o, --org ORG
#   -t, --tags TAGS
#   -v, --verbose
#
# TAGS holds the GitHub topics for the repository.  Its value is a
# comma separated list, and the option may be repeated; every
# occurrence appends to the array and empty entries are dropped.
#
# Globals:
#   DESCRIPTION, GITIGNORE, NAME, ORG, TAGS, VERBOSE - all set from
#   the parsed options.
# Arguments:
#   The command line options and their values, that is, "$@".
# Outputs:
#   Writes the name of any unknown, valueless or missing option to
#   stderr, followed by the usage().
# Returns:
#   0 if all required options are defined, 1 otherwise.  Exits the
#   script with 0 as soon as -h or --help is seen.
#####################################################################
function parse_options() {
  local -Ar option_variables=(
    ["-d"]="DESCRIPTION"
    ["--description"]="DESCRIPTION"
    ["-g"]="GITIGNORE"
    ["--gitignore"]="GITIGNORE"
    ["-n"]="NAME"
    ["--name"]="NAME"
    ["-o"]="ORG"
    ["--org"]="ORG"
    ["-t"]="TAGS"
    ["--tags"]="TAGS"
  )
  local option
  local tag
  local tag_values=()
  local variable_name
  local missing_options=()

  while [[ $# -gt 0 ]]; do
    option="$1"

    case "${option}" in
      -h | --help)
        usage
        exit 0
        ;;
      -v | --verbose)
        VERBOSE=1
        log_verbose "verbose logging enabled"
        shift
        continue
        ;;
      *)
        # every remaining option carries a value, and is resolved
        # through option_variables below.
        ;;
    esac

    variable_name="${option_variables[${option}]:-}"

    if [[ -z ${variable_name} ]]; then
      printf 'ERROR: unknown option: %s\n' "${option}" >&2
      usage >&2
      return 1
    fi

    # a value starting with a hyphen is the next option, not this value.
    if [[ -z ${2:-} || ${2} == -* ]]; then
      printf 'ERROR: missing value for option: %s\n' "${option}" >&2
      usage >&2
      return 1
    fi

    if [[ ${variable_name} == "TAGS" ]]; then
      IFS="," read -r -a tag_values <<< "$2"
      for tag in "${tag_values[@]}"; do
        if [[ -n ${tag} ]]; then
          TAGS+=("${tag}")
        fi
      done
    else
      printf -v "${variable_name}" '%s' "$2"
    fi

    shift 2
  done

  [[ -n ${DESCRIPTION} ]] || missing_options+=("-d, --description")
  [[ -n ${GITIGNORE} ]] || missing_options+=("-g, --gitignore")
  [[ -n ${NAME} ]] || missing_options+=("-n, --name")
  [[ -n ${ORG} ]] || missing_options+=("-o, --org")
  [[ ${#TAGS[@]} -gt 0 ]] || missing_options+=("-t, --tags")

  if [[ ${#missing_options[@]} -gt 0 ]]; then
    printf 'ERROR: missing required option(s): %s\n' "${missing_options[*]}" >&2
    usage >&2
    return 1
  fi

  log_verbose "project name: ${NAME}"
  log_verbose "organization: ${ORG}"
  log_verbose "description: ${DESCRIPTION}"
  log_verbose "gitignore template: ${GITIGNORE}"
  log_verbose "tags: ${TAGS[*]}"

  return 0
}

#####################################################################
# Prints how to invoke this script, listing every supported option
# and the argument it takes.
# Globals:
#   None.
# Arguments:
#   None.
# Outputs:
#   Writes the usage text to stdout.  A caller reporting a CLI error
#   is responsible for redirecting it to stderr.
# Returns:
#   0.  The caller decides the exit status, so that --help can
#   succeed while a malformed command line fails.
#####################################################################
function usage() {
  cat << EOF
Usage: $(basename "$0") OPTIONS

Options:
    -d, --description DESCRIPTION   Project description
    -g, --gitignore GITIGNORE       Gitignore template
    -h, --help                      Print this usage text
    -n, --name NAME                 Project name
    -o, --org ORG                   GitHub organization
    -t, --tags TAGS                 Comma separated GitHub topics
    -v, --verbose                   Print progress logs to stderr

EOF

  return 0
}

#####################################################################
# Creates the project: initializes a local git repository, commits
# the working tree, creates the matching private GitHub repository,
# adds every topic held in TAGS, rebases the local history onto the
# commit GitHub created, then pushes branch main to it.
#
# Each step is checked, and the first failure ends the function so
# that no later step runs against a half created project.
# Globals:
#   DESCRIPTION, GH_HOST, GITIGNORE, NAME, ORG, TAGS - all read, and
#   all set beforehand by check_options() and check_environment_vars().
# Arguments:
#   None.
# Outputs:
#   Writes the step that failed to stderr, and writes progress to
#   stderr through log_verbose(). The git and gh commands write their
#   own output.
# Returns:
#   0 if the project was created, 1 as soon as any step fails.
#####################################################################
function create_proj() {
  # GH_HOST is supplied by the environment, and its presence is
  # already guaranteed by check_environment_vars().
  # shellcheck disable=SC2154
  local url="https://${GH_HOST}/${ORG}"
  local -a topic_options=()
  local tag

  log_verbose "initializing a local git repository on branch main"
  if ! git init -b main; then
    printf 'ERROR: failed to initialize a git repository in: %s\n' "${PWD}" >&2
    return 1
  fi

  log_verbose "staging the working tree"
  if ! git add .; then
    printf 'ERROR: failed to stage the working tree\n' >&2
    return 1
  fi

  log_verbose "committing the initial revision"
  if ! git commit -m "initial commit" -a; then
    printf 'ERROR: failed to commit the initial revision\n' >&2
    return 1
  fi

  log_verbose "creating private GitHub repository: ${ORG}/${NAME}"
  if ! gh repo create "${ORG}/${NAME}" \
      --description "${DESCRIPTION}" \
      --gitignore "${GITIGNORE}" \
      --homepage "${url}" \
      --license "MIT" \
      --private; then
    printf 'ERROR: failed to create GitHub repository: %s/%s\n' \
      "${ORG}" "${NAME}" >&2
    return 1
  fi

  # gh takes one --add-topic per topic, so TAGS becomes a pair of
  # arguments each, expanded as a single option list below.
  for tag in "${TAGS[@]}"; do
    topic_options+=("--add-topic" "${tag}")
  done

  log_verbose "adding ${#TAGS[@]} topic(s) to ${ORG}/${NAME}: ${TAGS[*]}"
  if ! gh repo edit "${ORG}/${NAME}" "${topic_options[@]}"; then
    printf 'ERROR: failed to add topic(s) to GitHub repository: %s/%s\n' \
      "${ORG}" "${NAME}" >&2
    return 1
  fi

  log_verbose "adding remote origin: ${url}/${NAME}"
  if ! git remote add origin "${url}/${NAME}"; then
    printf 'ERROR: failed to add the origin remote: %s/%s\n' \
      "${url}" "${NAME}" >&2
    return 1
  fi

  # --gitignore and --license make GitHub initialize the repository with
  # a commit of its own, so the local history has to be replayed on top
  # of it before main can be pushed.
  log_verbose "fetching the remote initial commit"
  if ! git fetch origin; then
    printf 'ERROR: failed to fetch from the origin remote: %s/%s\n' \
      "${url}" "${NAME}" >&2
    return 1
  fi

  log_verbose "rebasing branch main onto origin/main"
  if ! git rebase origin/main; then
    printf 'ERROR: failed to rebase branch main onto: origin/main\n' >&2
    return 1
  fi

  log_verbose "pushing branch main to origin"
  if ! git push -u origin main; then
    printf 'ERROR: failed to push branch main to: %s/%s\n' \
      "${url}" "${NAME}" >&2
    return 1
  fi

  log_verbose "successfully created project: ${ORG}/${NAME}"
  return 0
}

#####################################################################
# Runs the project setup: verifies the running interpreter, parses
# the command line, verifies the tools and the environment this
# script depends on, then creates the project.
#
# The steps run in the order below and stop at the first failure, so
# that nothing is created until every precondition has been met.
# Globals:
#   NAME, ORG - read only to report the project that was created.
#   The called functions read and write the remaining globals.
# Arguments:
#   The command line options and their values, that is, "$@".
# Outputs:
#   Writes the step that failed to stderr, and writes progress to
#   stderr through log_verbose(). Each called function writes its own
#   diagnostic first, so the message here names the step that failed.
# Returns:
#   0 if the project was created, 1 as soon as any step fails.
#####################################################################
function main() {
  # checked before anything else: parse_options() declares an
  # associative array, and reporting that bash 4 requirement is
  # exactly what this guard is for.
  if ! check_bash_version; then
    printf 'ERROR: unsupported bash interpreter
' >&2
    return 1
  fi

  if ! parse_options "$@"; then
    printf 'ERROR: failed to validate the command line options
' >&2
    return 1
  fi

  log_verbose "verifying the required tools are installed"
  if ! check_tools; then
    printf 'ERROR: one or more required tools are not installed\n' >&2
    return 1
  fi

  log_verbose "verifying the required environment variables are defined"
  if ! check_environment_vars; then
    printf 'ERROR: one or more required environment variables are undefined\n' >&2
    return 1
  fi

  log_verbose "creating the project"
  if ! create_proj; then
    printf 'ERROR: failed to create the project: %s/%s\n' "${ORG}" "${NAME}" >&2
    return 1
  fi

  log_verbose "project setup completed: ${ORG}/${NAME}"
  return 0
}

# Run main() when this script is executed, but not when it is sourced,
# so that its functions remain callable in isolation from a test shell.
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  # main() is called from a condition so that a failure is reported
  # here instead of aborting the script through errexit.
  if main "$@"; then
    printf 'Done.\n'
  else
    printf 'ERROR: project setup failed\n' >&2
    exit 1
  fi
fi
