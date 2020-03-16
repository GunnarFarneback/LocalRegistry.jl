using LocalRegistry
using LocalRegistry: find_package_path, find_registry_path
using Test
using Random
using Pkg

const TEST_GITCONFIG = Dict(
    "user.name" => "LocalRegistryTests",
    "user.email" => "localregistrytests@example.com",
)

include("utils.jl")

# The following tests are primarily regression tests - checking that
# the results are the same as when the tests were written, regardless
# of correctness.
#
# The general strategy is that a number of project files have been
# stored. These are read and expanded to minimal stub packages, which
# are then registered in a newly created registry. The resulting
# registries after some selections of packages have been added have
# also been stored and are compared against.
#
# The project files have been extracted from the git history of the
# Flux and Images packages. The patch numbers have been faked to get
# more version samples out of their git histories. The FirstTest1
# project file is derived from this package.

# Set up packages and registry directories in a temporary location.
if VERSION >= v"1.2"
    testdir = mktempdir(prefix = "LocalRegistryTests")
else
    testdir = mktempdir()
end
packages_dir = joinpath(testdir, "packages")
if packages_dir ∉ LOAD_PATH
    push!(LOAD_PATH, packages_dir)
end
registry_dir = joinpath(testdir, "TestRegistry")

# Create a new registry.
create_registry(registry_dir, "git@example.com:Julia/TestRegistry.git",
                description = "For testing purposes only.",
                uuid = "ed6ca2f6-392d-11ea-3224-d3daf7fee369",
                gitconfig = TEST_GITCONFIG)

# Add the FirstTest1 package and check against the stored `registry1`.
prepare_package(packages_dir, "FirstTest1.toml")
using FirstTest
register(FirstTest, registry_dir, gitconfig = TEST_GITCONFIG)
@test check_result(registry_dir, "registry1")

# Reregister the same version of FirstTest to verify that nothing
# happens,
@test_logs (:info, "This version has already been registered and is unchanged.") register(FirstTest, registry_dir, gitconfig = TEST_GITCONFIG)
@test check_result(registry_dir, "registry1")

# Add 29 versions of the Flux project files and check against `registry2`.
for n = 1:29
    prepare_package(packages_dir, "Flux$(n).toml")
    using Flux
    register(Flux, registry_dir, gitconfig = TEST_GITCONFIG)
end
@test check_result(registry_dir, "registry2")

# Add 15 versions of the Images project files and check against `registry3`.
for n = 1:15
    prepare_package(packages_dir, "Images$(n).toml")
    using Images
    register(Images, registry_dir, gitconfig = TEST_GITCONFIG)
end
@test check_result(registry_dir, "registry3")

# Start over with a fresh registry and add all 46 project files but in
# shuffled order. Check that this also matches `registry3`.
registry_dir = joinpath(testdir, "test2", "TestRegistry")
create_registry(registry_dir, "git@example.com:Julia/TestRegistry.git",
                description = "For testing purposes only.",
                uuid = "ed6ca2f6-392d-11ea-3224-d3daf7fee369",
                gitconfig = TEST_GITCONFIG)
project_files = vcat("FirstTest1.toml",
                     ["Flux$(n).toml" for n = 1:29],
                     ["Images$(n).toml" for n = 1:15])
Random.seed!(13)
shuffle!(project_files)
for project_file in project_files
    prepare_package(packages_dir, project_file)
    package = match(r"[a-zA-Z]+", project_file).match
    # Register by path instead of module in this test.
    register(joinpath(packages_dir, package), registry_dir,
             gitconfig = TEST_GITCONFIG)
end
@test check_result(registry_dir, "registry3")

# Trying to register an already existing version with different content.
prepare_package(packages_dir, "Flux30.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Flux"),
                                     registry_dir, gitconfig = TEST_GITCONFIG)

# Parse error in compat section.
prepare_package(packages_dir, "Broken1.toml")
if VERSION < v"1.2"
    @test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                         registry_dir,
                                         gitconfig = TEST_GITCONFIG)
else
    @test_throws Pkg.Types.PkgError register(joinpath(packages_dir, "Broken"),
                                             registry_dir,
                                             gitconfig = TEST_GITCONFIG)
end
# Trying to change name (UUID remains).
prepare_package(packages_dir, "Fluxx1.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Fluxx"),
                                     registry_dir, gitconfig = TEST_GITCONFIG)

# Trying to change UUID.
prepare_package(packages_dir, "Flux31.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Flux"),
                                     registry_dir, gitconfig = TEST_GITCONFIG)

