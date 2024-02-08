# LocalRegistry

Create and maintain local registries for Julia packages. This package
is intended to provide a simple workflow for maintaining local
registries (private or public) without making any assumptions about
how the registry or the packages are hosted.

For registration in the General registry, see
[Registrator](https://github.com/JuliaComputing/Registrator.jl).

For serving local packages through a [Package
Server](https://github.com/JuliaLang/Pkg.jl/issues/1377) see the
companion package
[LocalPackageServer](https://github.com/GunnarFarneback/LocalPackageServer.jl).


## Compatibility

This package requires Julia 1.6 or later. Older versions of the
package work back to Julia 1.1.

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
Pkg.add("LocalRegistry")
```

## Create Registry

The recommended way to create a registry is
```
using LocalRegistry
create_registry(name, repository_url; description = "My private registry", push = true)
```
where `name` is the name of your registry and `repository_url` points
to an *empty* upstream repository where you will host your registry.

There are a number of options to customize this. Read more about that
and further explanations in the [detailed
instructions](docs/create_registry.md).

## Add Registry

To activate the registry, do
```
using Pkg
pkg"registry add <repository url>"
```
This only needs to be done once per Julia installation.
[Troubleshooting advice](docs/troubleshooting_general.md) if you
cannot find packages from the General registry.

## Register a Package or a New Version of a Package

The recommended way to register a package or a new version of a
package is simply:

```
using LocalRegistry
register()
```

For this to work you need to either have the package in your current
directory or have the package activated.

Actually there are some more requirements but those are usually
satisfied. Read more about that, a number of options to customize the
call, and some additional features in the [detailed
instructions](docs/register.md).

## Advanced Topics

* [Working with a Private Registry and/or Private Repositories](docs/ssh_keys.md)
* [Registering a Package in a Subdirectory of a Repository](docs/subdir.md)
* [Migrating Packages from the General Registry](docs/migration_from_general.md)
* [Using LocalRegistry on a Shared Filesysem](docs/shared_filesystem.md)
* [Delete a Registered Package](docs/delete_package.md)
* [Registry Consistency Testing](docs/registry_ci.md)
