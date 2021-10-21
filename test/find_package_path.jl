# Additional tests of `find_package_path`. Many of these have the
# purpose to cover error cases, making them somewhat contrived.

# Not a developed package.
@test_throws ErrorException find_package_path("AutoHashEquals")

# Find package by module and path.
using Multibreak
package_path = find_package_path(Multibreak)
@test find_package_path(package_path) == package_path

# Find package by name.
if Base.Sys.islinux()
    @test find_package_path("Multibreak") == package_path
else
    # Workaround for CI path weirdnesses on Windows and Mac.
    @test splitpath(package_path)[end-2:end] == splitpath(find_package_path("Multibreak"))[end-2:end]
end

# Not a package path.
corrupt_path = joinpath(package_path, "no_such_dir")
@test_throws ErrorException find_package_path(corrupt_path)

# Unknown package.
@test_throws ErrorException find_package_path("ZeroethTest")

# Current active environment is not a package. Return the current directory.
@test find_package_path(nothing) == pwd()

# Activate a package directory and find it with `find_package_path`.
Pkg.activate("Multibreak")
if Base.Sys.islinux()
    @test find_package_path(nothing) == package_path
else
    # Workaround for CI path weirdnesses on Windows and Mac.
    @test splitpath(package_path)[end-2:end] == splitpath(find_package_path(nothing))[end-2:end]
end
Pkg.activate()

# Early Julia 1.x versions insist on installing the General registry
# when doing `activate`. It is expected not to be there in the
# LocalRegistry tests, so remove it again if it has been installed.
if isdir(joinpath(first(DEPOT_PATH), "registries", "General"))
    Pkg.Registry.rm("General")
end
