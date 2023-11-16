# Using a Custom Git

By default LocalRegistry uses the `git` binary provided as an artifact
by the Git package. If this is not working satisfactorily you can
replace it with a system or custom git by specifying the
`external_git` keyword argument.

Examples:

```
register(; external_git = "git")
register(; external_git = "/usr/bin/git")
register(; external_git = `git`)
register(; external_git = `cmd /c git`)
```

You can also add git configuration with the `gitconfig` keyword
argument. E.g.

```
register(; gitconfig = Dict("user.name" => "Jane Doe"))
```

expands to `git ... -c user.name="Jane Doe" ...` in all `git` calls
made by `register`.
