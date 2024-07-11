# Register a Package or a New Version of a Package

Registration of a new package or a new version of a previously
registered package are both done with the `register` function.

The full set of arguments to `register` is
```
register(package = nothing;
         registry, commit, push, repo, ignore_reregistration,
         allow_package_dirty, gitconfig, create_gitlab_mr)
```

although in many cases a no-argument `register()` call is sufficient.

Notice that LocalRegistry should be installed in the global
environment or in some shared environment. It should never be a
dependency of the package you want to register, unless the package
wraps or extends LocalRegistry functionality.

## Positional Argument

`package::Union{Nothing, Module, AbstractString}`:

The package to be registered can be specified in several ways.

* If `package` is omitted or `nothing`, the active project is used if
  it is a package. Otherwise the current directory is used if that
  contains a package.

* If `package` is a `Module`, that is used. It needs to first be
  loaded by `using` or `import`.

* If `package` is a string, it can be either a package name or a
  path. It is considered a path if it contains multiple path
  components. A path in the current working directory can be specified
  by starting with `"./"`. If it is a name, it must be available in
  the active environment.

Notes:

* To activate a package, either use the `Pkg.activate` function or
  start Julia with the `--project` flag.

* The package must be stored as a git working copy, e.g. having been
  cloned with `Pkg.develop`, and must not contain un-committed changes
  (but also see the `allow_package_dirty` keyword argument).

* The package must have a `Project.toml` or `JuliaProject.toml`
  file. This must include `name`, `uuid`, and `version` fields.

* To register a new version, the `version` field in `Project.toml`
  must be updated.

* There is no checking that the package's dependencies are available
  in some registry. This can be separately verified with [registry
  consistency testing](registry_ci.md).

## Keyword Arguments

`registry::Union{Nothing, AbstractString}`:

There are a number of ways to specify the registry to register the
package in.

* If `registry` is omitted or `nothing`, it is first checked if the
  package is already registered in exactly one of the installed
  registries, in which case the new version is also registered there.
  In case of a new package, there must be exactly one installed
  registry, which is not General, and that is used.

* If `registry` is a string, the first match below is used.
  * It is considered a registry name if it is an exact match for one of
    the installed registries.
  * It is considered a path if it is an existing path on the local
    file system.
  * Otherwise it is assumed to be a URL to an upstream registry.

Notes:

* LocalRegistry needs to work with a git clone of the registry. If
  that is not already the case, or `registry` is specified as a URL, a
  temporary git clone is made for the registration. This requires that
  both keyword arguments `commit` and `push` are `true`.

* The registry must not have any un-committed changes, unless the
  keyword argument `commit` is `false`.

`commit::Bool`:

Whether to `git commit` the changes made to the registry. Default is
`true`. Only set it to `false` if you are doing something unusual and
know that it's needed.

`push::Bool`:

Whether to push the commits to the upstream repository. Default is
true. Setting it to `false` is mostly useful if you want to inspect
the commits before manually pushing, or if you have decided not to
have an upstream repository. It cannot be set to `true` if the keyword
argument `commit` is `false`.

`repo::Union{Nothing, AbstractString}`:

URL to the package repository. This is stored in the registry.

* If `repo` is omitted or `nothing`:
  * If it is a new version of a previously registered package, do not
    update the repo location.
  * If it is a new package, look up the URL from the package's `git
    remote`.

* If it is a string, set or update the repo location in the registry
  with the given string.

`ignore_reregistration::Bool`:

Whether not to give an error if trying to register a previously
registered version of the package, unless it is identical to the
registered version. Defaults to `false`. If `true`, only print an
informational message.

**Note: The default will likely be changed to `true` in a future update.**

`allow_package_dirty::Bool`:

LocalRegistry only registers what has been committed to the
package's repository, by nature of how Julia registries work. If the
package has local modifications which have not been committed, there
is a disconnect between the files on disk and what gets registered. By
default this gives an error but if you understand the consequences you
can override it by setting `allow_package_dirty` to `true` instead of
the default `false`.

An exception is if `Project.toml` (or `JuliaProject.toml` if
that is used) itself is dirty. This still gives an error, because
critical information like the version number is read from disk, and
could be different to what is in the project file being registered.

`git_config::Dict{<:AbstractString, <:AbstractString}`:

Optional configuration parameters for the `git` command. For
interactive use you most likely do not need this. Defaults to
an empty dictionary, i.e. no configuration.

For CI purposes it can be useful, e.g. as used in the LocalRegistry
tests:
```
git_config = Dict("user.name" => "LocalRegistryTests",
                  "user.email" => "localregistrytests@example.com")
```

`create_gitlab_mr`:

If `true`, send git push options to create a GitLab merge
request. Requires the keyword arguments `commit` and `push` to both be
`true`. Default is `false`. This functionality is mostly useful as
part of package CI if hosted on GitLab, to automatically register
packages.
