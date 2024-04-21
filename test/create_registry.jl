# Upstream and downstream have different ideas about initial branch
# names. Respect upstream when no explicit branch name was set in the
# `create_registry` call.
with_testdir() do testdir
    upstream_dir = joinpath(testdir, "upstream_registry")
    mkpath(upstream_dir)
    upstream_git = gitcmd(upstream_dir, gitconfig = TEST_GITCONFIG)
    # With a sufficiently new git (probably 2.28) this test could be
    # done much more easily, basically just
    # run(`$upstream_git init -q --bare --initial_branch=some_unusual_branch_name`)
    # To handle older git we have to first init the bare upstream
    # repository, then clone a temporary downstream where we create a
    # new branch, make a commit and push it up. Also needs some
    # hacking of the original HEAD.
    run(`$upstream_git init -q --bare`)
    write(joinpath(upstream_dir, "HEAD"), "ref: refs/heads/some_unusual_branch_name")
    tmp_downstream_dir = joinpath(testdir, "tmp_downstream")
    mkpath(tmp_downstream_dir)
    tmp_git = gitcmd(tmp_downstream_dir, gitconfig = TEST_GITCONFIG)
    run(`$tmp_git clone file://$(upstream_dir) .`)
    run(`$tmp_git checkout -b some_unusual_branch_name`)
    write(joinpath(tmp_downstream_dir, ".gitignore"), "Manifest.toml")
    run(`$tmp_git add .gitignore`)
    run(`$tmp_git commit -m "Initial version"`)
    run(`$tmp_git push -u origin some_unusual_branch_name`)

    downstream_dir = joinpath(testdir, "downstream_registry")
    create_registry(downstream_dir, "file://$(upstream_dir)", push = true,
                    gitconfig = TEST_GITCONFIG)
    @test readchomp(`$upstream_git branch --show-current`) == "some_unusual_branch_name"

    # Test that `create_registry` errors rather than overwriting an existing registry
    run(`rm -rf $(downstream_dir)`)
    @test_throws ErrorException("file://$(upstream_dir) already contains a registry") (
                    create_registry(downstream_dir, "file://$(upstream_dir)",
                                    push = true, gitconfig = TEST_GITCONFIG))
end

# Test explicit branch name.
with_testdir() do testdir
    upstream_dir = joinpath(testdir, "upstream_registry")
    mkpath(upstream_dir)
    upstream_git = gitcmd(upstream_dir, gitconfig = TEST_GITCONFIG)
    run(`$upstream_git init -q --bare`)
    downstream_dir = joinpath(testdir, "downstream_registry")
    create_registry(downstream_dir, "file://$(upstream_dir)", push = true,
                    branch = "my_favorite_branch_name",
                    gitconfig = TEST_GITCONFIG)
    @test strip(read(`$upstream_git branch`, String)) == "my_favorite_branch_name"

    # Test that `create_registry` errors rather than overwriting an existing registry
    run(`rm -rf $(downstream_dir)`)
    @test_throws ProcessFailedException (
                    create_registry(downstream_dir, "file://$(upstream_dir)",
                                    branch = "my_favorite_branch_name",
                                    push = true, gitconfig = TEST_GITCONFIG))
end
