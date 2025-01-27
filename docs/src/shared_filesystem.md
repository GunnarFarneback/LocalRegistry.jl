# Local Registry on a Shared Filesystem.

The recommended way to manage local packages and a local registry is
by using a web-based git hosting service such as GitHub, GitLab, or
Bitbucket - either public or private or in-house.

However, it is also possible to do this on a shared or network
filesystem, or on a single computer. The following sections gives some
guidelines for how this can be done.

## File URI Scheme

Wherever LocalRegistry functions need a URL, you can use the [file URI
scheme](https://en.wikipedia.org/wiki/File_URI_scheme) to point to a
filesystem path. To determine whether you have a working file URL you
can run `git clone $URL` or `git ls-remote $URL`.

## Creating a Local Registry

To be able to share the local registry between users or computers you
need to have an upstream repository, which needs to be "bare". Create
it and leave it empty:
```shell
cd $PATH_TO_UPSTREAM_REGISTRY
git init --bare
```

Now start Julia and run
```julia
using LocalRegistry
create_registry(name, repo, push = true)
```
where `name` is a string containing the name of your registry and
`repo` is a string containing the file URL to your upstream registry.

## Installing a Local Registry

To install the registry for another Julia installation, start Julia and run
```julia
using Pkg
Pkg.Registry.add(repo)
```
where `repo` is a string containing the file URL to your upstream registry.

## Registering a Package

If the package you want to register has been cloned with a file URL
from an upstream repository (or with a normal URL from some other
source) you can use `register` as normal
```shell
cd $PACKAGE_DIR
```

and within Julia
```julia
using LocalRegistry
register()
```

If you need better control you can use the `registry` and `repo`
keyword arguments of `register`.

Note: Do not try to use relative paths to packages. That is not
supported by `Pkg`.

## Example

Create a new registry, create an empty package, and register it, all
within the `/tmp` directory on a Linux computer. For conciseness this
example uses `julia -e` instead of running Julia interactively.

### Create Registry

Create a bare upstream repository.
```shell
~$ cd /tmp
/tmp$ mkdir testregistry
/tmp$ cd testregistry
/tmp/testregistry$ git init --bare
Initialized empty Git repository in /tmp/testregistry/
/tmp/testregistry$ cd ..
```

Sanity check that this repository can be accessed with a file
URL. This should give no output since the repository is empty. For
contrast, try with an incorrect path to see that it gives an error.
```shell
/tmp$ git ls-remote file:///tmp/testregistry
/tmp$ git ls-remote file:///tmp/test_registry
fatal: '/tmp/test_registry' does not appear to be a git repository
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
```

Create a new registry and immediately push it to the upstream registry.
```shell
/tmp$ julia  -e 'using LocalRegistry; create_registry("TestRegistry", "file:///tmp/testregistry", push = true)'
Enumerating objects: 3, done.
Counting objects: 100% (3/3), done.
Delta compression using up to 8 threads
Compressing objects: 100% (2/2), done.
Writing objects: 100% (3/3), 334 bytes | 334.00 KiB/s, done.
Total 3 (delta 0), reused 0 (delta 0)
To file:///tmp/testregistry
 * [new branch]      master -> master
Branch 'master' set up to track remote branch 'master' from 'origin'.
[ Info: Created registry in directory /home/gunnar/.julia/registries/TestRegistry
```

Verify that the new registry is available in your Julia installation
and check that the upstream repository is no longer empty.
```shell
/tmp$ julia -e 'using Pkg; Pkg.Registry.status()'
Registry Status
 [6ba68ce2] TestRegistry
 [23338594] General
/tmp$ git ls-remote file:///tmp/testregistry
41ad226852ab714bfecbb7c935bc04dec3773658        HEAD
41ad226852ab714bfecbb7c935bc04dec3773658        refs/heads/master
```

### Create a Package

Create a minimal package only to have something to register. Normally
you would already have a package available.

Create an upstream repository.
```shell
/tmp$ mkdir upstream_testpackage
/tmp$ cd upstream_testpackage
/tmp/upstream_testpackage$ git init --bare
Initialized empty Git repository in /tmp/upstream_testpackage/
/tmp/upstream_testpackage$ cd ..
```

Generate a skeleton package.
```shell
/tmp$ julia -e 'using Pkg; Pkg.generate("TestPackage")'
  Generating  project TestPackage:
    TestPackage/Project.toml
    TestPackage/src/TestPackage.jl
```

Commit the package to git.
```shell
/tmp$ cd TestPackage
/tmp/TestPackage$ git init
Initialized empty Git repository in /tmp/TestPackage/.git/
/tmp/TestPackage$ git add .
/tmp/TestPackage$ git commit -m "Initial version."
[master (root-commit) 8ab87f2] Initial version.
 2 files changed, 9 insertions(+)
 create mode 100644 Project.toml
 create mode 100644 src/TestPackage.jl
 ```

Push the package to the upstream repository.
 ```shell
/tmp/TestPackage$ git remote add origin file:///tmp/upstream_testpackage
/tmp/TestPackage$ git push --set-upstream origin master
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 8 threads
Compressing objects: 100% (4/4), done.
Writing objects: 100% (5/5), 518 bytes | 518.00 KiB/s, done.
Total 5 (delta 0), reused 0 (delta 0)
To file:///tmp/upstream_testpackage/
 * [new branch]      master -> master
Branch 'master' set up to track remote branch 'master' from 'origin'.
```

### Register the Package

Now everything is ready to call `register`.

```shell
/tmp/TestPackage$ julia -e 'using LocalRegistry; register()'
┌ Info: Registering package
│   package_path = "/tmp/TestPackage"
│   registry_path = "/home/gunnar/.julia/registries/TestRegistry"
│   package_repo = "file:///tmp/upstream_testpackage/"
│   uuid = UUID("d6f52898-0eeb-4554-8a9e-40f1cf0729ea")
│   version = v"0.1.0"
│   tree_hash = "7f79887a6ddc4a158117f2580ba917070341b1ed"
└   subdir = ""
Enumerating objects: 9, done.
Counting objects: 100% (9/9), done.
Delta compression using up to 8 threads
Compressing objects: 100% (6/6), done.
Writing objects: 100% (7/7), 864 bytes | 864.00 KiB/s, done.
Total 7 (delta 0), reused 0 (delta 0)
To file:///tmp/testregistry
   0a0e747..41ad226  master -> master
Already on 'master'
Your branch is up to date with 'origin/master'.
```
