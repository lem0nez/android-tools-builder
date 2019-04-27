![License](https://img.shields.io/github/license/lem0nez/android-tools-builder.svg)
![Latest release](https://img.shields.io/github/release/lem0nez/android-tools-builder.svg)
![Repo size](https://img.shields.io/github/repo-size/lem0nez/android-tools-builder.svg)

# Android tools builder
This script helps to build statically linked Android tools for different mobile
architectures. It automatically checks your environment, syncs AOSP repository
in an work directory and builds tools.

## Installation
You can clone this repository:
```
git clone https://github.com/lem0nez/android-tools-builder
```
or install a **.deb** package (recommended, as all required
packages for building will be installed at the same time):
```
sudo apt install ./<package>.deb
```
Alternative variant, if you don't have `apt`:
```
sudo dpkg -i <package>.deb
```
Find the latest package you can in the **Releases** tab.

## Using
All you need is run `tools-builder` (or execute `builder.sh` script,
if you cloned the repository) in the **work directory**. Or, you can specify
the path in parameters. Builder will store all files in this directory.

By default it builds **all supported tools** for **all available architectures**.
You can change it by providing list of needed tools with `-o` parameter, and
list of target architectures with `-a` parameter. To get information about
supported tools and architectures, execute this script with `-h` parameter.
