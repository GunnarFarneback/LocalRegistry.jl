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

For serving local packages through a [Package
Server](https://github.com/JuliaLang/Pkg.jl/issues/1377) see the
companion package
[LocalPackageServer](https://github.com/GunnarFarneback/LocalPackageServer.jl).


## Compatibility

This package requires Julia 1.1 or later.

## Prerequisites

You need to have command line `git` installed and available in the
system `PATH`. If
```
run(`git --version`)
```
in the Julia REPL prints a version number rather than giving an error,
you are good to go.

## Installation

```
using Pkg
pkg"add LocalRegistry"
```

## Create Registry

```
using LocalRegistry
create_registry(name, repository_url, description = "My private registry")
```
This prepares a registry with the given name in the the standard
location for registries. Review the result and `git push` it
manually. When created in this way the registry is automatically
activated and the next section can be skipped.

The registry can also be created at a specified path. See the
documentation string for details.

## Add Registry

To activate the registry, do
```
using Pkg
pkg"registry add <repository url>"
```
This only needs to be done once per Julia installation.

## Register a Package

```
using LocalRegistry
register(package, registry)
```

Register the new `package` in the registry `registry`. The version
number and other information is obtained from the package's
`Project.toml`. The easiest way to specify `package` and `registry` is
by name as strings. See the documentation string for more options.

Notes:
* You need to have a clean working copy of your registry.
* The changes are committed to the registry but you need to push them
  yourself.
* The package must be stored as a git working copy, e.g. having been
  cloned with `Pkg.develop`.
* The package must be available in the current `Pkg` environment.
* The package must have a `Project.toml` file.
* There is no checking that the dependencies are available in any
  registry.

## Register a New Version of a Package

```
using LocalRegistry
register(package)
```

When adding a new version of a package, the registry can be
omitted. The new version number is obtained from the `version` field
of the package's `Project.toml` file.

## Advanced Topics


* [Working with a Private Registry and/or Private Repositories](docs/ssh_keys.md)
* [Registering a Package in a Subdirectory of a Repository](docs/subdir.md)

## Migrating from General

If you have a package that is registered in the [General](https://github.com/JuliaRegistries/General) registry of Julia and you want to migrate it to your own registry, one good option is to:
1. add an `__init__()` function to your package:
   ```julia
   __init__() = @warn "This package is deprecated"
   ```
2. commit and tag a release
3. remove the `__init__()` function
4. add your package to your registry
5. and never tag a new release for that package in General 

This way you can keep working on your package while tagging new releases in your registry, all the while the version in General won't get updated and will warn users that it's deprecated. Keep in mind, deleting a package from the General registry is [not possible](https://github.com/JuliaRegistries/General/blob/master/README.md#how-do-i-remove-a-package-or-version-from-the-registry) (nor needed).
