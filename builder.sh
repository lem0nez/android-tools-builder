#!/usr/bin/env bash

# Copyright © 2019 Nikita Dudko. All rights reserved.
# Contacts: <nikita.dudko.95@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eo pipefail
shopt -s nullglob globstar

VERSION='1.1.0'
BUILDER_HOME='.builder-home'
CONF_FILE='.builder.conf'
REPO_FILE='.repo.py'
DEFAULT_THREADS=4
MIN_RAM_GB=4
MIN_ROM_GB=55

AVAIL_TOOLS=(
  'zipalign'
)

declare -A TOOLS_PATHS=(
  [zipalign]='build/tools/zipalign'
)

declare -A TOOLS_OUT_PATHS=(
  [zipalign]='out/target/product/generic/system/bin/zipalign'
)

AVAIL_ARCHS=(
  'arm' 'arm64'
  'mips' 'mips64'
  'x86' 'x86_64'
)

main() {
  funcs=(
    'check_pkgs'
    'check_rom'
    'check_git'
    'download_repo'
    'get_latest_branch'
    'repo_init'
    'repo_sync'
    'patch_files'
  )

  set_work_path "$@"

  while [[ -n $1 ]]; do
    case $1 in
      -o|--tools)
        set_tools "$2"
        shift ;;
      -a|--archs)
        set_archs "$2"
        shift ;;
      -t|--threads)
        set_threads "$2"
        shift ;;
      -h|--help)
        show_help
        exit 0 ;;
      -*)
        echo >&2 "Unrecognized parameter: \"$1\"!"
        exit 1 ;;
    esac
    shift
  done

  # Tools didn't specify in the parameters.
  if [[ -z $TOOLS ]]; then
    config_tools=$(get_conf 'TOOLS')

    if [[ -z $config_tools ]] || [[ $config_tools == 'all' ]]; then
      TOOLS=("${AVAIL_TOOLS[@]}")
    else
      read -ra TOOLS <<< "$config_tools"
    fi
  fi

  # Architectures didn't specify in the parameters.
  if [[ -z $ARCHS ]]; then
    config_archs=$(get_conf 'ARCHITECTURES')

    if [[ -z $config_archs ]] || [[ $config_archs == 'all' ]]; then
      ARCHS=("${AVAIL_ARCHS[@]}")
    else
      read -ra ARCHS <<< "$config_archs"
    fi
  fi

  # Number of threads didn't specify in the parameters.
  if [[ -z $THREADS ]]; then
    config_threads=$(get_conf 'THREADS')

    if [[ -n $config_threads ]]; then
      THREADS=$config_threads
    else
      THREADS=$(nproc 2> /dev/null || echo "$DEFAULT_THREADS")
    fi
  fi

  printf ' ------ Builder configuration ------\n'`
      `'Work path: %s\n'`
      `'Tools: %s\n'`
      `'Architectures: %s\n'`
      `'Sync threads: %i\n'`
      `' ------ ------ ------- ------ ------\n' \
      "$WORK_PATH" "$(sed 's/ /, /g' <<< "${TOOLS[*]}")" \
      "$(sed 's/ /, /g' <<< "${ARCHS[*]}")" "$THREADS"

  check_ram

  gitconfig_path="$HOME/.gitconfig"
  # For storing files generated by programs.
  export HOME="$WORK_PATH/$BUILDER_HOME"

  if [[ ! -e $HOME ]]; then
    mkdir "$HOME"
  fi

  # Copy Git configuration.
  if [[ -f $gitconfig_path ]]; then
    cp "$gitconfig_path" "$HOME"
  fi

  step=$(get_conf 'LAST_STEP')
  if [[ -z $step ]]; then
    step=0
  fi

  # Start from last saved build step.
  while (( step != ${#funcs[@]} )); do
    ${funcs[$step]}
    step=$(( step + 1 ))
    set_conf 'LAST_STEP' "$step"
  done

  build_tools
  printf '\nAll done! Congratulations!\n'
  exit 0
}

# Function receive all script parameters.
set_work_path() {
  while [[ -n $1 ]]; do
    if [[ ${1::1} != '-' ]] && \
        [[ ! $prev_arg =~ (^-(o|a|t|-tools|-archs|-threads)$) ]]; then

      if [[ ! -d $1 ]]; then
        mkdir -p "$1"
      fi
      WORK_PATH=$(realpath "$1")
      break
    fi

    prev_arg=$1
    shift
  done

  if [[ -z $WORK_PATH ]]; then
    WORK_PATH=$(realpath ".")
  fi
}

show_help() {
  if installed_via_deb; then
    cmd='tools-builder'
  else
    cmd='./builder.sh'
  fi

  printf 'Android tools builder v%s.\n'`
      `'This script helps to build statically linked\n'`
      `'tools for different mobile architectures.\n'`
      `'\n'`
      `'Usage: %s [parameters] [path].\n'`
      `'If a path didn'"'"'t specify, the builder will use\n'`
      `'the current directory for storing the AOSP files.\n'`
      `'\n'`
      `'Parameters:\n'`
      `'  -o, --tools <tools>    Set tools for build, separated with comma:\n'`
      `'                         %s\n'`
      `'                         or all. Default: all.\n'`
      `'  -a, --archs <archs>    Set target architectures, separated with\n'`
      `'                         comma: %s\n'`
      `'                         or all. Default: all.\n'`
      `'  -t, --threads <number>    Set number of threads to use for syncing\n'`
      `'                            the repository. Default: number of\n'`
      `'                            processor cores or %i.\n'`
      `'  -h, --help    Show help and exit.\n' \
      "$VERSION" "$cmd" "$(sed 's/ /, /g' <<< "${AVAIL_TOOLS[*]}")" \
      "$(sed 's/ /, /g' <<< "${AVAIL_ARCHS[*]}")" "$DEFAULT_THREADS"
}

# First parameter — variable, second — value.
set_conf() {
  conf_path="$WORK_PATH/$CONF_FILE"

  if [[ ! -e $conf_path ]]; then
    touch "$conf_path"
  fi

  if ! grep -qE "^[[:space:]]*$1[[:space:]]*=" < "$conf_path"; then
    # If variable didn't exist.
    echo "$1='$2'" >> "$conf_path"
  else
    sed -i -r "s/(^[[:space:]]*$1[[:space:]]*)=.*$/\\1='$2'/" "$conf_path"
  fi
}

# First parameter — variable. Return value.
get_conf() {
  conf_path="$WORK_PATH/$CONF_FILE"

  if [[ -f $conf_path ]]; then
    while IFS='=' read -r var val; do
      if [[ $var == "$1" ]]; then
        sed -r "s/^[[:space:]]*(\"|')//; s/(\"|')[[:space:]]*$//" <<< "$val"
        return
      fi
    done < "$conf_path"
  fi
}

# First parameter — list of tools separated with comma.
set_tools() {
  tools=$1
  IFS=',' read -ra choosed_tools <<< "$tools"

  if [[ -z $tools ]]; then
    echo >&2 'Please, specify tools separated with comma!'
    exit 1
  elif [[ $tools == 'all' ]]; then
    TOOLS=("${AVAIL_TOOLS[@]}")
    return
  fi

  for t in "${choosed_tools[@]}"; do
    if [[ " ${TOOLS[*]} " =~ ( $t ) ]]; then
      # If tool already specified.
      continue
    elif [[ " ${AVAIL_TOOLS[*]} " =~ ( $t ) ]]; then
      TOOLS+=("$t")
    else
      echo >&2 "Unrecognized tool: \"$t\"!"
      exit 1
    fi
  done

  set_conf 'TOOLS' "${TOOLS[*]}"
}

# First parameter — list of architectures separated with comma.
set_archs() {
  archs=$1
  IFS=',' read -ra choosed_archs <<< "$archs"

  if [[ -z $archs ]]; then
    echo >&2 'Please, specify architectures separated with comma!'
    exit 1
  elif [[ $archs == 'all' ]]; then
    ARCHS=("${AVAIL_ARCHS[@]}")
    return
  fi

  for a in "${choosed_archs[@]}"; do
    if [[ " ${ARCHS[*]} " =~ ( $a ) ]]; then
      # If architecture already specified.
      continue
    elif [[ " ${AVAIL_ARCHS[*]} " =~ ( $a ) ]]; then
      ARCHS+=("$a")
    else
      echo >&2 "Unrecognized architecture: \"$a\"!"
      exit 1
    fi
  done

  set_conf 'ARCHITECTURES' "${ARCHS[*]}"
}

# First parameter — number of threads.
set_threads() {
  if [[ ! $1 =~ (^[0-9]$) ]] || (( $1 < 1 )); then
    echo >&2 "Number of threads should be an integer, which greater than 0!"
    exit 1
  else
    THREADS=$1
  fi

  set_conf 'THREADS' "$1"
}

# Return 0 if the script installed via a .deb package, otherwise 1.
installed_via_deb() {
  if [[ $(dirname "$(readlink -f "${BASH_SOURCE[0]}")") == /usr/bin ]]; then
    return 0
  else
    return 1
  fi
}

check_pkgs() {
  required_pkgs=(
    'bison' 'build-essential' 'curl' 'flex' 'g++-multilib' 'gcc-multilib'
    'git' 'gnupg' 'gperf' 'lib32ncurses5-dev' 'lib32z1-dev'
    'libc6-dev-i386' 'libgl1-mesa-dev' 'libx11-dev' 'libxml2-utils'
    'python2.7' 'ruby' 'unzip' 'x11proto-core-dev' 'xsltproc' 'zip' 'zlib1g-dev'
  )

  # Alternative packages names with regex support.
  declare -A alt_pkgs_names=(
    [g++-multilib]='g\+\+-[0-9]+-multilib'
  )

  echo '> Checking required packages...'

  if ! pkgs=$(dpkg --get-selections 2> /dev/null); then
    printf >&2 "Can't get list of the installed packages!\\n"`
      `"Make sure that you have following packages: %s.\\n"`
      `"Continue?\\n" "$(sed 's/ /, /g' <<< "${required_pkgs[*]}")"

    while read -rp 'Yes/No> ' answer; do
      if ! grep -qiE '^(y|yes)$' <<< "$answer"; then
        printf '\nBuild stopped.'
        exit 1
      else
        break
      fi
    done
  fi

  for p in "${required_pkgs[@]}"; do
    if ! grep -qE "^$p([[:space:]]|:)" <<< "$pkgs"; then
      if [[ -z ${alt_pkgs_names[$p]} ]] || \
          ! grep -qE "^${alt_pkgs_names[$p]}([[:space:]]|:)" <<< "$pkgs"; then
        not_installed_pkgs+=("$p")
      fi
    fi
  done

  if [[ -n ${not_installed_pkgs[*]} ]]; then
    printf >&2 "Following packages didn't install: %s.\\n"`
        `"Continue build without this packages (may lead to fail)?\\n"`
        ` "$(sed 's/ /, /g' <<< "${not_installed_pkgs[*]}")"

    while read -rp 'Yes/No> ' answer; do
      if ! grep -qiE '^(y|yes)$' <<< "$answer"; then
        # shellcheck disable=SC2059
        printf 'Tip: on Debian-based distributions you can\n'`
            `'install required packages via "sudo apt install" command.\n'`
            `'\n'`
            `'Build stopped.\n'
        exit 1
      else
        break
      fi
    done
  fi
}

check_ram() {
  # Rows of /proc/meminfo file.
  rows=('MemTotal' 'SwapTotal')
  echo '> Checking RAM size...'

  for r in "${rows[@]}"; do
    row_size=$(grep -E "^$r:" < /proc/meminfo | awk '{print $2}')
    total_size=$(( total_size + (row_size / 1024) ))
  done

  # Convert to gigabytes.
  total_size=$(( total_size / 1024 + 1 ))

  if (( total_size < MIN_RAM_GB )); then
    printf >&2 'To build tools recommended have at least %i GB of RAM,\n'`
        `'you have only %i GB. Ignore it and continue\n'`
        `'(may lead to fail while compiling tools)?\n' \
        "$MIN_RAM_GB" "$total_size"

    while read -rp 'Yes/No> ' answer; do
      if ! grep -qiE '^(y|yes)$' <<< "$answer"; then
        printf `
            `'Tip: you can make a SWAP file by executing this commands via root:\n'`
            `'  # dd if=/dev/zero of=swapfile bs=1048576 count=%i\n'`
            `'  # mkswap swapfile\n'`
            `'  # swapon swapfile\n'`
            `'\n'`
            `'Build stopped.\n' "$(( (MIN_RAM_GB - total_size) * 1024 ))"
        exit 1
      else
        break
      fi
    done
  fi
}

check_rom() {
  echo '> Checking free space...'

  # Show in gigabytes and exclude a header.
  avail_space=$(df -B $(( 1024 ** 3 )) --output=avail "$WORK_PATH" | awk 'NR==2')

  if (( avail_space < MIN_ROM_GB )); then
    printf >&2 'You have only %i GB of the available space, but need %i GB\n'`
        `'for storing files. Ignore it and continue anyway\n'`
        `'(may lead to fail while syncing or building tools)?\n' \
        "$avail_space" "$MIN_ROM_GB"

    while read -rp 'Yes/No> ' answer; do
      if ! grep -qiE '^(y|yes)$' <<< "$answer"; then
        # shellcheck disable=SC2059
        printf 'Tip: you can free some disk space by\n'`
            `'removing files from ~/.cache or /tmp.\n'`
            `'\n'`
            `'Build stopped.\n'
        exit 1
      else
        break
      fi
    done
  fi
}

check_git() {
  # Git configurations.
  vars=('user.name' 'user.email')
  tip='Tip: you can change Git configuration by executing\n'`
      `'"git config --global <variable> <value>".\n'`
      `'\n'`
      `'Build stopped.\n'

  echo '> Checking Git configuration...'

  if ! config=$(git config -l 2> /dev/null); then
    printf >&2 "Can't check Git configuration!\\n"`
        `"Make sure that following variables set: %s.\\n"`
        `"Continue build?\\n" "$(sed 's/ /, /g' <<< "${vars[*]}")"

    while read -rp 'Yes/No> ' answer; do
      if ! grep -qiE '^(y|yes)$' <<< "$answer"; then
        printf '%s' "$tip"
        exit 1
      else
        return
      fi
    done
  fi

  for v in "${vars[@]}"; do
    # shellcheck disable=SC1087
    if ! grep -qE "^[[:space:]]*$v[[:space:]]*=[[:space:]]*.+$" \
        <<< "$config"; then
      unset_vars+=("$v")
    fi
  done

  if [[ -n ${unset_vars[*]} ]]; then
    printf >&2 "Following configuration variables didn't set: %s.\\n"`
        `"Continue build without them (not recommended)?\\n" \
        "$(sed 's/ /, /g' <<< "${vars[*]}")"

    while read -rp 'Yes/No> ' answer; do
      if ! grep -qiE '^(y|yes)$' <<< "$answer"; then
        printf '%s' "$tip"
        exit 1
      else
        return
      fi
    done
  fi
}

download_repo() {
  repo_path="$WORK_PATH/$REPO_FILE"
  echo '> Downloading repo script...'

  curl -o "$repo_path" -sL \
      'https://storage.googleapis.com/git-repo-downloads/repo'
  chmod +x "$repo_path"
}

get_latest_branch() {
  echo '> Retrieving a latest branch name...'

  if ! latest_branch=$(git ls-remote -h \
      'https://android.googlesource.com/platform/manifest' | \
      sed -r 's#^.+/##g; /^android-[1-9]/!d' | sort -rV | awk 'NR==1'); then

    echo >&2 "Can't get the latest branch name! Using master."
    set_conf 'BRANCH' 'master'
    return
  fi

  echo "Latest branch: $latest_branch."
  set_conf 'BRANCH' "$latest_branch"
}

repo_init() {
  echo '> Initializing...'

  cd "$WORK_PATH"
  "./$REPO_FILE" init -u 'https://android.googlesource.com/platform/manifest' \
      -b "$(get_conf 'BRANCH')" --depth=1 --no-clone-bundle --no-tags
}

repo_sync() {
  echo '> Syncing (it take a long time)...'

  cd "$WORK_PATH"
  "./$REPO_FILE" sync -cqj"$THREADS" --no-clone-bundle --no-tags
}

patch_files() {
  echo '> Patching build properties...'

  if installed_via_deb; then
    patches_path='/usr/share/android-tools-builder/patches'

    if [[ ! -d $patches_path ]]; then
      echo >&2 "A folder with patches doesn't exist! "`
          `"Try to reinstall the package."
      exit 1
    fi
  else
    patches_path="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/patches"

    if [[ ! -d $patches_path ]]; then
      # shellcheck disable=SC2059
      printf >&2 "Can't get patches! Make sure that \"patches\"\\n"`
          `"folder locate in the directory with script.\\n"
      exit 1
    fi
  fi

  # Get paths relative directories.
  IFS=$'\r' read -ra paths <<< "$(find "$patches_path" -type 'f' -name '*.bp' | \
      sed -r "s#^$patches_path/##; s:/*[^/]+$::; s:^$:.:" | \
      sort -u | tr '\n' '\r')"

  for p in "${paths[@]}"; do
    android_bp=$(cat "$WORK_PATH/$p/Android.bp")
    patched_props_count=0

    while IFS= read -r line; do
      if [[ $process == true ]]; then
        property="$property"$'\r'"$line"

        if grep -qE '^}[[:space:]]*$' <<< "$line"; then
          # If end of property reached.
          process=false
          md5=$(md5sum <<< "$property" | awk '{print $1}')
          patch="$patches_path/$p/$md5.bp"

          if [[ -e $patch ]]; then
            # Read and delete comments, empty lines
            # and trailing new line character.
            patch_content=$(sed -r \
                '/^[[:space:]]*\/\/.*$/d; /^[[:space:]]*$/d' "$patch" | \
                tr '\n' '\r' | sed -r 's/\r$//')

            # Export makes the variables visible for ruby command.
            export patch_content property
            # Replace property with patch.
            android_bp_patched=$(ruby -p -e \
                "gsub(ENV['property'], ENV['patch_content'])" \
                <<< "$(tr '\n' '\r' <<< "$android_bp")")
            tr '\r' '\n' <<< "$android_bp_patched" > "$WORK_PATH/$p/Android.bp"

            patched_props_count=$(( patched_props_count + 1 ))
          fi
        fi
      elif grep -qE '^[a-z_]+[[:space:]]*{[[:space:]]*$' <<< "$line"; then
        # If it start of property.
        property=$line
        process=true
      fi
    done <<< "$android_bp"

    if (( patched_props_count != 0 )); then
      if (( patched_props_count == 1)); then
        end='y'
      else
        end='ies'
      fi
      echo "$p/Android.bp: $patched_props_count propert$end patched."
    else
      echo >&2 "No patches applied for $p/Android.bp!"
    fi
  done
}

build_tools() {
  echo '> Building tools...'
  out_path="$WORK_PATH/$(get_conf 'BRANCH')"

  for a in "${ARCHS[@]}"; do
    unset BUILD_TOOLS

    for t in "${TOOLS[@]}"; do
      if [[ ! -e $out_path/$t/$a/$t ]]; then
        # If tool didn't build.
        BUILD_TOOLS+=("$t")
      fi
    done

    if [[ -z ${BUILD_TOOLS[*]} ]]; then
      # If all tools for current architecture is built.
      continue
    fi

    echo "> Switching architecture to $a..."
    cd "$WORK_PATH"
    rm -rf "out/*" "out/.[!.]*"

    # shellcheck disable=SC1091
    . build/envsetup.sh > /dev/null
    lunch "aosp_$a-eng" > /dev/null

    for t in "${BUILD_TOOLS[@]}"; do
      echo "> Building $t for $a..."
      cd "${TOOLS_PATHS[$t]}"
      LANG='en_US.UTF-8' LC_ALL=C mm

      mkdir -p "$out_path/$t/$a"
      mv "$WORK_PATH/${TOOLS_OUT_PATHS[$t]}" "$out_path/$t/$a/$t"
      echo "> $t for $a is built! Location: $out_path/$t/$a/$t."
    done
  done
}

main "$@"
