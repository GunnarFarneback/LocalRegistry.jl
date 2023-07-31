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
                     find_registered_version, Project
using UUIDs: uuid4
import Pkg
import TOML

export create_registry, register

# Note: The `uuid` keyword argument is intentionally omitted from the
# documentation string since it's not intended for users.
"""
    create_registry(name, repo)
    create_registry(path, repo)

Create a registry with the given `name` or at the local directory
`path`, and with repository URL or path `repo`. The first argument is
interpreted as a path if it has more than one path component and
otherwise as a name. If a path is given, the last path component is
used as the name of the registry. If a name is given, it is created in
the standard registry location. In both cases the registry path must
not previously exist. The repository must be able to be pushed to,
for example by being a bare repository.

*Keyword arguments*

    create_registry(...; description = nothing, push = false,
                    branch = nothing, gitconfig = Dict())

* `description`: Optional description of the purpose of the registry.
* `push`: If `false`, the registry will only be prepared locally.
  Review the result and `git push` it manually. If `true`, the upstream
  repository is first cloned (if possible) before creating the registry.
* `branch`: Create the registry in the specified branch. Default is to
  use the upstream branch if `push` is `true` and otherwise the default
  branch name configured for `git init`.
* `gitconfig`: Optional configuration parameters for the `git` command.
"""
function create_registry(name_or_path, repo; description = nothing,
                         gitconfig::Dict = Dict(), uuid = nothing,
                         push = false, branch = nothing)
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

    git = gitcmd(path, gitconfig)
    git_repo_cloned = false

    if push
        # The upstream repo may or may not exist. Even if it doesn't
        # yet exist, it might be possible to push to it. E.g. GitLab
        # can create a repository on demand when pushed to.
        try
            run(`$git clone -q $repo .`)
            git_repo_cloned = true
        catch
        end
    end

    # The only reason for the `uuid` keyword argument is to allow
    # deterministic testing of the package.
    if isnothing(uuid)
        uuid = string(uuid4())
    end

    registry_data = RegistryTools.RegistryData(name, uuid, repo = repo,
                                               description = description)
    RegistryTools.write_registry(joinpath(path, "Registry.toml"), registry_data)

    if !git_repo_cloned
        run(`$git init -q`)
        run(`$git remote add origin $repo`)
    end

    if !isnothing(branch)
        run(`$git checkout -b $branch`)
    end

    run(`$git add Registry.toml`)
    run(`$git commit -qm 'Create registry.'`)
    if push
        run(`$git push -u origin HEAD`)
    end
    @info "Created registry in directory $(path)"

    return path
end

