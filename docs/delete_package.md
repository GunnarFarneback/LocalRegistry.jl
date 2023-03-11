# Delete a Registered Package

There is no command to delete a registered package and the operation
must be performed manually: delete the files (typically `Compat.toml`,
`Deps.toml`, `Package.toml` and `Versions.toml`) for the package, edit
`Register.toml`, commit and push the changes.
