If you for some reason have two registries that should only be one or
you want to copy some packages from one registry to another, you can
use the function `LocalRegistry.merge` (not exported).

    LocalRegistry.merge(target_path, source_path)

Copy all packages in the registry at `source_path` into the
registry at `target_path`.

    LocalRegistry.merge(target_path, source_path, include = ["A", "B"])

Copy only the packages `A` and `B`.

    LocalRegistry.merge(target_path, source_path, exclude = ["A", "B"])

Copy all packages except `A` and `B`.

    LocalRegistry.merge(..., merge_packages = true)

Attempt to merge packages that appear in both registries. Without this
option clashing packages give an error.
