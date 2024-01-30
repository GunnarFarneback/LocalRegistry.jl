# Create Registry

The full set of arguments to `create_registry` is
```
create_registry(name_or_path, repository_url;
                description, push, branch, git_config)
```

## Positional Arguments

`name_or_path::AbstractString`:

The name and location (on local storage) of your new registry can be
specified in two different ways. The recommended way is to specify it
by name. In that case it is created in the standard place for
registries, typically `~/.julia/registries`, and will be automatically
available as an installed registry. The second option is to specify it
by path, in which case the last component of the path is used as the
registry name. If you want to create a registry in your current
directory, specify the path with a leading `"./"` to disambiguate it
from a registry name.

`repository_url::AbstractString`:

Normally `repository_url` should be the URL to an existing but empty
repository on some git hosting service, e.g. GitHub or GitLab, but it
can also be a bare repository on local storage. In order to work
properly you need to be able to push to the registry, which may
involve ssh keys or other credentials.

Notes:

* When creating the repository on a git hosting service, it is
  recommended to unmark all options to initialize the repo with
  various content.

* For URLs to local storage, it is recommended to use the [File URI
  scheme](https://en.wikipedia.org/wiki/File_URI_scheme),
  e.g. `file:///home/user/registry`.

* If you want to create a bare repository, use `git init --bare`.
  Normal repositories are not advisable to use as targets for push
  operations.

* If you should want to only use the registry on a single computer and
  not have an upstream repository at all, you can set `repository_url`
  to a fake URL and use the keyword argument `push = false` with both
  the `create_registry` and `register` functions.

## Keyword Arguments

`description::Union{Nothing, AbstractString}`:

Free text description of the registry. This is stored in the top level
file `Registry.toml` but is currently neither used, nor exposed, by
the package manager. Defaults to `nothing`, meaning that it is
omitted.

`push::Bool`:

Whether to `git push` the created registry to the upstream repository
specified by `repository_url`. If `false` you need to do the `git
push` manually, but gives you opportunity to review the result before
pushing it. Defaults to `false`.

**Note: The default will likely be changed to `true` in a future
breaking release.**

`branch::Union{Nothing, AbstractString}`:

What branch to use for the registry in the repository. Defaults to
`nothing`, in which case the branch name is decided by:

* If `push` is true, the default branch in the upstream repository is
  used, if the repository exists and can be cloned.

* Otherwise the default branch for the local `git` is used.

`git_config::Dict{<:AbstractString, <:AbstractString}`:

Optional configuration parameters for the `git` command. For
interactive use you most likely do not need this. Defaults to
an empty dictionary, i.e. no configuration.
