using LocalRegistry
using LocalRegistry: find_package_path, find_registry_path, check_git_registry,
                     do_register
using Test
using Random
using Pkg
using CodecZlib

const TEST_GITCONFIG = Dict(
    "user.name" => "LocalRegistryTests",
    "user.email" => "localregistrytests@example.com",
)

include("utils.jl")

# Since these tests will need to modify active registries and we don't
# want interference from, e.g. the General registry, use a temporary
# DEPOT_PATH. But first add some packages while we have the General
# registry available. These will be used for some tests later.
Pkg.add("AutoHashEquals")
# Same as `pkg"dev --local Multibreak"` but properly using the API function.
Pkg.develop("Multibreak", shared = false)
empty!(DEPOT_PATH)
depot_path = mktempdir(@__DIR__)
push!(DEPOT_PATH, depot_path)

# We don't want Pkg to try to update our local registries since they
# contain fake URLs.
Pkg.UPDATED_REGISTRY_THIS_SESSION[] = true

@testset "Regression tests" begin
    include("regression.jl")
end

@testset "Register tests" begin
    include("register.jl")
end

@testset "Find package path" begin
    include("find_package_path.jl")
end

@testset "Find registry path" begin
    include("find_registry_path.jl")
end

@testset "Check git registry" begin
    include("check_git_registry.jl")
end
