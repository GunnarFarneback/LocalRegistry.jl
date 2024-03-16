module GitExt

import LocalRegistry
import Git

LocalRegistry._gitcmd(::Nothing, ::Val{:git}) = Git.git()

end
