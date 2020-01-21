"""
# LocalRegistry

Create and maintain local registries for Julia packages. This package
is intended to provide a simple but manual workflow for maintaining
small local registries (private or public) without making any
assumptions about how the registry or the packages are hosted.

Registry creation is done by the function `create_registry`.

Registration of new and updated packages is done by the function `register`.
"""
module LocalRegistry

using RegistryTools: RegistryTools, gitcmd, Compress
using UUIDs: uuid4
using LibGit2
using Pkg: Pkg, TOML

export create_registry, register

"""
    create_registry(path, repo; description = nothing)

Create a registry at the local directory `path` and with repository
URL `repo`. Optionally add a description of the purpose of the
registry with the keyword argument `description`. The last component of
`path` is used as name of the registry.

Note: This will only prepare the registry locally. Review the result
and `git push` it manually.
"""
function create_registry(path, repo; description = nothing,
                         gitconfig::Dict = Dict(), uuid = nothing)
    path = abspath(path)
    name = basename(path)
    if isempty(name)
        # If `path` ends with a slash, `basename` becomes empty and
        # the slash needs to be peeled off with `dirname`.
        name = basename(dirname(path))
    end
    if isdir(path) || isfile(path)
        throw("$path already exists.")
    end
    mkpath(path)

    # The only reason for the `uuid` function argument is to allow
    # deterministic testing of the package.
    if isnothing(uuid)
        uuid = string(uuid4())
    end
    
    registry_data = RegistryTools.RegistryData(name, uuid, repo = repo,
                                               description = description)
    RegistryTools.write_registry(joinpath(path, "Registry.toml"), registry_data)

    git = gitcmd(path, gitconfig)
    run(`$git init -q`)
    run(`$git add Registry.toml`)
    run(`$git commit -qm 'Create registry.'`)
    run(`$git remote add origin $repo`)

    return path
end

"""
    register(package, registry)

Register the new `package` in the registry `registry`. The version
number and other information is obtained from the package's
`Project.toml`.

    register(package)

Register a new version of `package`.  The version number is obtained
from the package's `Project.toml`.

Note: In both cases this will only update the registry locally. Review
the result and `git push` it manually. The package must live in a git
working copy, e.g. having been cloned by `Pkg.develop`.

`package` can be specified in the following ways:
* By package name. The package must be available in the active `Pkg`
  environment.
* By path. This is distinguished from package name by having more than
  one path component. A path in the current working directory can be
  specified by starting with `"./"`.
* By module. It needs to first be loaded by `using` or `import`.

`registry` can be specified by name or by path in the same way as
`package`. If omitted or `nothing`, it will be automatically located
by `package`.

*Keyword arguments*

    register(package, registry; commit = true, repo = nothing, gitconfig = Dict())

* `commit`: If `false`, only make the changes to the registry but do not commit.
* `repo`: Specify the package repository explicitly. Otherwise looked up as the `git remote` of the package.
* `gitconfig`: Optional configuration parameters for the `git` command.
"""
function register(package::Union{Module, AbstractString},
                  registry::Union{Nothing, AbstractString} = nothing;
                  repo = nothing, commit = true, gitconfig::Dict = Dict())
    # Find and read the `Project.toml` for the package.
    package_path = find_package_path(package)
    pkg = Pkg.Types.read_project(joinpath(package_path, "Project.toml"))
    if isnothing(pkg.name)
        throw("$(package) does not have a Project.toml file")
    end

    registry_path = find_registry_path(registry, pkg)
    if LibGit2.isdirty(LibGit2.GitRepo(registry_path))
        throw("Registry repo is dirty. Stash or commit files.")
    end

    # Compute the tree hash for the package.
    tree_hash = get_tree_hash(package_path, gitconfig)

    # Use the `repo` argument or check for the git remote if not provided.
    if isnothing(repo)
        package_repo = get_remote_repo(package_path, gitconfig)
    else
        package_repo = repo
    end

    @info "Registering package" package_path registry_path package_repo uuid=pkg.uuid version=pkg.version tree_hash
    clean_registry = true

    git = gitcmd(registry_path, gitconfig)
    try
        package_path = get_package_path(registry_path, pkg)
        update_package_data(pkg, registry_path, package_repo, package_path, tree_hash)
        if commit
            commit_registry(pkg, package_path, package_repo, tree_hash, git)
        end
    finally
        if clean_registry
            run(`$git reset --hard`)
        end
    end

    return
end

# If the package is provided as a module, directly find the package
# path from the loaded code. This works both if the module is loaded
# from the current package environment or found in LOAD_PATH.
function find_package_path(package::Module)
    return dirname(dirname(pathof(package)))
end

# A string argument is either interpreted as a path or as a package
# name, decided by the number of components returned by `splitpath`.
#
# If the package is given by name, it must be available in the current
# package environment as a developed package.
function find_package_path(package_name::AbstractString)
    if length(splitpath(package_name)) > 1
        if !isdir(package_name)
            error("Package path $(package_name) does not exist.")
        end
        return abspath(expanduser(package_name))
    end

    ctx = Pkg.Types.Context()
    if !haskey(ctx.env.project.deps, package_name)
        error("Unknown package $package_name.")
    end
    pkg_uuid = ctx.env.project.deps[package_name]
    pkg_path = ctx.env.manifest[pkg_uuid].path
    if isnothing(pkg_path)
        error("Package must be developed to be registered.")
    end
    return pkg_path
