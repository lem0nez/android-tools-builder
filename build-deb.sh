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

# This script just build a .deb package
# for easy dependencies install.

PKG_VER='1.2.3-1'
set -eo pipefail

tmp_dir=$(mktemp -dt tmp.build-deb_XXXXXX)
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

main() {
  if [[ $(has_fakeroot) != true ]] && (( EUID != 0 )); then
    echo >&2 "As you don't have fakeroot, please, run this script via root!"
    exit 1
  fi

  cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
  # Copy with symlinks following.
  cp -rL 'deb' "$tmp_dir"
  gzip -n9 "$tmp_dir/deb/usr/share/doc/android-tools-builder/changelog.Debian"

  # Convert all manual pages from Markdown to Man format, and compress their.
  while read -r file; do
    out_file=$(sed -r 's/\.md$//' <<< "$file")
    pandoc "$file" -st 'man' -o "$out_file"
    gzip -n9 "$out_file"
    rm -f "$file"
  done <<< "$(find "$tmp_dir/deb/usr/share/man" -type 'f' -name '*.[1-8].md')"

  if [[ $(has_fakeroot) == true ]]; then
    fakeroot='fakeroot'
  else
    chown -R root:root "$tmp_dir/deb"
  fi

  $fakeroot dpkg-deb --build "$tmp_dir/deb" \
      "android-tools-builder_${PKG_VER}_all.deb"
  exit 0
}

has_fakeroot() {
  if fakeroot pwd &> /dev/null; then
    echo true
  else
    echo false
  fi
}

main "$@"
