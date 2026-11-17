load("@rules_rust//rust:defs.bzl", "rust_test")

def _runpath(ctx, f):
    # This prototype targets Linux with a runfiles symlink tree.
    path = f.short_path
    if path.startswith("../"):
        return path[3:]
    return ctx.workspace_name + "/" + path

def _mull_control_test_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name)
    for char in ctx.attr.test_filter.elems():
        if char not in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_:":
            fail("test_filter must be an exact Rust test name")
    for char in ctx.attr.expected_location.elems():
        if char not in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_:/.-":
            fail("expected_location must be a Rust source path, line, and column")
    ctx.actions.expand_template(
        template = ctx.file._launcher,
        output = out,
        substitutions = {
            "@@BINARY@@": _runpath(ctx, ctx.file.harness),
            "@@CONFIG@@": _runpath(ctx, ctx.file.config),
            "@@RUNNER@@": _runpath(ctx, ctx.file._runner),
            "@@LIB@@": _runpath(ctx, ctx.file._clang_library),
            "@@FILTER@@": ctx.attr.test_filter,
            "@@EXPECTED@@": ctx.attr.expected,
            "@@LOCATION@@": ctx.attr.expected_location,
        },
        is_executable = True,
    )
    return DefaultInfo(
        executable = out,
        runfiles = ctx.runfiles(
            files = [ctx.file.harness, ctx.file.config, ctx.file._runner],
            transitive_files = ctx.attr._mull_libraries[DefaultInfo].files,
        ),
    )

mull_control_test = rule(
    implementation = _mull_control_test_impl,
    test = True,
    attrs = {
        "harness": attr.label(allow_single_file = True, mandatory = True),
        "config": attr.label(allow_single_file = [".yml"], mandatory = True),
        "test_filter": attr.string(mandatory = True),
        "expected_location": attr.string(mandatory = True),
        "expected": attr.string(values = ["killed", "survived"], mandatory = True),
        "_runner": attr.label(default = "@pinned_mull//:mull-runner-19", allow_single_file = True),
        "_clang_library": attr.label(default = "@pinned_mull//:lib/libclang-cpp.so.19.1", allow_single_file = True),
        "_mull_libraries": attr.label(default = "@pinned_mull//:libraries"),
        "_launcher": attr.label(default = "//bazel:control.sh.tpl", allow_single_file = True),
    },
)

def _plugin_bundle_impl(ctx):
    directory = ctx.actions.declare_directory(ctx.label.name)
    args = ctx.actions.args()
    args.add(directory.path)
    args.add(ctx.file.config.path)
    args.add_all([ctx.file._plugin] + ctx.files._mull_libraries)
    ctx.actions.run_shell(
        mnemonic = "MullPluginBundle",
        arguments = [args],
        inputs = [ctx.file._plugin, ctx.file.config] + ctx.files._mull_libraries,
        outputs = [directory],
        command = """out="$1"; config="$2"; shift 2
mkdir -p "$out"
cp -L "$config" "$out/mull.yml"
for file in "$@"; do cp -L "$file" "$out/"; done""",
    )
    return DefaultInfo(files = depset([directory]))

_mull_plugin_bundle = rule(
    implementation = _plugin_bundle_impl,
    attrs = {
        "config": attr.label(allow_single_file = [".yml"], mandatory = True),
        "_plugin": attr.label(default = "@pinned_mull//:mull-ir-frontend-19", allow_single_file = True),
        "_mull_libraries": attr.label(default = "@pinned_mull//:libraries"),
    },
)

def mull_rust_harness(name, config, **kwargs):
    """Build a rules_rust test harness instrumented by the pinned Mull plugin."""
    bundle = name + "_plugin"
    _mull_plugin_bundle(name = bundle, config = config)
    plugin_path = "$(execpath :%s)" % bundle
    rust_test(
        name = name,
        compile_data = kwargs.pop("compile_data", []) + [":" + bundle],
        rustc_env = dict(kwargs.pop("rustc_env", {}), **{
            "LD_LIBRARY_PATH": plugin_path,
            "MULL_CONFIG": plugin_path + "/mull.yml",
            "RUSTC_BOOTSTRAP": "1",
        }),
        rustc_flags = kwargs.pop("rustc_flags", []) + [
            "-Zllvm-plugins=" + plugin_path + "/mull-ir-frontend-19",
            "-Coverflow-checks=off",
            "-Cdebuginfo=2",
            "-Copt-level=0",
            "-Ccodegen-units=1",
        ],
        tags = kwargs.pop("tags", []) + ["manual"],
        **kwargs
    )
