# Troubleshooting Advice for the General Registry

## Scenario

You have added your own registry with e.g.
```
using Pkg
pkg"registry add <repository url>"
```
and then find that trying to add a package from the General registry
fails with a message like
```
ERROR: The following package names could not be resolved:
 * Example (not found in project, manifest or registry)
```
or you try to add one of your own packages, with a dependency in
General, with a result like
```
ERROR: cannot find name corresponding to UUID fa961155-64e5-5f13-b03f-caf6b980ea82 in a registry
```

## Likely Cause

This can happen if you have a fresh installation of Julia (technically
an empty depot) where the General registry was not already installed.
You can verify whether this is the case by running
```
using Pkg
pkg"registry status"
```
If this shows a single line with your own registry, you can read on to
find out what to do about it. If it does show a line
```
 [23338594] General
```
then you have the General registry installed and your problem is
something different from what is discussed here.

## Solution

Simply run
```
using Pkg
pkg"registry add General"
```
to add the General registry.

If this happens in the context of a Continuous Integration setup,
where you typically start over repeatedly from a fresh install, you
can most easily avoid the problem by doing
```
using Pkg
pkg"registry add General <repository url>"
```
to simultaneously install both the General registry and your own registry.

## Further Discussion

If you have a fresh install and don't add a custom registry, you will
not see this problem. The reason is that if you run a `Pkg` command
that needs registry information but *no* registry is installed, it
automatically installs the General registry. This does not happen if
some registry, such as your own, is already installed.
