using RegistryTools: gitcmd, Compress
using Pkg: Pkg, TOML

# Read `project_file` and create or update a corresponding bare bones
# package directory under `package_dir`. Commit the changes to git.
#
# Strictly speaking it is only the "Project.toml" file and the src
# file that matter. Additional files are added to make the set up
# somewhat more normal looking.
function prepare_package(packages_dir, project_file, subdir = "")
    project_file = joinpath(@__DIR__, "project_files", project_file)
    project_data = TOML.parsefile(project_file)
    name = project_data["name"]
    version = project_data["version"]
    # Fake repository URL.
    repo = "git@example.com:Julia/$(name).jl.git"
    top_dir = joinpath(packages_dir, name)
    package_dir = joinpath(top_dir, subdir)
    mkpath(package_dir)
    mkpath(joinpath(package_dir, "src"))
    mkpath(joinpath(package_dir, "test"))
    if !isempty(subdir)
        write(joinpath(top_dir, "README.md"), "# Top Level README")
    end
    git = gitcmd(top_dir, TEST_GITCONFIG)
    if !isdir(joinpath(top_dir, ".git"))
        run(`$(git) init -q`)
        run(`$git remote add origin $repo`)
    end
    write(joinpath(package_dir, "Project.toml"), read(project_file, String))
    write(joinpath(package_dir, "README.md"), "# $(name)\n")
    write(joinpath(package_dir, "LICENSE"), "$(name) is in the public domain\n")
    write(joinpath(package_dir, "src", "$(name).jl"), "module $(name)\nend\n")
    write(joinpath(package_dir, "test", "runtests.jl"),
          "using Test\n@test true\n")
    run(`$git add --all`)
    vers = "Version $(version)"
    @show vers
    if !occursin("nothing to commit, working tree clean",
                read(`$git status`, String))
        @info("nothing to commit")
        run(`$git commit -qm $(vers)`)
    end
    return
end

function readdir_excluding_git(dir)
    return filter(!isequal(".git"), readdir(dir))
end

function check_result(actual_result_dir, expected_result_dir)
    check1 = compare_file_trees(actual_result_dir,
                                joinpath(@__DIR__, "expected_results",
                                         expected_result_dir))
    check2 = sanity_check_registry(actual_result_dir)
    return check1 && check2
end

function compare_file_trees(path1, path2)
    if isdir(path1) && isdir(path2)
        dir1 = readdir_excluding_git(path1)
        if sort(dir1) != sort(readdir_excluding_git(path2))
            println("Directories $(path1) and $(path2) differ.")
            return false
        end
        for path in dir1
            if !compare_file_trees(joinpath(path1, path), joinpath(path2, path))
                return false
            end
        end
    elseif isfile(path1) && isfile(path2)
        if !compare_files(path1, path2)
            println("Files $(path1) and $(path2) differ.")
            return false
        end
    else
        println("Mismatch between paths $(path1) and $(path2)")
        return false
    end

    return true
end

# Compress.save writes files differently on e.g. Julia 1.1 and
# 1.3. Compare the Deps.toml and Compat.toml files after reading them
# with Compress.load.
function compare_files(path1, path2)
    if endswith(path1, "Deps.toml") || endswith(path1, "Compat.toml")
        return Compress.load(path1) == Compress.load(path2)
    end
    return read_normalize_line_end(path1) == read_normalize_line_end(path2)
end

function read_normalize_line_end(path)
    return replace(read(path, String), "\r\n" => "\n")
end

# Check that the deps and compat files can be read at all by a
# function used in the internals of Pkg. Return true whenever there is
# no error.
function sanity_check_registry(path)
    registry = TOML.parsefile(joinpath(path, "Registry.toml"))
    for (uuid, package) in registry["packages"]
        package_path = joinpath(path, package["path"])
        deps_file = joinpath(package_path, "Deps.toml")
        compat_file = joinpath(package_path, "Compat.toml")
        if isdefined(Pkg.Operations, :load_package_data_raw)
            deps_data = Pkg.Operations.load_package_data_raw(Pkg.Types.UUID,
                                                             deps_file)
            compat_data = Pkg.Operations.load_package_data_raw(Pkg.Types.VersionSpec,
                                                               compat_file)
        else
            version_info = Pkg.Operations.load_versions(package_path;
                                                        include_yanked = false)
            versions = sort!(collect(keys(version_info)))
            deps_data = Pkg.Operations.load_package_data(Pkg.Types.UUID,
                                                         deps_file, versions)
            compat_data = Pkg.Operations.load_package_data(Pkg.Types.VersionSpec,
                                                           compat_file, versions)
        end
    end
    
    return true
end