"""
    register(package; registry = registry)
    register(package)
    register()

Register `package`. If `package` is omitted, register the package in
the currently active project or in the current directory in case the
active project is not a package.

If `registry` is not specified:
* For registration of a new version, automatically locate the registry
  where `package` is available.
* For registration of a new package, fail unless exactly one registry
  other than General is installed, in which case that registry is
  used.

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

`registry` can be specified in the following ways:
* By registry name. This must be an exact match to the name of one of
  the installed registries.
* By path. This must be an existing local path.
* By URL to its remote location. Everything which doesn't match one of
  the previous options is assumed to be a URL.

If `registry` is specified by URL, or the found registry is not a git
clone (i.e. obtained from a package server), a temporary git clone
will be used to perform the registration. In this case `push` must be
`true`.

*Keyword arguments*

    register(package; registry = nothing, commit = true, push = true,
             branch = nothing, repo = nothing, ignore_reregistration = false,
             gitconfig = Dict(), create_gitlab_mr = false)

* `registry`: Name, path, or URL of registry.
* `commit`: If `false`, only make the changes to the registry but do not commit. Additionally the registry is allowed to be dirty in the `false` case.
* `push`: If `true`, push the changes to the registry repository automatically. Ignored if `commit` is false.
* `branch`: Branch name to use for the registration.
* `repo`: Specify the package repository explicitly. Otherwise looked up as the `git remote` of the package the first time it is registered.
* `ignore_reregistration`: If `true`, do not raise an error if a version has already been registered (with different content), only an informational message.
* `gitconfig`: Optional configuration parameters for the `git` command.
* `create_gitlab_mr`: If `true` sends git push options to create a GitLab merge request. Requires `commit` and `push` to be true.
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
                     commit = true, push = true, branch = nothing,
                     repo = nothing, ignore_reregistration = false,
                     gitconfig::Dict = Dict(), create_gitlab_mr = false)
    # Find and read the `Project.toml` for the package. First look for
    # the alternative `JuliaProject.toml`.
    package_path = find_package_path(package)
    local pkg
    for project_file in Base.project_names
        pkg = Project(joinpath(package_path, project_file))
        if !isnothing(pkg.name)
            break
        end
    end
    if isnothing(pkg.name)
        error("$(package) does not have a Project.toml or JuliaProject.toml file")
    end
    if isnothing(pkg.uuid)
        error("$(package) is not a valid package (no UUID)")
    end
    if isnothing(pkg.version)
        error("$(package) is not a valid package (no version)")
    end
    pkg_filename = "$(pkg.name).jl"
    if !isfile(joinpath(package_path, "src", pkg_filename))
        error("$(package) is not a valid package (no src/$(pkg_filename))")
    end


    # If the package directory is dirty, a different version could be
    # present in Project.toml.
    if is_dirty(package_path, gitconfig)
        error("Package directory is dirty. Stash or commit files.")
    end

    registry_path = find_registry_path(registry, pkg)
    registry_path, is_temporary = check_git_registry(registry_path, gitconfig)
    if is_temporary && (!commit || !push)
        error("Need to use a temporary git clone of the registry, but commit or push is set to false.")
    end
    if is_dirty(registry_path, gitconfig)
        if commit
            error("Registry directory is dirty. Stash or commit files.")
        else
            @info("Note: registry directory is dirty.")
        end
    end

    # Compute the tree hash for the package and the subdirectory
    # location within the git repository. For normal packages living
    # at the top level of the repository, `subdir` will be the empty
    # string. Also obtain the commit hash for later use.
    tree_hash, subdir, commit_hash = get_tree_hash(package_path, gitconfig)

    # Check if this version has already been registered. Note, if it
    # was already registered and the contents has changed and
    # `ignore_reregistration` is false, this will be caught later.
    registered_version = find_registered_version(pkg, registry_path)
    if registered_version == tree_hash
        @info "This version has already been registered and is unchanged."
        return false
    elseif !isempty(registered_version) && ignore_reregistration
        @info "This version has already been registered. Registration request is ignored. Update the version number to register a new version."
        return false
    end

    # Is this a new package?
    new_package = !has_package(registry_path, pkg)

    # Use the `repo` argument or, if this is a new package
    # registration, check for the git remote. If `repo` is `nothing`
    # and this is an existing package, the repository information will
    # not be updated.
    if isnothing(repo)
        if new_package
            package_repo = get_remote_repo(package_path, gitconfig)
        else
            package_repo = ""
        end
    else
        package_repo = repo
    end

    @info "Registering package" package_path registry_path package_repo uuid=pkg.uuid version=pkg.version tree_hash subdir
    clean_registry = true
    clean_branch = false

    push_options = String[]
    if create_gitlab_mr
        if !commit || !push
            error("Neither `commit` nor `push` can be false when `create_gitlab_mr` is set to true.")
        end
        branch, push_options = gitlab(branch, pkg, new_package, package_repo,
                                      commit_hash)
    end

    git = gitcmd(registry_path, gitconfig)
    HEAD = readchomp(`$git rev-parse --verify HEAD`)
    saved_branch = readchomp(`$git rev-parse --abbrev-ref HEAD`)
    remote = readchomp(`$git remote`)
    status = ReturnStatus()
    try
        check_and_update_registry_files(pkg, package_repo, tree_hash,
                                        registry_path, String[], status,
                                        subdir = subdir)
        if !haserror(status)
            if commit
                if !isnothing(branch)
                    run(`$git checkout -b $branch`)
                    clean_branch = true
                end
                commit_registry(pkg, new_package,
                                package_repo, tree_hash, git)
                if push
                    if isnothing(branch)
                        run(`$git push`)
                    else
                        run(`$git push $(push_options) --set-upstream $remote $branch`)
                    end
                end
                run(`$git checkout $(saved_branch)`)
            end
            clean_registry = false
        end
    finally
        if clean_registry
            run(`$git reset --hard $(HEAD)`)
            run(`$git clean -f -d`)
            run(`$git checkout $(saved_branch)`)
        end
        if clean_branch
            run(`$git branch -d $(branch)`)
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

# If the package is omitted,
# * use the active project if it corresponds to a package,
# * otherwise use the current directory.
function find_package_path(::Nothing)
    path = Base.active_project()
    project = TOML.parsefile(path)
    # The active project is considered a package if it has a name and
    # a uuid, which is the definition Pkg uses.
    if haskey(project, "name") && haskey(project, "uuid")
        return dirname(path)
    end

    return pwd()
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

function find_registry_path(registry::AbstractString, ::Project)
    return find_registry_path(registry)
end

function find_registry_path(registry::AbstractString)
    # 1. Does `registry` match the name of one of the installed registries?
    all_registries = collect_registries()
    matching_registries = filter(r -> r.name == registry, all_registries)
    if !isempty(matching_registries)
        return first(matching_registries).path
    end

    # 2. Is `registry` an existing path?
    path = abspath(expanduser(registry))
    if ispath(path)
        return path
    end

    # 3. If not, assume it is a URL.
    return registry
end

function find_registry_path(::Nothing, pkg::Project)
    all_registries = collect_registries()
    all_registries_but_general = filter(r -> r.name != "General",
                                        all_registries)

    matching_registries = filter(all_registries) do reg_spec
        reg_data = TOML.parsefile(joinpath(reg_spec.path, "Registry.toml"))
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

# Starting with Julia 1.4, a registry can either be obtained as a git
# clone of a remote git repository or be downloaded from a Julia
# package server. Starting with Julia 1.7, in the latter case the
# registry can also be stored as a tar archive that hasn't been
# unpacked.
#
# Either way, LocalRegistry must have a git clone to work with, so if
# the registry is not in that form, make a temporary git clone.
function check_git_registry(registry_path_or_url, gitconfig)
    if !ispath(registry_path_or_url)
        # URL given. Use this to make a git clone.
        url = registry_path_or_url
    elseif isdir(joinpath(registry_path_or_url, ".git"))
        # Path is already a git clone. Nothing left to do.
        return registry_path_or_url, false
    else
        # Registry is given as a path but is not a git clone. Find the
        # URL of the registry from Registry.toml.
        if VERSION >= v"1.7"
            # This handles both packed and unpacked registries.
            try
                url = Pkg.Registry.RegistryInstance(registry_path_or_url).repo
            catch
                error("Bad registry path: $(registry_path_or_url)")
            end
        else
            if looks_like_tar_registry(registry_path_or_url)
                error("Non-unpacked registries require Julia 1.7 or later.")
            elseif !isdir(registry_path_or_url)
                error("Bad registry path: $(registry_path_or_url)")
            end
            url = TOML.parsefile(joinpath(registry_path_or_url, "Registry.toml"))["repo"]
        end
    end

    # Make a temporary clone of the registry at `url`. This will be
    # automatically removed when Julia exits.
    path = mktempdir()
    git = gitcmd(path, gitconfig)
    try
        # Note, the output directory `.` effectively means `path`.
        run(`$git clone -q $url .`)
    catch
        error("Failed to make a temporary git clone of $url")
    end
    return path, true
end

function looks_like_tar_registry(path)
    endswith(path, ".toml") || return false
    isfile(path) || return false
    try
        return haskey(TOML.parsefile(path), "git-tree-sha1")
    catch
        return false
    end
end

# This replaces the use of `Pkg.Types.collect_registries`, which was
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
            if isfile(file)
                push!(registries, (name = name, path = joinpath(reg_dir, name)))
            else
                # Packed registry in Julia 1.7+.
                file = joinpath(reg_dir, "$(name).toml")
                if isfile(file)
                    push!(registries,
                          (name = name, path = joinpath(reg_dir,
                                                        "$(name).toml")))
                end
            end
        end
    end
    return registries
end

function has_package(registry_path, pkg::Project)
    registry = TOML.parsefile(joinpath(registry_path, "Registry.toml"))
    return haskey(registry["packages"], string(pkg.uuid))
end

function get_tree_hash(package_path, gitconfig)
    git = gitcmd(package_path, gitconfig)
    subdir = readchomp(`$git rev-parse --show-prefix`)
    tree_hash = readchomp(`$git rev-parse HEAD:$subdir`)
    commit_hash = readchomp(`$git rev-parse HEAD`)
    # Get rid of trailing slash.
    if isempty(basename(subdir))
        subdir = dirname(subdir)
    end
    return tree_hash, subdir, commit_hash
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

function commit_registry(pkg::Project, new_package,
                         package_repo, tree_hash, git)
    @debug("commit changes")
    message = """
    $(commit_title(pkg, new_package))

    UUID: $(pkg.uuid)
    Repo: $(package_repo)
    Tree: $(string(tree_hash))
    """
    run(`$git add --all`)
    run(`$git commit -qm $message`)
end

function commit_title(pkg, new_package)
    registration_type = new_package ? "New package" : "New version"
    return "$(registration_type): $(pkg.name) v$(pkg.version)"
end

# Construct the git push options that will automatically create a PR
# if the registry repo is hosted on GitLab.
function gitlab(branch, pkg, new_package, repo, commit)
    # If `branch` hasn't been set, create a branch name.
    if isnothing(branch)
        branch = string(pkg.name, "/v", pkg.version)
    end

    title = commit_title(pkg, new_package)
    description = """
    * Registering package: $(pkg.name)
    * Repository: $(repo)
    * Version: v$(pkg.version)
    * Commit: $(commit)
    """
    # Tag the user who started the GitLab job
    if haskey(ENV, "GITLAB_USER_LOGIN")
        description = description * "* Triggered by: @$(ENV["GITLAB_USER_LOGIN"])\n"
    end


    # Unfortunately git push options are not allowed to contain
    # newlines. This makes it difficult to create multiline
    # descriptions for the merge request by this mechanism. There's an
    # open issue https://gitlab.com/gitlab-org/gitlab/-/issues/241710
    # to provide some way around that in GitLab.
    #
    # For the time being we use the workaround of replacing the
    # newlines with HTML `<br>` codes. This works but inhibits the
    # markdown rendering of the list, so we also replace the markdown
    # item indicators with unicode bullets to make it look a bit better.
    description = replace(description, "\n" => "<br>")
    description = replace(description, "* " => "• ")

    push_options = ["-o", "merge_request.create"]
    push!(push_options, "-o", "merge_request.title=$title")
    push!(push_options, "-o", "merge_request.description=$description")
    # This is intended for automated workflows, so make it as
    # automatic as possible.
    push!(push_options, "-o", "merge_request.merge_when_pipeline_succeeds")
    # No point keeping registration branches around.
    push!(push_options, "-o", "merge_request.remove_source_branch")

    return branch, push_options
end

end
