using LocalRegistry
using LocalRegistry: find_package_path, find_registry_path
using Test
using Random
using Pkg

const TEST_GITCONFIG = Dict(
    "user.name" => "LocalRegistryTests",
    "user.email" => "localregistrytests@example.com",
    "core.autocrlf" => "input"
)

include("utils.jl")

# Since these tests will need to modify active registries and we don't
# want interference from, e.g. the General registry, use a temporary
# DEPOT_PATH. But first add some packages while we have the General
# registry available. These will be used for some tests later.
pkg"add AutoHashEquals"
pkg"dev --local Multibreak"
empty!(DEPOT_PATH)
depot_path = mktempdir(@__DIR__)
push!(DEPOT_PATH, depot_path)

# We don't want Pkg to try to update our local registries since they
# contain fake URLs.
Pkg.UPDATED_REGISTRY_THIS_SESSION[] = true

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
                gitconfig = TEST_GITCONFIG, push = false)

# Add the FirstTest1 package and check against the stored `registry1`.
prepare_package(packages_dir, "FirstTest1.toml")
using FirstTest
register(FirstTest, registry = registry_dir,
         gitconfig = TEST_GITCONFIG, push = false)
@test check_result(registry_dir, "registry1")

# Reregister the same version of FirstTest to verify that nothing
# happens,
@test_logs (:info, "This version has already been registered and is unchanged.") register(FirstTest, registry = registry_dir, gitconfig = TEST_GITCONFIG, push = false)
@test check_result(registry_dir, "registry1")

# Add 29 versions of the Flux project files and check against `registry2`.
for n = 1:29
    prepare_package(packages_dir, "Flux$(n).toml")
    using Flux
    register(Flux, registry = registry_dir,
             gitconfig = TEST_GITCONFIG, push = false)
end
@test check_result(registry_dir, "registry2")

# Add 15 versions of the Images project files and check against `registry3`.
for n = 1:15
    prepare_package(packages_dir, "Images$(n).toml")
    using Images
    register(Images, registry = registry_dir,
             gitconfig = TEST_GITCONFIG, push = false)
end
@test check_result(registry_dir, "registry3")

# Start over with a fresh registry and add all 46 project files but in
# shuffled order. Check that this also matches `registry3`.
registry_dir = joinpath(testdir, "test2", "TestRegistry")
create_registry(registry_dir, "git@example.com:Julia/TestRegistry.git",
                description = "For testing purposes only.",
                uuid = "ed6ca2f6-392d-11ea-3224-d3daf7fee369",
                gitconfig = TEST_GITCONFIG, push = false)
project_files = vcat("FirstTest1.toml",
                     ["Flux$(n).toml" for n = 1:29],
                     ["Images$(n).toml" for n = 1:15])
Random.seed!(13)
shuffle!(project_files)
for project_file in project_files
    prepare_package(packages_dir, project_file)
    package = match(r"[a-zA-Z]+", project_file).match
    # Register by path instead of module in this test.
    register(joinpath(packages_dir, package), registry = registry_dir,
             gitconfig = TEST_GITCONFIG, push = false)
end
@test check_result(registry_dir, "registry3")

# Trying to register an already existing version with different content.
prepare_package(packages_dir, "Flux30.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Flux"),
                                     registry = registry_dir,
                                     gitconfig = TEST_GITCONFIG,
                                     push = false)

# Parse error in compat section.
prepare_package(packages_dir, "Broken1.toml")
if VERSION < v"1.2"
    @test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
else
    @test_throws Pkg.Types.PkgError register(joinpath(packages_dir, "Broken"),
                                             registry = registry_dir,
                                             gitconfig = TEST_GITCONFIG,
                                             push = false)
end

# Trying to change name (UUID remains).
prepare_package(packages_dir, "Fluxx1.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Fluxx"),
                                     registry = registry_dir,
                                     gitconfig = TEST_GITCONFIG,
                                     push = false)

