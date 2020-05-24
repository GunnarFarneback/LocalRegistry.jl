using RegistryTools: write_registry

function merge(target_path::AbstractString,
               source_path::AbstractString;
               include::Union{Nothing, Vector{<:AbstractString}} = nothing,
               exclude::Union{Nothing, Vector{<:AbstractString}} = nothing,
               merge_packages::Bool = false)
    if !isnothing(include) && !isnothing(exclude)
        error("Packages can be either included or excluded, not both.")
    end

    target_registry = parse_registry(joinpath(target_path, "Registry.toml"))
    source_registry = parse_registry(joinpath(source_path, "Registry.toml"))

    target_packages = target_registry.packages
    packages = source_registry.packages

    if !isnothing(include)
        packages = filter(p -> last(p)["name"] in include, packages)
        if length(packages) != length(include)
            missing_packages = setdiff(include, [p["name"] for p in values(packages)])
            error("Included packages $(missing_packages) do not exist in the source repository")
        end
    end

    if !isnothing(exclude)
        missing_packages = setdiff(exclude, [p["name"] for p in values(packages)])
        if !isempty(missing_packages)
            error("Excluded packages $(missing_packages) do not exist in the source repository")
        end
        packages = filter(p -> last(p)["name"] ∉ exclude, packages)
    end

    colliding_names = intersect([p["name"] for p in values(target_packages)],
                                [p["name"] for p in values(packages)])
    if !isempty(colliding_names) && !merge_packages
        error("The target registry already contains these packages: $(colliding_names).")
    end

    colliding_uuids = intersect(keys(target_packages), keys(packages))
    if !isempty(colliding_uuids)
        if merge_packages
            for uuid in colliding_uuids
                if target_packages[uuid]["name"] != packages[uuid]["name"]
                    error("Package with UUID=$(uuid) have different name in the two registries.")
                end
            end
        else
            error("The target registry already contains these uuids: $(colliding_uuids).")
        end
    end

    for (uuid, package) in packages
        if haskey(target_packages, uuid)
            @assert merge_packages
            merge_package(uuid, target_packages[uuid], package,
                          target_path, source_path)
            continue
        end

        push!(target_packages, uuid => package)
        package_dir = joinpath(target_path, package["path"])
        if isdir(package_dir)
            error("Package dir ", package["path"], " already exists in target registry.")
        end
        mkpath(package_dir)
        for filename in ("Package.toml", "Versions.toml",
                         "Deps.toml", "Compat.toml")
            from = joinpath(source_path, package["path"], filename)
            to = joinpath(target_path, package["path"], filename)
            if isfile(from)
                cp(from, to)
            end
        end
    end

    write_registry(joinpath(target_path, "Registry.toml"), target_registry)
end

function merge_package(uuid, target_package, source_package,
                       target_path, source_path)
    target_package_path = joinpath(target_path, target_package["path"])
    source_package_path = joinpath(source_path, source_package["path"])

    # Package.toml
    target_package_data = read_package_data(target_package_path, "Package.toml")
    source_package_data = read_package_data(source_package_path, "Package.toml")
    if target_package_data != source_package_data
        @warn("Package.toml files differ for package with UUID=$(uuid). Using target file.")
    end

    # Versions.toml
    target_versions_data = read_package_data(target_package_path, "Versions.toml")
    source_versions_data = read_package_data(source_package_path, "Versions.toml")
    overlap = intersect(keys(source_versions_data), keys(target_versions_data))
    if !isempty(overlap)
        @warn("One or more versions of ", target_package["name"], "are registered in both registries: $(overlap). Using the ones in the target.")
    end
    versions_data = Base.merge(source_versions_data, target_versions_data)
    write_package_data(versions_data, target_package_path, "Versions.toml")

    # Deps.toml and Compat.toml
    for filename in ("Deps.toml", "Compat.toml")
        target_data = read_package_data(target_package_path, filename)
        source_data = read_package_data(source_package_path, filename)
        data = Base.merge(source_data, target_data)
        write_package_data(data, target_package_path, filename)
    end
end

function read_package_data(package_path, filename)
    path = joinpath(package_path, filename)
    if !isfile(path)
        return Dict()
    elseif filename == "Deps.toml" || filename == "Compat.toml"
        return Compress.load(path)
    else
        return TOML.parsefile(path)
    end
end

function write_package_data(data, package_path, filename)
    path = joinpath(package_path, filename)
    if filename == "Deps.toml" || filename == "Compat.toml"
        Compress.save(path, data)
    else
        @assert filename == "Versions.toml"
        save_versions_file(path, data)
    end
end

# This function needs to be refactored within RegistryTools.
function save_versions_file(filename, data)
    open(filename, "w") do io
        # TOML.print with sorted=true sorts recursively
        # so this by function needs to handle the outer dict
        # with version number keys, and the inner dict with
        # git-tree-sha1, yanked, etc as keys.
        function by(x)
            if occursin(Base.VERSION_REGEX, x)
                return VersionNumber(x)
            else
                if x == "git-tree-sha1"
                    return 1
                elseif x == "yanked"
                    return 2
                else
                    return 3
                end
            end
        end
        TOML.print(io, data; sorted = true, by = by)
    end
end