end

function find_registry_path(registry::AbstractString, pkg)
    if length(splitpath(registry)) > 1
        return abspath(expanduser(registry))
    end

    all_registries = Pkg.Types.collect_registries()
    matching_registries = filter(r -> r.name == registry, all_registries)
    if isempty(matching_registries)
        error("Registry $(registry) not found.")
    end

    return first(matching_registries).path
end

function find_registry_path(registry::Nothing, pkg)
    all_registries = Pkg.Types.collect_registries()

    matching_registries = filter(all_registries) do reg_spec
        reg_data = Pkg.Types.read_registry(joinpath(reg_spec.path,
                                                    "Registry.toml"))
        haskey(reg_data["packages"], string(pkg.uuid))
    end

    if isempty(matching_registries)
        error("Package $(pkg.name) not found in any registry. Please specify in which registry you want to register it.")
    elseif length(matching_registries) > 1
        error("Package $(pkg.name) is registered in more than one registry, please specify in which you want to register the package.")
    end

    return first(matching_registries).path
end

function get_tree_hash(package_path, gitconfig)
    git = gitcmd(package_path, gitconfig)
    return read(`$git log --pretty=format:%T -1`, String)
end

function get_remote_repo(package_path, gitconfig)
    git = gitcmd(package_path, gitconfig)
    remote_name = split(readchomp(`$git remote`), '\n')
    length(remote_name) > 1 && throw("Repository has multiple remotes.")
    remote_name[1] == "" && throw("Repository does not have a remote.")
    return readchomp(`$git remote get-url $(remote_name[1])`)
end

# Find the package in the repository and return its path. If not
# previously registered, first create its directory.
function get_package_path(registry_path, pkg::Pkg.Types.Project)
    @debug("find package in registry")
    registry_file = joinpath(registry_path, "Registry.toml")
    registry_data = RegistryTools.parse_registry(registry_file)

    uuid = string(pkg.uuid)
    if haskey(registry_data.packages, uuid)
        package_data = registry_data.packages[uuid]
        if package_data["name"] != pkg.name
            err = "Changing package names not supported yet"
            @debug(err)
            throw(err)
        end
        package_path = joinpath(registry_path, package_data["path"])
    else
        @debug("Package with UUID: $uuid not found in registry, checking if UUID was changed")
        if pkg.name in (v["name"] for (k, v) in registry_data.packages)
            err = "Changing UUIDs is not allowed"
            @debug(err)
            throw(err)
        end

        @debug("Creating directory for new package $(pkg.name)")
        first_letter = uppercase(pkg.name[1:1])
        relative_package_path = joinpath(first_letter, pkg.name)
        package_path = joinpath(registry_path, relative_package_path)
        mkpath(package_path)

        # Do not use joinpath to construct the stored path. Should be
        # a forward slash independent of platform.
        registry_data.packages[uuid] = Dict("name" => pkg.name,
                                            "path" => string(first_letter, "/",
                                                             pkg.name))
        RegistryTools.write_registry(registry_file, registry_data)
    end

    return package_path
end

function update_package_data(pkg::Pkg.Types.Project, registry_path,
                             package_repo, package_path, tree_hash)
    # Package file.
    RegistryTools.update_package_file(pkg, package_repo, package_path)

    # Versions file.
    update_versions_file(pkg, package_path, tree_hash)

    # Dependencies file.
    check_dependencies(pkg, registry_path)
    update_deps_file(pkg, package_path)

    # Compatibilities file.
    check_compatibilities(pkg)
    update_compat_file(pkg, package_path)

    return
end

# Same code as in RegistryTools but without the RegBranch version checks.
function update_versions_file(pkg::Pkg.Types.Project,
                              package_path::AbstractString,
                              tree_hash::AbstractString)
    versions_file = joinpath(package_path, "Versions.toml")
    versions_data = isfile(versions_file) ? TOML.parsefile(versions_file) : Dict()
    versions = sort!([VersionNumber(v) for v in keys(versions_data)])

    version_info = Dict{String,Any}("git-tree-sha1" => string(tree_hash))
    versions_data[string(pkg.version)] = version_info

    open(versions_file, "w") do io
        TOML.print(io, versions_data; sorted=true, by=x->VersionNumber(x))
    end
    return
end

function check_dependencies(pkg::Pkg.Types.Project, registry_path)
    @debug("Verifying package name and uuid in deps")
    registry_file = joinpath(registry_path, "Registry.toml")
    registry_data = TOML.parsefile(registry_file)
    for (k, v) in pkg.deps
        u = string(v)
        if haskey(registry_data["packages"], u)
            name_in_reg = registry_data["packages"][u]["name"]
            if name_in_reg != k
                err = "Error in `[deps]`: UUID $u refers to package '$name_in_reg' in registry but deps file has '$k'"
                throw(err)
            end
        elseif haskey(BUILTIN_PKGS, k)
            if BUILTIN_PKGS[k] != u
                err = "Error in `[deps]`: UUID $u for package $k should be $(BUILTIN_PKGS[k])"
                throw(err)
            end
        else
