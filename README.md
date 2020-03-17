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
in the Julia REPL prints a version number rather than giving an error,
you are good to go.

## Installation

```
using Pkg
pkg"add https://github.com/GunnarFarneback/LocalRegistry.jl"
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

## Working with a Private Registry and/or Private Repositories

If the registry needs to be private and/or privately hosted packages are 
added to it, using the git ssh protocol works well with Julia's Pkg manager:

### 1. Add Packages to the Registry with the git ssh url Protocol

Activate the private registry in Julia with the `git@github.com:...` 
url format
```
using Pkg
pkg"registry add git@github.com:User/CustomRegistry.git"
```

Adding a private package to the registry with the `git@github.com:...`
url format
```
using LocalRegistry
register(package, registry, repo="git@github.com:User/Package.jl.git")
```

### 2. Set Up Persistent git ssh Authentication that Julia Recognizes

By default libssh2 (which is used by the Julia Pkg manager via libgit2)
looks for git ssh keys in ~/.ssh/id_rsa and ~/.ssh/id_rsa.pub so if you 
have that typical setup you shouldn't need to do anything extra. 

If that doesn't work, or if your git keys need to be named differently, 
you can try to set `SSH_PUB_KEY_PATH` and `SSH_KEY_PATH` environmental 
variables:

In Juno, setting “Julia Options” > “Arguments” to:
```
SSH_PUB_KEY_PATH=~/.ssh/key.pub, SSH_KEY_PATH=~/.ssh/key
```
or in `~/.bashrc`, for instance
```
export SSH_PUB_KEY_PATH=~/.ssh/key.pub
export SSH_KEY_PATH=~/.ssh/key
```

