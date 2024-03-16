# Try to register an already existing version with different content.
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "Flux24.toml")
    register(joinpath(packages_dir, "Flux"),
             registry = registry_dir,
             gitconfig = TEST_GITCONFIG,
             push = false)
    prepare_package(packages_dir, "Flux30.toml")
    @test_throws ErrorException register(joinpath(packages_dir, "Flux"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
    # This should do nothing more than give an informational message.
    @test do_register(joinpath(packages_dir, "Flux"), registry_dir,
                      gitconfig = TEST_GITCONFIG, push = false,
                      ignore_reregistration = true) == false
end

# Parse error in compat section.
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "Broken1.toml")
    @test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
end

# Try to change name (UUID remains).
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "Flux1.toml")
    register(joinpath(packages_dir, "Flux"),
             registry = registry_dir,
             gitconfig = TEST_GITCONFIG,
             push = false)
    prepare_package(packages_dir, "Fluxx1.toml")
    @test_throws ErrorException register(joinpath(packages_dir, "Fluxx"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
end

# Try to change UUID.
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "Flux1.toml")
    register(joinpath(packages_dir, "Flux"),
             registry = registry_dir,
             gitconfig = TEST_GITCONFIG,
             push = false)
    prepare_package(packages_dir, "Flux31.toml")
    @test_throws ErrorException register(joinpath(packages_dir, "Flux"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
end

# Depends on itself.
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "Broken2.toml")
    @test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
end

# Incorrect name of dependency.
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "Flux1.toml")
    register(joinpath(packages_dir, "Flux"),
             registry = registry_dir,
             gitconfig = TEST_GITCONFIG,
             push = false)
    prepare_package(packages_dir, "Broken3.toml")
    @test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
end

# TODO: This should really be an error but RegistryTools 1.3.0 doesn't catch it.
# Incorrect UUID of dependency.
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "Broken4.toml")
    register(joinpath(packages_dir, "Broken"), registry = registry_dir,
             gitconfig = TEST_GITCONFIG, push = false)
end

# Incorrect UUID of stdlib.
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "Broken5.toml")
    @test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
end

with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "Flux1.toml")
    register(joinpath(packages_dir, "Flux"),
             registry = registry_dir,
             gitconfig = TEST_GITCONFIG,
             push = false)
    # Change the git remote before registration and verify that the
    # registered repo is not changed.
    prepare_package(packages_dir, "Flux32.toml")
    package_dir = joinpath(packages_dir, "Flux")
    git = gitcmd(package_dir, gitconfig = TEST_GITCONFIG)
    package_file = joinpath(registry_dir, "F", "Flux", "Package.toml")
    old_repo = TOML.parsefile(package_file)["repo"]
    new_repo = "https://example.com/Julia/Flux.jl.git"
    run(`$git remote set-url origin $(new_repo)`)
    register(joinpath(packages_dir, "Flux"), registry = registry_dir,
             gitconfig = TEST_GITCONFIG, push = false)
    @test TOML.parsefile(package_file)["repo"] == old_repo

    # Register with explicit repo argument and verify that the registered
    # repo is updated.
    prepare_package(packages_dir, "Flux33.toml")
    register(joinpath(packages_dir, "Flux"), registry = registry_dir,
             repo = new_repo, gitconfig = TEST_GITCONFIG, push = false)
    @test TOML.parsefile(package_file)["repo"] == new_repo
end

# Register a package in a subdirectory of a git repository. Also add
# some dirt outside the subdirectory to verify that it is ignored.
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "SubdirTest1.toml", "subdir")
    write(joinpath(packages_dir, "SubdirTest", "README.md"), "dirty")
    register(joinpath(packages_dir, "SubdirTest", "subdir"),
             registry = registry_dir, gitconfig = TEST_GITCONFIG, push = false)
    package_file = joinpath(registry_dir, "S", "SubdirTest", "Package.toml")
    @test TOML.parsefile(package_file)["subdir"] == "subdir"
end

# Register a package with a JuliaProject.toml rather than a Project.toml.
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "JuliaProjectTest1.toml",
                    use_julia_project = true)
    register(joinpath(packages_dir, "JuliaProjectTest"), registry = registry_dir,
             gitconfig = TEST_GITCONFIG, push = false)
    @test isfile(joinpath(registry_dir, "J", "JuliaProjectTest", "Package.toml"))
end

