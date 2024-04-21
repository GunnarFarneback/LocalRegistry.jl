# Using a Custom Git

By default LocalRegistry uses an external `git` binary available in
the system PATH.

If you do not have an external `git` installation, or if it is very
old or not working for some other reason, `LocalRegistry` provides a
package extension to obtain a `git` binary from the `Git` package.
This feature requires Julia 1.9 or later but it is also possible to
use the bundled `git` from Julia 1.6, although not as
conveniently, as described below.

## Bundled Git for Julia 1.9 and Later

To enable the package extension you need to install the `Git` package
in the same environment you use for running `LocalRegistry`.
```
using Pkg
Pkg.install("Git")
```

Then you also need to load (with `import` or `using`) the `Git`
package together with `LocalRegistry`. E.g.
```
using LocalRegistry, Git
```

### Bundled Git for Julia 1.6 - 1.8

Add the `Git` package to your environment as with the package
extension. Then use the `custom_git` keyword argument (further
explained in the following section).

```
import Git
register(; custom_git = Git.git())
```

## Further Customization

If this is not working satisfactorily you can customize the `git`
command to be used by specifying the `custom_git` keyword argument to
`create_registry` or `register`. This can either specify a path to
`git` or a `Cmd` object.

Examples:

```
# Use the git found in the system PATH, even if the Git package is loaded.
register(; custom_git = "git")

# Specify an absolute path.
register(; custom_git = "/usr/bin/git")

# Same as the first example but using a CMD object.
register(; custom_git = `git`)

# Call a system git via a Windows cmd wrapper.
register(; custom_git = `cmd /c git`)

# Call a bundled git via a Windows cmd wrapper.
import Git
register(; custom_git = `cmd /c $(Git.git())`)
```

## Custom Git Configuration

You can also add git configuration with the `gitconfig` keyword
argument. E.g.

```
register(; gitconfig = Dict("user.name" => "Jane Doe"))
```

expands to `git ... -c user.name="Jane Doe" ...` in all `git` calls
made by `register`.
