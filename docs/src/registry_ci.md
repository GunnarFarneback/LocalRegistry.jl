# Registry Consistency Testing

For trouble-shooting, or as good practice if you have your registry
set up with CI (Continuous Integration), you can run the registry
consistency tests from the
[RegistryCI](https://github.com/JuliaRegistries/RegistryCI.jl)
package on your registry.

In the following sections it is assumed that all packages in your
registry have all their dependencies registerad either in your own
registry or in the General registry, which is the typical scenario.

## Manual Testing

Add RegistryCI
```
pkg> add RegistryCI
```
and run the consistency tests:
```
using RegistryCI
withenv("JULIA_PKG_UNPACK_REGISTRY" => "true") do
    RegistryCI.test(path_to_your_registry, registry_deps = ["General"])
end
```

## CI Testing

The idea is the same as for manual testing. A sample GitLab CI job for
your registry repository can look something like:
```
registry consistency test:
  stage: test
  variables:
    JULIA_PKG_UNPACK_REGISTRY: "true"
  script:
    - git config --global user.name $GITLAB_USER_NAME
    - git config --global user.email $GITLAB_USER_EMAIL
    - julia -e 'using Pkg; Pkg.add("RegistryCI")'
    - julia --color=yes -e 'using RegistryCI; RegistryCI.test(@__DIR__, registry_deps = ["General"])'
```