# Remove Project.toml from a package and try to register.
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "Flux1.toml")
    rm(joinpath(packages_dir, "Flux", "Project.toml"))
    @test_throws ErrorException register(joinpath(packages_dir, "Flux"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
end

# Dirty the package repository and try to register the package.
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "Flux1.toml")
    readme = joinpath(packages_dir, "Flux", "README.md")
    open(readme, "a") do io
        write(io, "\n")
    end
    @test_throws ErrorException register(joinpath(packages_dir, "Flux"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
end

# Dirty the registry repository and try to register a package.
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "Flux1.toml")
    filename = joinpath(registry_dir, "Registry.toml")
    open(filename, "a") do io
        write(io, "\n")
    end
    @test_throws ErrorException register(joinpath(packages_dir, "Flux"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
    # Allowed with `commit = false`.
    register(joinpath(packages_dir, "Flux"), registry = registry_dir,
             gitconfig = TEST_GITCONFIG, push = false,  commit = false)
end


# Test automatic push functionality. The sequence of events is:
# 1. Create a bare "upstream" repository.
# 2. Create a new registry with the upstream as repo and `push = true`.
# 3. Register a package with `push = true`.
# 4. Verify that the registry and the upstream repo has the same two commits.
with_testdir() do testdir
    upstream_dir = joinpath(testdir, "upstream")
    mkpath(upstream_dir)
    upstream_git = gitcmd(upstream_dir, gitconfig = TEST_GITCONFIG)
    run(`$(upstream_git) init --bare`)
    registry_push_dir = joinpath(testdir, "TestRegistryPush")
    create_registry(registry_push_dir, "file://$(upstream_dir)", push = true,
                    gitconfig = TEST_GITCONFIG)
    downstream_git = gitcmd(registry_push_dir, gitconfig = TEST_GITCONFIG)
    packages_dir = joinpath(testdir, "packages")
    prepare_package(packages_dir, "FirstTest1.toml")
    register(joinpath(packages_dir, "FirstTest"), registry = registry_push_dir,
             push = true, gitconfig = TEST_GITCONFIG)
    @test readchomp(`$(downstream_git) log`) == readchomp(`$(upstream_git) log`)
    @test length(readlines(`$(upstream_git) log --format=oneline`)) == 2

    # Now duplicate the upstream repo. Then register the same package
    # * like before via downstream repo with push,
    # * directly against the second upstream, internally using a
    #   temporary clone.
    upstream2_dir = joinpath(testdir, "upstream2")
    mkpath(upstream2_dir)
    upstream2_git = gitcmd(upstream2_dir, gitconfig = TEST_GITCONFIG)
    run(`$(upstream2_git) clone --bare file://$(upstream_dir) .`)
    prepare_package(packages_dir, "Flux1.toml")
    register(joinpath(packages_dir, "Flux"), registry = registry_push_dir,
             push = true, gitconfig = TEST_GITCONFIG)
    # Can't have `push = false` when using a temporary git clone.
    @test_throws ErrorException register(joinpath(packages_dir, "Flux"),
                                         registry = "file://$(upstream2_dir)",
                                         push = false,
                                         gitconfig = TEST_GITCONFIG)
    register(joinpath(packages_dir, "Flux"), registry = "file://$(upstream2_dir)",
             push = true, gitconfig = TEST_GITCONFIG)
    @test readchomp(`$(downstream_git) log`) == readchomp(`$(upstream_git) log`)
    # Can't use standard log format here since the time stamps will be different.
    @test readchomp(`$(downstream_git) log --format=%T:%s`) == readchomp(`$(upstream2_git) log --format=%T:%s`)
    @test length(readlines(`$(upstream2_git) log --format=%T:%s`)) == 3

    # Register one more package, this time using a branch.
    prepare_package(packages_dir, "Images1.toml")
    register(joinpath(packages_dir, "Images"), registry = registry_push_dir,
             push = true, branch = "images", gitconfig = TEST_GITCONFIG)
    register(joinpath(packages_dir, "Images"),
             registry = "file://$(upstream2_dir)",
             push = true, branch = "images", gitconfig = TEST_GITCONFIG)
    @test readchomp(`$(downstream_git) log`) == readchomp(`$(upstream_git) log`)
    # Can't use standard log format here since the time stamps will be different.
    @test readchomp(`$(upstream_git) log --format=%T:%s images`) == readchomp(`$(upstream2_git) log --format=%T:%s images`)
    @test length(readlines(`$(upstream2_git) log --format=%T:%s images`)) == 4
end

# Test automatic creation of a Gitlab merge request using git push options.
# 1. Create a bare "upstream" repository.
# 2. Create a new registry with the upstream as repo and `push = true`.
# 3. Add a pre-receive hook to the upstream repository, which will save
#    push options to a file.
# 4. Register a package with `create_gitlab_mr = true`.
# 5. Verify that the expected push options were received.
with_testdir() do testdir
    withenv("GITLAB_USER_LOGIN" => "john.doe") do
        upstream_dir = joinpath(testdir, "upstream")
        mkpath(upstream_dir)
        upstream_git = gitcmd(upstream_dir, gitconfig = TEST_GITCONFIG)
        run(`$(upstream_git) init --bare`)

        registry_test_dir = joinpath(testdir, "TestGitlabMR")
        create_registry(registry_test_dir, "file://$(upstream_dir)", push = true,
                        gitconfig = TEST_GITCONFIG)

        received_push_options_file = joinpath(testdir, "received_push_options")
        run(`$(upstream_git) config --local receive.advertisePushOptions true`)
        pre_receive_hook = joinpath(upstream_dir, "hooks", "pre-receive")
        write(pre_receive_hook,
              """
              #!/bin/sh
              if test -n "\$GIT_PUSH_OPTION_COUNT"
              then
                  i=0
                  while test "\$i" -lt "\$GIT_PUSH_OPTION_COUNT"
                  do
                      eval "value=\\\$GIT_PUSH_OPTION_\$i"
                      echo \$value >> $(received_push_options_file)
                      i=\$((i + 1))
                  done
               fi
               """)
        chmod(pre_receive_hook, 0o775)

        packages_dir = joinpath(testdir, "packages")
        prepare_package(packages_dir, "FirstTest1.toml")
        register(joinpath(packages_dir, "FirstTest"), registry = registry_test_dir,
                 push = true, create_gitlab_mr = true, gitconfig = TEST_GITCONFIG)

        package_git = gitcmd(joinpath(packages_dir, "FirstTest"),
                             gitconfig = TEST_GITCONFIG)
        commit_hash = readchomp(`$(package_git) rev-parse HEAD`)
        expected_push_options =
            """
            merge_request.create
            merge_request.title=New package: FirstTest v1.0.0
            merge_request.description=• Registering package: FirstTest<br>• Repository: git@example.com:Julia/FirstTest.jl.git<br>• Version: v1.0.0<br>• Commit: $(commit_hash)<br>• Triggered by: @john.doe<br>
            merge_request.merge_when_pipeline_succeeds
            merge_request.remove_source_branch
            """
        # Obviously the hook shell script won't be effective on Windows,
        # but there is no need to perform this test on every platform.
        if !Sys.iswindows()
            @test read(received_push_options_file, String) == expected_push_options
        end
        # Check that the automatically named branch exists in the upstream repo.
        @test length(readchomp(`$(upstream_git) rev-parse --verify FirstTest/v1.0.0`)) == 40

        # `create_gitlab_mr` requires `push` and `commit`.
        @test_throws ErrorException register(joinpath(packages_dir, "FirstTest"),
                                             registry = registry_test_dir,
                                             push = false, create_gitlab_mr = true,
                                             gitconfig = TEST_GITCONFIG)
        @test_throws ErrorException register(joinpath(packages_dir, "FirstTest"),
                                             registry = registry_test_dir,
                                             commit = false, create_gitlab_mr = true,
                                             gitconfig = TEST_GITCONFIG)
    end
end

# No UUID nor version
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "NonPackageProject1.toml")
    @test_throws ErrorException register(joinpath(packages_dir, "JuliaProjectTest"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
end

# No version
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "NonPackageProject2.toml")
    @test_throws ErrorException register(joinpath(packages_dir, "JuliaProjectTest"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
end

# No UUID
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "NonPackageProject3.toml")
    @test_throws ErrorException register(joinpath(packages_dir, "JuliaProjectTest"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
end

# No module file
with_empty_registry() do registry_dir, packages_dir
    prepare_package(packages_dir, "Flux1.toml", module_file=false)
    @test_throws ErrorException register(joinpath(packages_dir, "Flux"),
                                         registry = registry_dir,
                                         gitconfig = TEST_GITCONFIG,
                                         push = false)
end
