# Android tools builder
This script helps to build statically linked Android tools for different mobile
architectures. All you need is **clone this repository**:
```
git clone https://github.com/lem0nez/android-tools-builder
```
and **run script**:
```
./builder.sh [path]
```
Path *(not necessary)* is a work directory for storing files. The script checks
your environment, syncs AOSP repository in the work directory and builds tools.

By default it builds **all supported tools** for **all available architectures**.
You can change it by providing list of needed tools with `-o` parameter, and
list of target architectures with `-a` parameter. To get information about
supported tools and architectures, execute this script with `-h` parameter.
