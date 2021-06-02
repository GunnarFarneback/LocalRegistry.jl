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

using RegistryTools: RegistryTools, Compress,
                     check_and_update_registry_files, ReturnStatus, haserror,
                     find_registered_version
using UUIDs: uuid4
using Pkg: Pkg, TOML
using Git

export create_registry, register

# Note: The `uuid` keyword argument is intentionally omitted from the
# documentation string since it's not intended for users.
"""
    create_registry(name, repo)
    create_registry(path, repo)

Create a registry with the given `name` or at the local directory
`path`, and with repository URL `repo`. The first argument is
interpreted as a path if it has more than one path component and
otherwise as a name. If a path is given, the last path component is
used as the name of the registry. If a name is given, it is created in
the standard registry location. In both cases the registry path must
not previously exist.

*Keyword arguments*

    create_registry(...; description = nothing, push = false, gitconfig = Dict())

* `description`: Optional description of the purpose of the registry.
* `push`: If `false`, the registry will only be prepared locally. Review the result and `git push` it manually.
* `gitconfig`: Optional configuration parameters for the `git` command.
"""
function create_registry(name_or_path, repo; description = nothing,
                         gitconfig::Dict = Dict(), uuid = nothing,
                         push = false)
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
    if push
        run(`$git push -u origin master`)
    end
    @info "Created registry in directory $(path)"

    return path
end

"""
    register(package, registry = registry)

Register the new `package` in the registry `registry`. The version
number and other information is obtained from the package's
`Project.toml`.

    register(package)

Register a new version of `package`.  The version number is obtained
from the package's `Project.toml`.

    register()

Register a new version of the package in the currently active project.

Notes:
 * By default this will, in all cases, `git push` the updated registry
   to its remote repository. If you prefer to do the push manually,
   use the keyword argument `push = false`.
 * The package must live in a git working copy, e.g. having been
   cloned by `Pkg.develop`.

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

    register(package; registry = nothing, commit = true, push = true,
             repo = nothing, gitconfig = Dict())

* `registry`: Name or path of registry.
* `commit`: If `false`, only make the changes to the registry but do not commit.
* `push`: If `true`, push the changes to the registry repository automatically. Ignored if `commit` is false.
* `repo`: Specify the package repository explicitly. Otherwise looked up as the `git remote` of the package the first time it is registered.
* `gitconfig`: Optional configuration parameters for the `git` command.
"""
function register(package::Union{Nothing, Module, AbstractString} = nothing;
                  registry::Union{Nothing, AbstractString} = nothing,
                  kwargs...)
    do_register(package, registry; kwargs...)
    return
end

# Differs from the above by looser type restrictions on `package` and
# `registry`. Also returns false if there was nothing new to register
# and true if something new was registered.
function do_register(package, registry;
                     commit = true, push = true, repo = nothing,
                     gitconfig::Dict = Dict())
    # Find and read the `Project.toml` for the package. First look for
    # the alternative `JuliaProject.toml`.
    package_path = find_package_path(package)
    local pkg
    for project_file in Base.project_names
        pkg = Pkg.Types.read_project(joinpath(package_path, project_file))
        if !isnothing(pkg.name)
            break
        end
    end
    if isnothing(pkg.name)
        error("$(package) does not have a Project.toml or JuliaProject.toml file")
    end

    # If the package directory is dirty, a different version could be
    # present in Project.toml.
    if is_dirty(package_path, gitconfig)
        error("Package directory is dirty. Stash or commit files.")
    end

    registry_path = find_registry_path(registry, pkg)
    if is_dirty(registry_path, gitconfig)
        error("Registry directory is dirty. Stash or commit files.")
    end

    # Compute the tree hash for the package and the subdirectory
    # location within the git repository. For normal packages living
    # at the top level of the repository, `subdir` will be the empty
    # string.
    tree_hash, subdir = get_tree_hash(package_path, gitconfig)

    # Check if this exact package has already been registered. Do
    # nothing and don't error in that case.
    if find_registered_version(pkg, registry_path) == tree_hash
        @info "This version has already been registered and is unchanged."
        return false
    end

    # Use the `repo` argument or, if this is a new package
    # registration, check for the git remote. If `repo` is `nothing`
    # and this is an existing package, the repository information will
    # not be updated.
    if isnothing(repo)
        if !has_package(registry_path, pkg)
            package_repo = get_remote_repo(package_path, gitconfig)
        else
            package_repo = ""
        end
    else
        package_repo = repo
    end

    @info "Registering package" package_path registry_path package_repo uuid=pkg.uuid version=pkg.version tree_hash subdir
    clean_registry = true

    git = gitcmd(registry_path, gitconfig)
    HEAD = readchomp(`$git rev-parse --verify HEAD`)
    status = ReturnStatus()
    try
        check_and_update_registry_files(pkg, package_repo, tree_hash,
                                        registry_path, String[], status,
                                        subdir = subdir)
        if !haserror(status)
            if commit
                commit_registry(pkg, package_path, package_repo, tree_hash, git)
                if push
                    run(`$git push`)
                end
            end
            clean_registry = false
        end
    finally
        if clean_registry
            run(`$git reset --hard $(HEAD)`)
            run(`$git clean -f -d`)
        end
    end

    # Registration failed. Explain to the user what happened.
    if haserror(status)
        error(explain_registration_error(status))
    end

    return true
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

