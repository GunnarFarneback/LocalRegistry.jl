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

## 2. Using an External git Binary with Julia's Package Manager

By default Julia's package manager uses libgit2 and libssh2 for git
operations. The remaining items discuss how to set up ssh keys to work
with these libraries. However, for Julia 1.7 and later, a potentially
much simpler and more robust solution is to set the environment
variable
```
JULIA_PKG_USE_CLI_GIT=true
```
to make Pkg use an external git binary.

## 3. Set Up Persistent git ssh Authentication that Julia Recognizes

By default libssh2 (which is used by the Julia Pkg manager via libgit2)
looks for git ssh keys in `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub` so if you
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

## 4. Generating a Compatible Key

libssh2 is much less flexible than normal ssh in many ways, including
keys. This is a way to generate a working key:
```
ssh-keygen -t rsa -b 4096 -m PEM
```
Importantly `-m PEM` is needed to store the key in the OpenSSL PEM
format rather than the default (from OpenSSH 7.8) OpenSSH format. This
is an unfortunate tradeoff since the OpenSSH format is more secure,
but libssh2 does not understand it.

If you already have a key, you can recognize the difference from the
first line of the private key:
* OpenSSL PEM format begins with `-----BEGIN RSA PRIVATE KEY-----`
* OpenSSH format begins with `-----BEGIN OPENSSH PRIVATE KEY-----`

## 5. Extracting the Public Key from the Private Key

If you only have the private key available, the corresponding public
key can be generated from the private key with
```
ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
```