#             err = "Error in `[deps]`: Package '$k' with UUID: $u not found in registry or stdlib"
#             throw(err)
        end
    end
end    

function update_deps_file(pkg::Pkg.Types.Project, package_path)
    deps_file = joinpath(package_path, "Deps.toml")
    if isfile(deps_file)
        deps_data = Compress.load(deps_file)
    else
        deps_data = Dict()
    end

    deps_data[pkg.version] = pkg.deps
    Compress.save(deps_file, deps_data)
end

function check_compatibilities(pkg::Pkg.Types.Project)
    for (p, v) in pkg.compat
        try
            ver = Pkg.Types.semver_spec(v)
            if p == "julia" && any(map(x->!isempty(intersect(Pkg.Types.VersionRange("0-0.6"),x)), ver.ranges))
                err = "Julia version < 0.7 not allowed in `[compat]`"
                @debug(err)
                throw(err)
            end
        catch ex
            if isa(ex, ArgumentError)
                err = "Error in `[compat]`: $(ex.msg)"
                @debug(err)
                throw(err)
            else
                rethrow(ex)
            end
        end
    end
end

function update_compat_file(pkg::Pkg.Types.Project, package_path)
    compat_file = joinpath(package_path, "Compat.toml")
    if isfile(compat_file)
        compat_data = Compress.load(compat_file)
    else
        compat_data = Dict()
    end

    d = Dict()
    for (n, v) in pkg.compat
        spec = Pkg.Types.semver_spec(v)
        # The call to map(versionrange, ) can be removed once support
        # for older Julia versions than 1.3 are dropped.
        ranges = map(r->versionrange(r.lower, r.upper), spec.ranges)
        ranges = Pkg.Types.VersionSpec(ranges).ranges # this combines joinable ranges
        d[n] = length(ranges) == 1 ? string(ranges[1]) : map(string, ranges)
    end
    compat_data[pkg.version] = d
    Compress.save(compat_file, compat_data)
end

function versionrange(lo::Pkg.Types.VersionBound, hi::Pkg.Types.VersionBound)
    lo.t == hi.t && (lo = hi)
    return Pkg.Types.VersionRange(lo, hi)
end

function commit_registry(pkg::Pkg.Types.Project, package_path, package_repo, tree_hash, git)
    @debug("commit changes")
    message = """
    New version: $(pkg.name) v$(pkg.version)

    UUID: $(pkg.uuid)
    Repo: $(package_repo)
    Tree: $(string(tree_hash))
    """
    run(`$git add --all`)
    if occursin("nothing to commit, working tree clean",
                read(`$git status`, String))
        @info("nothing to commit")
    else
        run(`$git commit -qm $message`)
    end
end

const BUILTIN_PKGS = Dict("Pkg"=>"44cfe95a-1eb2-52ea-b672-e2afdf69b78f",
                          "Statistics"=>"10745b16-79ce-11e8-11f9-7d13ad32a3b2",
                          "Test"=>"8dfed614-e22c-5e08-85e1-65c5234f0b40",
                          "CRC32c"=>"8bf52ea8-c179-5cab-976a-9e18b702a9bc",
                          "Random"=>"9a3f8284-a2c9-5f02-9a11-845980a1fd5c",
                          "Libdl"=>"8f399da3-3557-5675-b5ff-fb832c97cbdb",
                          "UUIDs"=>"cf7118a7-6976-5b1a-9a39-7adc72f591a4",
                          "Distributed"=>"8ba89e20-285c-5b6f-9357-94700520ee1b",
                          "Serialization"=>"9e88b42a-f829-5b0c-bbe9-9e923198166b",
                          "DelimitedFiles"=>"8bb1440f-4735-579b-a4ab-409b98df4dab",
                          "LinearAlgebra"=>"37e2e46d-f89d-539d-b4ee-838fcccc9c8e",
                          "FileWatching"=>"7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee",
                          "SharedArrays"=>"1a1011a3-84de-559e-8e89-a11a2f7dc383",
                          "Base64"=>"2a0f44e3-6c83-55bd-87e4-b1978d98bd5f",
                          "SparseArrays"=>"2f01184e-e22b-5df5-ae63-d93ebab69eaf",
                          "Profile"=>"9abbd945-dff8-562f-b5e8-e1ebf5ef1b79",
                          "Mmap"=>"a63ad114-7e13-5084-954f-fe012c677804",
                          "Unicode"=>"4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5",
                          "InteractiveUtils"=>"b77e0a4c-d291-57a0-90e8-8db25a27a240",
                          "Future"=>"9fa8497b-333b-5362-9e8d-4d0656e87820",
                          "Sockets"=>"6462fe0b-24de-5631-8697-dd941f90decc",
                          "Printf"=>"de0858da-6303-5e67-8744-51eddeeeb8d7")

end