# This does the same thing as `LibGit2.isdirty(LibGit2.GitRepo(path))`
# but also works when `path` is a subdirectory of a git
# repository. Only dirt within the subdirectory is considered.
function is_dirty(path, gitconfig)
    git = gitcmd(path, gitconfig)
    # TODO: There should be no need for the `-u` option but without it
    # a bogus diff is reported in the tests.
    return !isempty(read(`$git diff-index -u HEAD -- .`))
end

# If the package is omitted, the active project must correspond to a
# package.
function find_package_path(::Nothing)
    path = ""
    if VERSION < v"1.4"
        env = Pkg.Types.EnvCache()
        if !isnothing(env.pkg)
            path = dirname(env.project_file)
        end
    else
        # Pkg.project() was introduced in Julia 1.4 as an experimental
        # feature. Effectively this does the same thing as the code
        # above but is hopefully more future safe.
        project = Pkg.project()
        if project.ispackage
            path = dirname(project.path)
        end
    end

    if path == ""
        error("The active project is not a package.")
    end

    return path
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
    elseif !isabspath(pkg_path)
        # If the package is developed with --local, pkg_path is
        # relative to the project path.
        pkg_path = joinpath(dirname(ctx.env.manifest_file), pkg_path)
    end

    # `pkg_path` might be a relative path, in which case it is
    # relative to the directory of Manifest.toml. If `pkg_path`
    # already is an absolute path, this call does not affect it.
    pkg_path = abspath(dirname(ctx.env.manifest_file), pkg_path)

    return pkg_path
end

function find_registry_path(registry::AbstractString, ::Pkg.Types.Project)
    return find_registry_path(registry)
end

function find_registry_path(registry::AbstractString)
    if length(splitpath(registry)) > 1
        return abspath(expanduser(registry))
    end

    all_registries = collect_registries()
    matching_registries = filter(r -> r.name == registry, all_registries)
    if isempty(matching_registries)
        error("Registry $(registry) not found.")
    end

    return first(matching_registries).path
end

function find_registry_path(::Nothing, pkg::Pkg.Types.Project)
    all_registries = collect_registries()
    all_registries_but_general = filter(r -> r.name != "General",
                                        all_registries)

    matching_registries = filter(all_registries) do reg_spec
        reg_data = Pkg.TOML.parsefile(joinpath(reg_spec.path, "Registry.toml"))
        haskey(reg_data["packages"], string(pkg.uuid))
    end

    if isempty(matching_registries)
        if length(all_registries_but_general) == 1
            return first(all_registries_but_general).path
        else
            error("Package $(pkg.name) not found in any registry. Please specify in which registry you want to register it.")
        end
    elseif length(matching_registries) > 1
        error("Package $(pkg.name) is registered in more than one registry, please specify in which you want to register the new version.")
    end

    return first(matching_registries).path
end

# This replaces the use of `Pkg.Types.collect_registries` which was
# removed in Julia 1.7.
#
# TODO: Once Julia versions before 1.7 are no longer supported,
# consider switching over to use `Pkg.Registry.reachable_registries`
# where this is called.
function collect_registries()
    registries = []
    for depot in Pkg.depots()
        isdir(depot) || continue
        reg_dir = joinpath(depot, "registries")
        isdir(reg_dir) || continue
        for name in readdir(reg_dir)
            file = joinpath(reg_dir, name, "Registry.toml")
            isfile(file) || continue
            push!(registries, (name = name, path = joinpath(reg_dir, name)))
        end
    end
    return registries
end

function has_package(registry_path, pkg::Pkg.Types.Project)
    registry = Pkg.TOML.parsefile(joinpath(registry_path, "Registry.toml"))
    return haskey(registry["packages"], string(pkg.uuid))
end

function get_tree_hash(package_path, gitconfig)
    git = gitcmd(package_path, gitconfig)
    subdir = readchomp(`$git rev-parse --show-prefix`)
    tree_hash = readchomp(`$git rev-parse HEAD:$subdir`)
    # Get rid of trailing slash.
    if isempty(basename(subdir))
        subdir = dirname(subdir)
    end
    return tree_hash, subdir
end

function get_remote_repo(package_path, gitconfig)
    git = gitcmd(package_path, gitconfig)
    remote_names = split(readchomp(`$git remote`), '\n', keepempty=false)
    repos = String[]
    foreach(remote_names) do remote_name
        push!(repos,readchomp(`$git remote get-url $(remote_name)`))
    end
    length(repos) === 0 && error("No repo URL found. Try calling `register` with the keyword `repo` to provide a URL.")
    length(repos) > 1 && error("Multiple repo URLs found. Try calling `register` with the keyword `repo` to provide a URL.\n$(repos)")
    return repos[1]
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

function gitcmd(path::AbstractString, gitconfig::Dict)
    args = ["-C", path]
    for (k, v) in gitconfig
        push!(args, "-c")
        push!(args, "$k=$v")
    end
    return Git.git(args)
end

end
