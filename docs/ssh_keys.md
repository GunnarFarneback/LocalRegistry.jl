# Working with a Private Registry and/or Private Repositories

If the registry needs to be private and/or privately hosted packages are
added to it, using the git ssh protocol works well with Julia's Pkg manager:

## 1. Add Packages to the Registry with the git ssh url Protocol

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

## 2. Set Up Persistent git ssh Authentication that Julia Recognizes

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
