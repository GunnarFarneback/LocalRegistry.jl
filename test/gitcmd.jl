import Git

external_git_available = try
    wait(run(`git`, wait = false))
    true
catch e
    false
end

artifact_exec_path = readchomp(`$(Git.git()) --exec-path`)

# These tests are not intended to check all the functionality of
# `gitcmd` - that is covered well enough by all the other tests.
#
# The focus here is only to verify that the artifact git (from the Git
# package) is functional and that the external git option works as
# intended.
mktempdir() do tmp_dir
    git = gitcmd(tmp_dir, Dict(), nothing)
    @test readchomp(`$git --exec-path`) == artifact_exec_path
    git = gitcmd(tmp_dir, Dict(), Git.git())
    @test readchomp(`$git --exec-path`) == artifact_exec_path
    # We have to skip the rest of the tests if there's no external git
    # available.
    if external_git_available
        external_exec_path = readchomp(`git --exec-path`)
        git = gitcmd(tmp_dir, Dict(), "git")
        @test readchomp(`$git --exec-path`) == external_exec_path
        git = gitcmd(tmp_dir, Dict(), `git`)
        @test readchomp(`$git --exec-path`) == external_exec_path
        if Sys.iswindows()
            # See https://github.com/GunnarFarneback/LocalRegistry.jl/issues/76
            # for an explanation why we want this to work.
            git = gitcmd(tmp_dir, Dict(), `cmd /c git`)
            @test readchomp(`$git --exec-path`) == external_exec_path
        else
            git = gitcmd(tmp_dir, Dict(), readchomp(`which git`))
            @test readchomp(`$git --exec-path`) == external_exec_path
        end
    end
end
