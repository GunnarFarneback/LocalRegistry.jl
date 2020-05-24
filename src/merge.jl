using RegistryTools: write_registry

function merge(target_path::AbstractString,
               source_path::AbstractString;
               include::Union{Nothing, Vector{<:AbstractString}} = nothing,
               exclude::Union{Nothing, Vector{<:AbstractString}} = nothing)
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
    if !isempty(colliding_names)
        error("The target registry already contains these packages: $(colliding_names).")
    end

    colliding_uuids = intersect(keys(target_packages), keys(packages))
    if !isempty(colliding_uuids)
        error("The target registry already contains these uuids: $(colliding_uuids).")
    end

    for (uuid, package) in packages
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
