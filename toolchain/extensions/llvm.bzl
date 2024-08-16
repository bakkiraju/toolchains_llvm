"""LLVM extension for use with bzlmod"""

load("@toolchains_llvm//toolchain:rules.bzl", "llvm_toolchain")
load(
    "@toolchains_llvm//toolchain/internal:repo.bzl",
    _llvm_config_attrs = "llvm_config_attrs",
    _llvm_repo_attrs = "llvm_repo_attrs",
)

def _constraint_dict(tags, name):
    cons = {}

    # Gather all the additional constraints for each target
    for tag in tags:
        targets = list(tag.targets)
        if not targets:
            targets = [""]
        for target in targets:
            cons_for_target = cons.setdefault(target, [])
            cons_for_target.extend([str(c) for c in tag.constraints])

    # Encode the values as json so we can pass them into the repo_rule
    cons = {k: json.encode(v) for k, v in cons.items()}

    return con

def _llvm_impl_(module_ctx):
    for mod in module_ctx.modules:
        if not mod.is_root:
            fail("Only the root module can use the 'llvm' extension")
        for toolchain_attr in mod.tags.toolchain:
            attrs = {
                key: getattr(toolchain_attr, key)
                for key in dir(toolchain_attr)
                if not key.startswith("_")
            }
            attrs["extra_exec_compatible_with"] = _constraint_dict(
                [tag for tag in mod.tags.extra_exec_compatible_with if tag.name == name],
                name,
            )
            attrs["extra_target_compatible_with"] = _constraint_dict(
                [tag for tag in mod.tags.extra_target_compatible_with if tag.name == name],
                name,
            )
            llvm_toolchain(
                **attrs
            )

        # Check that every defined toolchain_root or sysroot has a corresponding toolchain.
        for root in mod.tags.toolchain_root:
            if root.name not in toolchain_names:
                fail("toolchain_root '%s' does not have a corresponding toolchain" % root.name)
        for root in mod.tags.sysroot:
            if root.name not in toolchain_names:
                fail("sysroot '%s' does not have a corresponding toolchain" % root.name)


_attrs = {
    "name": attr.string(doc = """\
        Base name for the generated repositories, allowing more than one LLVM toolchain to be registered.
    """, default = "llvm_toolchain"),
}
_attrs.update(_llvm_config_attrs)
_attrs.update(_llvm_repo_attrs)

llvm = module_extension(
    implementation = _llvm_impl_,
    tag_classes = {
        "toolchain": tag_class(
            attrs = _attrs,
        ),
    },
)
