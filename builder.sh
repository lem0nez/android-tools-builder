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

VERSION='1.0.0'
DEFAULT_THREADS=4

main() {
  while [[ -n $1 ]]; do
    case $1 in
      -a|--arch)
        set_archs "$2"
        shift ;;
      -t|--threads)
        if [[ ! $2 =~ (^[0-9]$) ]] || (( $2 < 1 )); then
          echo >&2 "Number of threads should be an integer, which greater than 0!"
          exit 1
        else
          THREADS=$2
        fi ;;
      -h|--help)
        show_help ;;
      -*)
        echo >&2 "Unrecognized parameter: \"$1\"!"
        exit 1 ;;
    esac
    shift
  done

  if [[ -z $THREADS ]]; then
    THREADS=$(nproc 2> /dev/null || echo "$DEFAULT_THREADS")
  fi
}

show_help() {
  printf 'Android tools builder v%s.\n'`
      `'This script helps to build such tools, as: zipalign for mobile\n'`
      `'arhitectures: ARM, ARM64, MIPS, MIPS64, x86 and x86_64.\n'`
      `'\n'`
      `'Usage: builder.sh [parameters] [path].\n'`
      `'If path didn'"'"'t specify, will use the current\n'`
      `'directory for storing the AOSP files.\n'`
      `'\n'`
      `'Parameters:\n'`
      `'  -a, --arch       Set target architectures, separated with comma:\n'`
      `'                   arm, arm64, mips, x86, x86_86, all. Default: all.\n'`
      `'  -t, --threads    Set number of threads to use for syncing the\n'`
      `'                   repository. Default: number of processor cores or %i.\n'`
      `'  -h, --help       Show help and exit.\n'`
      ` "$VERSION" "$DEFAULT_THREADS"
  exit 0
}

set_archs() {
  avail_archs=(
    'arm' 'arm64'
    'mips' 'mips64'
    'x86' 'x86_64'
  )
  IFS=',' read -a choosed_archs <<< "$1"

  if [[ -z ${choosed_archs[*]} ]]; then
    echo >&2 'Please, specify architectures separated with comma!'
    exit 1
  elif [[ ${choosed_archs[*]} == 'all' ]]; then
    ARCHS=("${avail_archs[@]}")
    return
  fi

  for a in "${choosed_archs[@]}"; do
    if [[ " ${avail_archs[*]} " =~ ( $a ) ]]; then
      ARCHS+=("$a")
    else
      echo >&2 "Unrecognized architecture: \"$a\"!"
      exit 1
    fi
  done
}

main "$@"