# Trying to change UUID.
prepare_package(packages_dir, "Flux31.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Flux"),
                                     registry = registry_dir,
                                     gitconfig = TEST_GITCONFIG,
                                     push = false)

# Depends on itself.
prepare_package(packages_dir, "Broken2.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                     registry = registry_dir,
                                     gitconfig = TEST_GITCONFIG,
                                     push = false)

# Incorrect name of dependency.
prepare_package(packages_dir, "Broken3.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                     registry = registry_dir,
                                     gitconfig = TEST_GITCONFIG,
                                     push = false)

# TODO: This should really be an error but RegistryTools 1.3.0 doesn't catch it.
# Incorrect UUID of dependency.
prepare_package(packages_dir, "Broken4.toml")
register(joinpath(packages_dir, "Broken"), registry = registry_dir,
         gitconfig = TEST_GITCONFIG, push = false)

# Incorrect UUID of stdlib.
prepare_package(packages_dir, "Broken5.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                     registry = registry_dir,
                                     gitconfig = TEST_GITCONFIG,
                                     push = false)

# Change the git remote before registration and verify that the
# registered repo is not changed.
prepare_package(packages_dir, "Flux32.toml")
package_dir = joinpath(packages_dir, "Flux")
git = gitcmd(package_dir, TEST_GITCONFIG)
package_file = joinpath(registry_dir, "F", "Flux", "Package.toml")
old_repo = TOML.parsefile(package_file)["repo"]
new_repo = "https://example.com/Julia/Flux.jl.git"
run(`$git remote set-url origin $(new_repo)`)
register(joinpath(packages_dir, "Flux"), registry = registry_dir,
         gitconfig = TEST_GITCONFIG, push = false)
@test TOML.parsefile(package_file)["repo"] == old_repo

# Register with explicit repo argument and verify that the registered
# repo is updated.
prepare_package(packages_dir, "Flux33.toml")
register(joinpath(packages_dir, "Flux"), registry = registry_dir,
         repo = new_repo, gitconfig = TEST_GITCONFIG, push = false)
@test TOML.parsefile(package_file)["repo"] == new_repo

pop!(LOAD_PATH)

# Register a package in a subdirectory of a git repository. Also add
# some dirt outside the subdirectory to verify that it is ignored.
prepare_package(packages_dir, "SubdirTest1.toml", "subdir")
write(joinpath(packages_dir, "SubdirTest", "README.md"), "dirty")
register(joinpath(packages_dir, "SubdirTest", "subdir"),
         registry = registry_dir, gitconfig = TEST_GITCONFIG, push = false)
package_file = joinpath(registry_dir, "S", "SubdirTest", "Package.toml")
@test TOML.parsefile(package_file)["subdir"] == "subdir"

# Register a package with a JuliaProject.toml rather than a Project.toml.
prepare_package(packages_dir, "JuliaProjectTest1.toml",
                use_julia_project = true)
register(joinpath(packages_dir, "JuliaProjectTest"), registry = registry_dir,
         gitconfig = TEST_GITCONFIG, push = false)
@test isfile(joinpath(registry_dir, "J", "JuliaProjectTest", "Package.toml"))

# Test automatic push functionality. The sequence of events is:
# 1. Create a bare "upstream" repository.
# 2. Create a new registry with the upstream as repo and `push = true`.
# 3. Register a package with `push = true`.
# 4. Verify that the registry and the upstream repo has the same two commits.
upstream_dir = joinpath(testdir, "upstream")
mkpath(upstream_dir)
upstream_git = gitcmd(upstream_dir, TEST_GITCONFIG)
run(`$(upstream_git) init --bare`)
registry_push_dir = joinpath(testdir, "TestRegistryPush")
create_registry(registry_push_dir, "file://$(upstream_dir)", push = true,
                gitconfig = TEST_GITCONFIG)
downstream_git = gitcmd(registry_push_dir, TEST_GITCONFIG)
register(joinpath(packages_dir, "FirstTest"), registry = registry_push_dir,
         push = true, gitconfig = TEST_GITCONFIG)
