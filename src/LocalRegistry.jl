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

using RegistryTools: RegistryTools, gitcmd, Compress,
                     check_and_update_registry_files, ReturnStatus, haserror,
                     find_registered_version
using UUIDs: uuid4
using LibGit2
using Pkg: Pkg, TOML

export create_registry, register

"""
    create_registry(name, repo; description = nothing)
    create_registry(path, repo; description = nothing)

Create a registry with the given `name` or at the local directory
`path`, and with repository URL `repo`. Optionally add a description
of the purpose of the registry with the keyword argument
`description`. The first argument is interpreted as a path if it has
more than one path component and otherwise as a name. If a path is
given, the last path component is used as the name of the registry. If
a name is given, it is created in the standard registry location. In
both cases the registry path must not previously exist.

Note: This will only prepare the registry locally. Review the result
and `git push` it manually.
"""
function create_registry(name_or_path, repo; description = nothing,
                         gitconfig::Dict = Dict(), uuid = nothing)
    if length(splitpath(name_or_path)) > 1
        path = abspath(expanduser(name_or_path))
    else
        path = joinpath(first(DEPOT_PATH), "registries", name_or_path)
    end
    name = basename(path)
    if isempty(name)
        # If `path` ends with a slash, `basename` becomes empty and
        # the slash needs to be peeled off with `dirname`.
        name = basename(dirname(path))
    end
    if isdir(path) || isfile(path)
        error("$path already exists.")
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
    @info "Created registry in directory $(path)"

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
        error("$(package) does not have a Project.toml file")
    end

    registry_path = find_registry_path(registry, pkg)
    if LibGit2.isdirty(LibGit2.GitRepo(registry_path))
        error("Registry repo is dirty. Stash or commit files.")
    end

    # Compute the tree hash for the package.
    tree_hash = get_tree_hash(package_path, gitconfig)

    # Check if this exact package has already been registered. Do
    # nothing and don't error in that case.
    if find_registered_version(pkg, registry_path) == tree_hash
        @info "This version has already been registered and is unchanged."
        return
    end

    # Use the `repo` argument or check for the git remote if not provided.
    if isnothing(repo)
        package_repo = get_remote_repo(package_path, gitconfig)
    else
        package_repo = repo
    end

    @info "Registering package" package_path registry_path package_repo uuid=pkg.uuid version=pkg.version tree_hash
    clean_registry = true

    git = gitcmd(registry_path, gitconfig)
    status = ReturnStatus()
    try
        check_and_update_registry_files(pkg, package_repo, tree_hash,
                                        registry_path, String[], status)
        haserror(status)
        if !haserror(status)
            if commit
                commit_registry(pkg, package_path, package_repo, tree_hash, git)
            end
            clean_registry = false
        end
    finally
        if clean_registry
            run(`$git reset --hard`)
            run(`$git clean -f -d`)
        end
    end

    # Registration failed. Explain to the user what happened.
    if haserror(status)
        error(explain_registration_error(status))
    end

    return
end

function explain_registration_error(status)
    for triggered_check in status.triggered_checks
        check = triggered_check.id
        data = triggered_check
        if check == :version_exists
            return "Version $(data.version) has already been registered and the content has changed."
        elseif check == :change_package_name
            return "Changing package name is not supported."
        elseif check == :change_package_uuid
            return "Changing package UUID is not allowed."
        elseif check == :package_self_dep
            return "The package depends on itself."
        elseif check == :name_mismatch
            return "Error in (Julia)Project.toml: UUID $(data.uuid) refers to package '$(data.reg_name)' in registry but Project.toml has '$(data.project_name)'."
        elseif check == :wrong_stdlib_uuid
            return "Error in (Julia)Project.toml: UUID $(data.project_uuid) for package $(data.name) should be $(data.stdlib_uuid)"
        elseif check == :package_url_missing
            return "No repo URL provided for a new package."
        elseif check == :unexpected_registration_error
            return "Unexpected registration error."
        end
    end
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

function find_registry_path(registry::AbstractString, pkg::Pkg.Types.Project)
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

function find_registry_path(registry::Nothing, pkg::Pkg.Types.Project)
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
    length(remote_name) > 1 && error("Repository has multiple remotes.")
    remote_name[1] == "" && error("Repository does not have a remote.")
    return readchomp(`$git remote get-url $(remote_name[1])`)
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
    run(`$git commit -qm $message`)
end

end
