# Migrating Packages from the General Registry

If you have a package that is registered in the
[General](https://github.com/JuliaRegistries/General) registry of
Julia and you want to migrate it to your own registry, one good option
is to:

1. add an `__init__()` function to your package:
   ```julia
   __init__() = @warn "This package is deprecated"
   ```
2. commit and tag a release
3. remove the `__init__()` function
4. add your package to your registry
5. and never tag a new release for that package in General

This way you can keep working on your package while tagging new
releases in your registry, all the while the version in General won't
get updated and will warn users that it's deprecated. Keep in mind,
deleting a package from the General registry is [not possible](https://github.com/JuliaRegistries/General/blob/master/README.md#how-do-i-remove-a-package-or-version-from-the-registry)
(nor needed).
