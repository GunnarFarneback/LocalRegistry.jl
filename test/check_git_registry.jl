with_testdir() do testdir
    registry_dir = joinpath(testdir, "TestRegistry")
    upstream_dir = joinpath(dirname(registry_dir), "upstream")
    upstream_url = "file:///$(upstream_dir)"
    create_registry(registry_dir, upstream_url,
                    description = "For testing purposes only.",
                    uuid = "ed6ca2f6-392d-11ea-3224-d3daf7fee369",
                    gitconfig = TEST_GITCONFIG, push = false)

    reg_path, reg_git, is_temp = check_git_registry(registry_dir,
                                                    TEST_GITCONFIG, nothing)
    @test reg_path == registry_dir
    @test readchomp(`$(reg_git) rev-parse --is-inside-work-tree`) == "true"
    @test !is_temp

    mkpath(upstream_dir)
    upstream_git = gitcmd(upstream_dir, gitconfig = TEST_GITCONFIG)
    run(`$(upstream_git) clone -q --bare $(registry_dir) .`)

    reg_path, reg_git, is_temp = check_git_registry(upstream_url,
                                                    TEST_GITCONFIG, nothing)
    @test isdir(joinpath(reg_path, ".git"))
    @test readchomp(`$(reg_git) rev-parse --is-inside-work-tree`) == "true"
    @test is_temp

    # Emulate a registry downloaded from a package server.
    downstream_git = gitcmd(registry_dir, gitconfig = TEST_GITCONFIG)
    tree_hash = readchomp(`$(downstream_git) rev-parse HEAD:`)
    rm(joinpath(registry_dir, ".git"), recursive = true)
    write(joinpath(registry_dir, ".tree_info.toml"),
          "git-tree-sha1 = \"$(tree_hash)\"")
    reg_path, reg_git, is_temp = check_git_registry(registry_dir,
                                                    TEST_GITCONFIG, nothing)
    @test isdir(joinpath(reg_path, ".git"))
    @test readchomp(`$(reg_git) rev-parse --is-inside-work-tree`) == "true"
    @test is_temp

    # Emulate a registry downloaded from a package server without unpacking.
    tar = read(`$(upstream_git) -c core.autocrlf=false archive $(tree_hash)`)
    gzip = transcode(GzipCompressor, tar)
    write(joinpath(testdir, "TestRegistry.tar.gz"), gzip)
    registry_toml = joinpath(testdir, "TestRegistry.toml")
    write(registry_toml,
          """git-tree-sha1 = "$(tree_hash)"
             uuid = "ed6ca2f6-392d-11ea-3224-d3daf7fee369"
             path = "TestRegistry.tar.gz"
          """)
    reg_path, reg_git, is_temp = check_git_registry(registry_toml,
                                                    TEST_GITCONFIG, nothing)
    @test isdir(joinpath(reg_path, ".git"))
    @test readchomp(`$(reg_git) rev-parse --is-inside-work-tree`) == "true"
    @test is_temp
end
