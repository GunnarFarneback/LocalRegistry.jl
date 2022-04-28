# Creating a Minimal Package at GitHub

This tutorial shows how to create a *minimal* Julia package and make
it publically available in a GitHub repository. The purpose of the
package is only to provide demonstration material for the [next
LocalRegistry tutorial](register_package.md).

If you want a tutorial tailored to some other git hosting service than
GitHub, feel free to submit a pull request that adds it.

**Important:** This tutorial does *not* represent best practice for
creating Julia packages but shows how to make a *minimal valid*
package. For better tools, see the
[PkgTemplates](https://github.com/invenia/PkgTemplates.jl) and
[PkgSkeleton](https://github.com/tpapp/PkgSkeleton.jl) packages.

## Versions

This tutorial was made in April 2022 using Julia 1.7.2 and Git
2.25.1. The tutorial was made on Linux but should work the same on
other platforms. Paths may look different though.

## Prerequisites

It is assumed that you have Julia and Git installed on your computer
and a GitHub account where you can create a new repository for your
package. You also need to be able to authenticate with Git to GitHub
using either `https` with password or `ssh` with keys. Some
familiarity with Git and with GitHub is assumed.

## Creating a Minimal Package

Place yourself in a directory where you want to have your package and
start Julia. For simplicity I will just use the top of my home
directory, but most likely you can find some better option. After
starting Julia, enter package mode by pressing `]` and run
```
(@v1.7) pkg> generate MinimalPackage
  Generating  project MinimalPackage:
    MinimalPackage/Project.toml
    MinimalPackage/src/MinimalPackage.jl
```
Exit Julia and have a look at the file structure
```
~$ cd MinimalPackage/
~/MinimalPackage$ tree
.
├── Project.toml
└── src
    └── MinimalPackage.jl

1 directory, 2 files
```
These are the files and directory structure required for a Julia
package. Looking at the content of the files, we have this in the
project file
```
~/MinimalPackage$ cat Project.toml
name = "MinimalPackage"
uuid = "60dc3756-877d-480e-a2ce-4e4100171837"
authors = ["Gunnar Farnebäck <gunnar.farneback@contextvision.se>"]
version = "0.1.0"
```

Name, uuid and version are required. The `authors` line is not
necessary and can be removed if you wish. The uuid must be unique and
has been randomly generated.

**Important**: Never copy an existing uuid to anything else. If you
need a fresh uuid, run
```
julia> using UUIDs; uuid4()
```

The `MinimalPackage.jl` file contains
```
module MinimalPackage

greet() = print("Hello World!")

end # module
```

This file must define a module of the same name as the file and the
name field in `Project.toml`. The `greet` function is obviously just a
placeholder for the functionality you would implement in your package.
I will leave it here since it provides something to test.

## Adding a Git Repository

To be able to share the package the first step is to put it into a git
repository.

```
~/MinimalPackage$ git init
Initialized empty Git repository in /home/gunnar/MinimalPackage/.git/
~/MinimalPackage$ git add Project.toml src/MinimalPackage.jl
~/MinimalPackage$ git commit -m "Initial version."
[master (root-commit) e755f48] Initial version.
 2 files changed, 9 insertions(+)
 create mode 100644 Project.toml
 create mode 100644 src/MinimalPackage.jl
```

This creates a git repository which only exists locally on your file
system.

## Creating a Remote Repository on GitHub

The next step is to create a remote repository for your package on
GitHub and make your package available there.
