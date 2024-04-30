edepbuild is a utility that helps manage dependency builds for your C++ project.

The goal isn't to be perfect or to require you to port everything to another system that promises to
solve everything. Instead edepbuild provides a framework to automate the building of your project's
dependencies utilising whichever build system the dependency's developer happened to favour at the
time.

There are some reasonable defaults so well behaving dependencies can be configured and built by
setting four values in a configuration file. Each configuration file also operates as a script
that can replace implementations of any stage in the pipeline from downloading through to building
and installing.

This goal is to reduce the burden of dependency management so you can focus on your project.

edepbuild provides mechanisms to manage cross compilation as well as native tagets.

The script comes in two flavours:
- A bash shell script that supports autotools and cmake - compilers are configurable
- A PowerShell version of the script that defaults cmake + Visual Studio.

Variations of edepbuild have been used at numerous (at least 5) companies over the last decade.

Previously it has primarily been distributed with Echo (the 'e' in the name) but the scripts have
proven themselves and deserve their own home. https://github.com/SeanTasker/edepbuild

For additional probably more up to date version of edepbuild check out Echo. There are also
configurations for multiple platform targets including Wii and Windows Cross compilation from
Linux.

Echo - https://developer.emblem.net.au/source/echo3/

Check out the help text from the script (or read it within) for more information.
