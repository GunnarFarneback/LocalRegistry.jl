# LocalRegistry

Create and maintain local registries for Julia packages. This package
is intended to provide a simple but manual workflow for maintaining
small local registries (private or public) without making any
assumptions about how the registry or the packages are hosted.

For registration in the General registry, see
[Registrator](https://github.com/JuliaComputing/Registrator.jl). For a
more automated but GitHub-centric workflow with either the General
registry or a local registry, see
[PkgDev](https://github.com/JuliaLang/PkgDev.jl).

## Compatibility

This package requires Julia 1.1 or later.

## Prerequisites

You need to have command line `git` installed and available in the
system `PATH`. If
```
run(`git --version`)
```
in the Julia REPL prints a version number rather than giving an error
you are good to go.

## Installation

```
using Pkg
pkg"add https://github.com/GunnarFarneback/LocalRegistry.jl"
```

## Create Registry

```
using LocalRegistry
create_registry(<local path>, <repository url>, description = "My private registry")
```
This prepares a registry in the given directory, which must previously
not exist. Review the result and `git push` it manually. The last component of the path is used as the name of the registry.

## Add Registry

To activate the registry, do
```
using Pkg
pkg"registry add <repository url>"
```
This only needs to be done once.

## Add a Package

```
using LocalRegistry
using MyPackage
register(MyPackage, <registry path>)
```

This assumes that you have a clean working copy of your registry at
`<registry path>` and adds `MyPackage` to the working copy. Review the
result and `git push` it manually. With the keyword argument
`commit = false`, the changes are made to the working copy but are not
committed.

Notes:
* The package must be stored as a git working copy, e.g. using
  `Pkg.develop`.
* The package must have a `Project.toml` file.
* There is no checking that the dependencies are available in any
  registry.

## Add a New Version of a Package

This is done in exactly the same way as adding a package. The only
requirement is that the `version` field of the package's
`Project.toml` is updated to a new version that is not already in the
registry.
