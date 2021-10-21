# Additional tests of `find_registry_path` and `check_registry`. Many
# of these have the purpose to cover error cases, making them somewhat
# contrived. Another complicating factor is that some of the call
# variants have to interact with the package environment, including
# registries, of the running Julia process.

# Not a registered package.
pkg = Pkg.Types.Project(Dict("name" => "UUIDs",
                             "uuid" => "cf7118a7-6976-5b1a-9a39-7adc72f591a4"))
@test_throws ErrorException find_registry_path(nothing, pkg)


with_empty_registry() do registry_dir, packages_dir
    Pkg.Registry.add(RegistrySpec(path = registry_dir))

    # Use Multibreak as Guinea pig. The sleep is a Travis workaround. See
    # a later comment. This also tests automatically choosing the only
    # installed registry for a new package.
    sleep(1)
    register("Multibreak", push = false, gitconfig = TEST_GITCONFIG)

    # Directory already exists. Also tests code handling a trailing slash.
    create_registry("TestRegistry2", "", gitconfig = TEST_GITCONFIG,
                    push = false)
    @test_throws ErrorException create_registry("TestRegistry2/", "",
                                                gitconfig = TEST_GITCONFIG,
                                                push = false)

    # Find a registry by name.
    package_path = find_package_path("Multibreak")
    pkg = Pkg.Types.read_project(joinpath(package_path, "Project.toml"))
    @test find_registry_path("TestRegistry") == joinpath(first(DEPOT_PATH),
                                                         "registries",
                                                         "TestRegistry")

    # The named registry does not exist. In this case it is assumed to
    # be a local path if it exists, otherwise a URL, regardless how
    # much it doesn't look like a URL.
    saved_dir = pwd()
    tempdir = mktempdir()
    cd(tempdir)
    @test find_registry_path("General", pkg) == "General"
    mkdir("General")
    @test find_registry_path("General", pkg) == abspath("General")
    cd(saved_dir)
    rm(tempdir, recursive = true)

    # Find which registry contains a package.
    @test find_registry_path(nothing, pkg) == joinpath(first(DEPOT_PATH),
                                                       "registries",
                                                       "TestRegistry")

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
end
