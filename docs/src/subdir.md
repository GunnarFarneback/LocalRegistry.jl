# Registering a Package in a Subdirectory of a Repository

A Julia package is normally a git repository by itself. However,
sometimes you may want to have multiple packages in one repository or
the Julia package is only a part of a larger repository. In those
cases you need to be able to register only a subdirectory of the
repository. This is fully supported by LocalRegistry and partially
supported by Julia 1.0-1.4, as explained in the following
sections. Julia support will be improved with version 1.5.

## Register

In order to register a package in a subdirectory of a repository you
need to make the following preparations:

* `git clone` the repository manually if you have not already done
  so. It does not matter where the repository is placed.
* `Pkg.develop` the package by path. E.g.
```
pkg"develop /path/to/repository/path/to/package"
```

After this, `register` can be called as normal.

## Julia support

In Julia 1.0-1.4, packages in subdirectories work as expected in the
following contexts:

* As dependencies to other packages.
* `Pkg.add` by name from registry, e.g. `pkg"add Package"`
* `Pkg.add` by name and version from registry, e.g. `pkg"add Package@1.1.0"`
* `Pkg.dev` by path (using the full path to the subdirectory)

The following do not work properly or at all:
* `Pkg.add` by path
* `Pkg.add` by name and branch from registry, e.g. `pkg"add Package#master"`
* `Pkg.dev` by name

This situation will be improved in Julia 1.5.
