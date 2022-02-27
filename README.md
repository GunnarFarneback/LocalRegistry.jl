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
This prepares a registry with the given name in the standard
location for registries. Review the result and `git push` it
manually. When created in this way the registry is automatically
activated and the next section can be skipped.

The repository at `repository_url` must be able to be pushed to,
for example by being a bare repository. `repository_url` itself
can be an URL, or a path to a local git repository.

The registry can also be created at a specified path. See the
documentation string for details.

## Add Registry

To activate the registry, do
```
using Pkg
pkg"registry add <repository url>"
```
This only needs to be done once per Julia installation.
[Troubleshooting advice](docs/troubleshooting_general.md) if you
cannot find packages from the General registry.

## Register a Package

```
using LocalRegistry
register(package, registry = registry)
```

Register the new `package` in the registry `registry`. The version
number and other information is obtained from the package's
`Project.toml`. The easiest way to specify `package` and `registry` is
by name as strings. See the documentation string for more options.

Notes:
* You need to have a clean working copy of your registry.
* The package must be stored as a git working copy, e.g. having been
  cloned with `Pkg.develop`.
* The package must be available in the current `Pkg` environment.
* The package must have a `Project.toml` or `JuliaProject.toml` file.
* There is no checking that the dependencies are available in any
  registry.
* If you have exactly one installed registry beside the `General`
  registry, it is not necessary to specify `registry`.
* By default the registry changes are `git push`ed to the upstream
  registry repository.

## Register a New Version of a Package

```
using LocalRegistry
register(package)
```

When adding a new version of a package, the registry can be
omitted. The new version number is obtained from the `version` field
of the package's `Project.toml` file.

## Simplified Registration of Active Package or Current Directory

If you start Julia with the `--project` flag or use `Pkg.activate` to
activate a developed package, this package can be registered simply by

```
using LocalRegistry
register()
```

This is also sufficient for registering a new package, provided that
you have exactly one installed registry beside the `General` registry.

If you run `register()` but the active project is not a package, it
will look for a package in the current directory.

## Advanced Topics

* [Working with a Private Registry and/or Private Repositories](docs/ssh_keys.md)
* [Registering a Package in a Subdirectory of a Repository](docs/subdir.md)
* [Migrating Packages from the General Registry](docs/migration_from_general.md)
