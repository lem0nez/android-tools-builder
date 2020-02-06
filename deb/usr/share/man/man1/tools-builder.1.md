% TOOLS-BUILDER(1)
% Nikita Dudko
% 2019-04-27

# NAME

tools-builder - helps to build statically linked
Android tools for different mobile architectures

# SYNOPSIS

tools-builder [-t threads] [-b branch] [-a architectures] [-o tools] path

# DESCRIPTION

Script automatically checks your environment, syncs AOSP repository and builds
tools. All you need is run `tools-builder` **in a work directory**. Or, you can
specify the path in parameters. Builder will **store all files** in this directory.

By default it builds **all supported tools** for **all available architectures**.
You can change it by providing list of needed tools with `-o` parameter, and
list of target architectures with `-a` parameter. To get information about
supported tools and architectures, execute this script with `-h` parameter.
