using LocalRegistry
using Test
using Random

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
                uuid = "ed6ca2f6-392d-11ea-3224-d3daf7fee369")

# Add the FirstTest1 package and check against the stored `registry1`.
prepare_package(packages_dir, "FirstTest1.toml")
using FirstTest
register(FirstTest, registry_dir)
@test check_result(registry_dir, "registry1")

# Reregister the same version of FirstTest to verify that nothing
# happens,
register(FirstTest, registry_dir)
@test check_result(registry_dir, "registry1")

# Add 30 versions of the Flux project files and check against `registry2`.
for n = 1:30
    prepare_package(packages_dir, "Flux$(n).toml")
    using Flux
    register(Flux, registry_dir)
end
@test check_result(registry_dir, "registry2")

# Add 15 versions of the Images project files and check against `registry3`.
for n = 1:15
    prepare_package(packages_dir, "Images$(n).toml")
    using Images
    register(Images, registry_dir)
end
@test check_result(registry_dir, "registry3")

# Start over with a fresh registry and add all 46 project files but in
# shuffled order. Check that this also matches `registry3`.
# Note, allowing addition of out of order versions of the same package
# is quite liberal.
registry_dir = joinpath(testdir, "test2", "TestRegistry")
create_registry(registry_dir, "git@example.com:Julia/TestRegistry.git",
                description = "For testing purposes only.",
                uuid = "ed6ca2f6-392d-11ea-3224-d3daf7fee369")
project_files = vcat("FirstTest1.toml",
                     ["Flux$(n).toml" for n = 1:30],
                     ["Images$(n).toml" for n = 1:15])
Random.seed!(13)
shuffle!(project_files)
for project_file in project_files
    prepare_package(packages_dir, project_file)
    package = match(r"[a-zA-Z]+", project_file).match
    @show project_file
    register(getfield(Main, Symbol(package)), registry_dir)
end
@test check_result(registry_dir, "registry3")

pop!(LOAD_PATH)