@test readchomp(`$(downstream_git) log`) == readchomp(`$(upstream_git) log`)
@test length(readlines(`$(upstream_git) log --format=oneline`)) == 2



# Additional tests of `find_package_path` and `find_registry_path`.
# Many of these have the purpose to cover error cases, making them
# somewhat contrived. Another complicating factor is that some of the
# call variants have to interact with the package environment,
# including registries, of the running Julia process.

# Prepare by adding the registry used in previous tests.
# TODO: Needed in Julia 1.7.0-DEV.1046. Check if the `mkdir` can be
# removed for the final Julia 1.7.
mkdir(joinpath(depot_path, "registries"))
Pkg.Registry.add(RegistrySpec(path = registry_dir))

# Use Multibreak as Guinea pig. The sleep is a Travis workaround. See
# a later comment. This also tests automatically choosing the only
# installed registry for a new package.
sleep(1)
register("Multibreak", push = false, gitconfig = TEST_GITCONFIG)

# Directory already exists. Also tests code handling a trailing slash.
create_registry("TestRegistry2", "", gitconfig = TEST_GITCONFIG, push = false)
@test_throws ErrorException create_registry("TestRegistry2/", "",
                                            gitconfig = TEST_GITCONFIG,
                                            push = false)

# Not a developed package.
@test_throws ErrorException find_package_path("AutoHashEquals")

# Not a registered package.
pkg = Pkg.Types.Project(Dict("name" => "UUIDs",
                             "uuid" => "cf7118a7-6976-5b1a-9a39-7adc72f591a4"))
@test_throws ErrorException find_registry_path(nothing, pkg)

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

# Workaround for bad `mtime` resolution of 1 second on MacOS workers
# on Travis.
#
# The issue is that `read_registry` caches its results with respect to
# the file `mtime`. Since `read_registry` is called from within
# `register`, the old data will be read into the cache. If the new
# data is written close enough to the previous registry update so that
# `mtime` does not change, subsequent `read_registry` will keep using
# the old data from the cache.
sleep(1)

# More than one registry contains the package.
register("Multibreak", registry = "TestRegistry2",
         repo = "file://$(packages_dir)/FirstTest",
         gitconfig = TEST_GITCONFIG, push = false)
@test_throws ErrorException find_registry_path(nothing, pkg)

# Dirty the registry repository and try to register a package.
registry_path = find_registry_path("TestRegistry2")
filename = joinpath(registry_path, "Registry.toml")
open(filename, "a") do io
    write(io, "\n")
end
@test_throws ErrorException register("Multibreak", registry = "TestRegistry2",
                                     gitconfig = TEST_GITCONFIG, push = false)

# Remove Project.toml from a package and try to register.
mv(joinpath(package_path, "Project.toml"),
   joinpath(package_path, "Project.txt"))
@test_throws ErrorException register("Multibreak", registry = "TestRegistry2",
                                     gitconfig = TEST_GITCONFIG, push = false)
mv(joinpath(package_path, "Project.txt"),
   joinpath(package_path, "Project.toml"))

# Dirty the package repository and try to register the package.
package_path = find_package_path("Multibreak")
filename = joinpath(package_path, "README.md")
open(filename, "a") do io
    write(io, "\n")
end
@test_throws ErrorException register("Multibreak", registry = "TestRegistry2",
                                     gitconfig = TEST_GITCONFIG, push = false)

# Current active environment is not a package.
@test_throws ErrorException find_package_path(nothing)

# Activate a package directory and find it with `find_package_path`.
Pkg.activate("Multibreak")
if Base.Sys.islinux()
    @test find_package_path(nothing) == package_path
else
    # Workaround for CI path weirdnesses on Windows and Mac.
    @test splitpath(package_path)[end-2:end] == splitpath(find_package_path(nothing))[end-2:end]
end

if VERSION < v"1.2"
    rm(depot_path, recursive = true)
end