# Depends on itself.
prepare_package(packages_dir, "Broken2.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                     registry_dir, gitconfig = TEST_GITCONFIG)

# Incorrect name of dependency.
prepare_package(packages_dir, "Broken3.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                     registry_dir, gitconfig = TEST_GITCONFIG)

# TODO: This should really be an error but RegistryTools 1.3.0 doesn't catch it.
# Incorrect UUID of dependency.
prepare_package(packages_dir, "Broken4.toml")
register(joinpath(packages_dir, "Broken"), registry_dir,
         gitconfig = TEST_GITCONFIG)

# Incorrect UUID of stdlib.
prepare_package(packages_dir, "Broken5.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                     registry_dir, gitconfig = TEST_GITCONFIG)

# Change the git remote before registration and verify that the
# registered repo is not changed.
prepare_package(packages_dir, "Flux32.toml")
package_dir = joinpath(packages_dir, "Flux")
git = gitcmd(package_dir, TEST_GITCONFIG)
package_file = joinpath(registry_dir, "F", "Flux", "Package.toml")
old_repo = TOML.parsefile(package_file)["repo"]
new_repo = "https://example.com/Julia/Flux.jl.git"
run(`$git remote set-url origin $(new_repo)`)
register(joinpath(packages_dir, "Flux"), registry_dir,
         gitconfig = TEST_GITCONFIG)
@test TOML.parsefile(package_file)["repo"] == old_repo

# Register with explicit repo argument and verify that the registered
# repo is updated.
prepare_package(packages_dir, "Flux33.toml")
register(joinpath(packages_dir, "Flux"), registry_dir, repo = new_repo,
         gitconfig = TEST_GITCONFIG)
@test TOML.parsefile(package_file)["repo"] == new_repo

pop!(LOAD_PATH)


# Additional tests of `find_package_path` and `find_registry_path`.
# Many of these have the purpose to cover error cases, making them
# somewhat contrived. Another complicating factor is that some of the
# call variants have to interact with the package environment,
# including registries, of the running Julia process. Thus things will
# become more than slightly messy.
#
# Warning: If something goes wrong and these tests are interupted, you
# may end up with a broken state of registries. Recovery involves
# doing one or more of the following operations:
#
# using Pkg
# pkg"registry add General"
# pkg"registry rm TestRegistry2"
# pkg"registry rm TestRegistry"


# Prepare by adding an stdlib package, adding the registry used in
# previous tests, developing a package, and removing the General
# registry. The last step is necessary to avoid potential and current
# conflicts between General and package names used in these tests.
pkg"add Base64"
Pkg.Registry.add(RegistrySpec(path = registry_dir))
Pkg.develop(PackageSpec(path = joinpath(packages_dir, "FirstTest")))
pkg"registry rm General"

# Directory already exists. Also tests code handling a trailing slash.
create_registry("TestRegistry2", "", gitconfig = TEST_GITCONFIG)
@test_throws ErrorException create_registry("TestRegistry2/", "",
                                            gitconfig = TEST_GITCONFIG)

# Not a developed package. (Version 1.1 handles this a bit differently
# but it is nicer to do this with a stdlib package since someone who
# runs these tests plausibly could have AutoHashEquals as a developed
# package.
if VERSION < v"1.2"
    @test_throws ErrorException find_package_path("AutoHashEquals")
else
    @test_throws ErrorException find_package_path("Base64")
end

# Not a registered package.
pkg = Pkg.Types.Project(Dict("name" => "UUIDs",
                             "uuid" => "cf7118a7-6976-5b1a-9a39-7adc72f591a4"))
@test_throws ErrorException find_registry_path(nothing, pkg)

# Find package by module and path.
package_path = find_package_path(FirstTest)
@test find_package_path(package_path) == package_path

# Find package by name.
@test find_package_path("FirstTest") == package_path

# Not a package path.
corrupt_path = joinpath(package_path, "no_such_dir")
@test_throws ErrorException find_package_path(corrupt_path)

# Unknown package.
@test_throws ErrorException find_package_path("ZeroethTest")

# Find a registry by name.
pkg = Pkg.Types.read_project(joinpath(package_path, "Project.toml"))
@test find_registry_path("TestRegistry") == joinpath(first(DEPOT_PATH),
                                                     "registries",
                                                     "TestRegistry")

# The named registry does not exist.
@test_throws ErrorException find_registry_path("General", pkg)

# Find which registry contains a package.
@test find_registry_path(nothing, pkg) == joinpath(first(DEPOT_PATH),
                                                   "registries", "TestRegistry")

# More than one registry contains the package.
register("FirstTest", "TestRegistry2",
         repo = "file://$(packages_dir)/FirstTest",
         gitconfig = TEST_GITCONFIG)
@test_throws ErrorException find_registry_path(nothing, pkg)

# Dirty the registry repository and try to register a package.
registry_path = find_registry_path("TestRegistry2")
filename = joinpath(registry_path, "Registry.toml")
open(filename, "a") do io
    write(io, "\n")
end
@test_throws ErrorException register("FirstTest", "TestRegistry2",
                                     gitconfig = TEST_GITCONFIG)

# Remove Project.toml from a package and try to register.
rm(joinpath(package_path, "Project.toml"))
@test_throws ErrorException register("FirstTest", "TestRegistry2",
                                     gitconfig = TEST_GITCONFIG)

# Remove the added and developed packages.
pkg"rm FirstTest"
pkg"rm Base64"

# Clean up the registries.
pkg"registry rm TestRegistry"
pkg"registry rm TestRegistry2"
pkg"registry add General"
