def _local_sdk_impl(ctx):
    path = ctx.getenv(ctx.attr.env)
    if not path:
        fail("Pass --repo_env=%s=/absolute/path" % ctx.attr.env)
    for name in ctx.attr.entries:
        source = ctx.path(path).get_child(name)
        if not source.exists:
            fail("%s is missing SDK entry %s" % (ctx.attr.env, name))
        ctx.symlink(source, name)
    ctx.file("BUILD.bazel", ctx.attr.build)

local_sdk = repository_rule(
    implementation = _local_sdk_impl,
    attrs = {"env": attr.string(), "entries": attr.string_list(), "build": attr.string()},
    local = True,
    configure = True,
)
