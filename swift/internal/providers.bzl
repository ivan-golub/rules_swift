# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Defines Starlark providers that propagated by the Swift BUILD rules."""

load("@bazel_skylib//lib:sets.bzl", "sets")

SwiftInfo = provider(
    doc = """\
Contains information about the compiled artifacts of a Swift module.

This provider contains a large number of fields and many custom rules may not
need to set all of them. Instead of constructing a `SwiftInfo` provider
directly, consider using the `swift_common.create_swift_info` function, which
has reasonable defaults for any fields not explicitly set.
""",
    fields = {
        "direct_defines": """\
`List` of `string`s. The values specified by the `defines` attribute of the
library that directly propagated this provider.
""",
        "direct_modules": """\
`List` of values returned from `swift_common.create_module`. The modules (both
Swift and C/Objective-C) emitted by the library that propagated this provider.
""",
        "swift_version": """\
`String`. The version of the Swift language that was used when compiling the
propagating target; that is, the value passed via the `-swift-version` compiler
flag. This will be `None` if the flag was not set.

This field is deprecated; the Swift version should be obtained by inspecting the
arguments passed to specific compilation actions.
""",
        "transitive_defines": """\
`Depset` of `string`s. The transitive `defines` specified for the library that
propagated this provider and all of its dependencies.
""",
        "transitive_modules": """\
`Depset` of values returned from `swift_common.create_module`. The transitive
modules (both Swift and C/Objective-C) emitted by the library that propagated
this provider and all of its dependencies.
""",
    },
)

SwiftProtoInfo = provider(
    doc = "Propagates Swift-specific information about a `proto_library`.",
    fields = {
        "module_mappings": """\
`Sequence` of `struct`s. Each struct contains `module_name` and
`proto_file_paths` fields that denote the transitive mappings from `.proto`
files to Swift modules. This allows messages that reference messages in other
libraries to import those modules in generated code.
""",
        "pbswift_files": """\
`Depset` of `File`s. The transitive Swift source files (`.pb.swift`) generated
from the `.proto` files.
""",
    },
)

SwiftToolchainInfo = provider(
    doc = """
Propagates information about a Swift toolchain to compilation and linking rules
that use the toolchain.
""",
    fields = {
        "action_configs": """\
This field is an internal implementation detail of the build rules.
""",
        "all_files": """\
A `depset` of `File`s containing all the Swift toolchain files (tools,
libraries, and other resource files) so they can be passed as `tools` to actions
using this toolchain.
""",
        "cc_toolchain_info": """\
The `cc_common.CcToolchainInfo` provider from the Bazel C++ toolchain that this
Swift toolchain depends on.
""",
        "command_line_copts": """\
`List` of `strings`. Flags that were passed to Bazel using the `--swiftcopt`
command line flag. These flags have the highest precedence; they are added to
compilation command lines after the toolchain default flags
(`SwiftToolchainInfo.swiftc_copts`) and after flags specified in the `copts`
attributes of Swift targets.
""",
        "cpu": """\
`String`. The CPU architecture that the toolchain is targeting.
""",
        "linker_opts_producer": """\
Skylib `partial`. A partial function that returns the flags that should be
passed to Clang to link a binary or test target with the Swift runtime
libraries.

The partial should be called with two arguments:

*   `is_static`: A `Boolean` value indicating whether to link against the static
    or dynamic runtime libraries.

*   `is_test`: A `Boolean` value indicating whether the target being linked is a
    test target.
""",
        "object_format": """\
`String`. The object file format of the platform that the toolchain is
targeting. The currently supported values are `"elf"` and `"macho"`.
""",
        "optional_implicit_deps": """\
`List` of `Target`s. Library targets that should be added as implicit
dependencies of any `swift_library`, `swift_binary`, or `swift_test` target that
does not have the feature `swift.minimal_deps` applied.
""",
        "requested_features": """\
`List` of `string`s. Features that should be implicitly enabled by default for
targets built using this toolchain, unless overridden by the user by listing
their negation in the `features` attribute of a target/package or in the
`--features` command line flag.

These features determine various compilation and debugging behaviors of the
Swift build rules, and they are also passed to the C++ APIs used when linking
(so features defined in CROSSTOOL may be used here).
""",
        "required_implicit_deps": """\
`List` of `Target`s. Library targets that should be unconditionally added as
implicit dependencies of any `swift_library`, `swift_binary`, or `swift_test`
target.
""",
        "root_dir": """\
`String`. The workspace-relative root directory of the toolchain.
""",
        "supports_objc_interop": """\
`Boolean`. Indicates whether or not the toolchain supports Objective-C interop.
""",
        "swift_worker": """\
`File`. The executable representing the worker executable used to invoke the
compiler and other Swift tools (for both incremental and non-incremental
compiles).
""",
        "system_name": """\
`String`. The name of the operating system that the toolchain is targeting.
""",
        "test_configuration": """\
`Struct` containing two fields:

*   `env`: A `dict` of environment variables to be set when running tests
    that were built with this toolchain.

*   `execution_requirements`: A `dict` of execution requirements for tests
    that were built with this toolchain.

This is used, for example, with Xcode-based toolchains to ensure that the
`xctest` helper and coverage tools are found in the correct developer
directory when running tests.
""",
        "tool_configs": """\
This field is an internal implementation detail of the build rules.
""",
        "unsupported_features": """\
`List` of `string`s. Features that should be implicitly disabled by default for
targets built using this toolchain, unless overridden by the user by listing
them in the `features` attribute of a target/package or in the `--features`
command line flag.

These features determine various compilation and debugging behaviors of the
Swift build rules, and they are also passed to the C++ APIs used when linking
(so features defined in CROSSTOOL may be used here).
""",
    },
)

SwiftUsageInfo = provider(
    doc = """\
A provider that indicates that Swift was used by a target or any target that it
depends on, and specifically which toolchain was used.
""",
    fields = {
        "toolchain": """\
The Swift toolchain that was used to build the targets propagating this
provider.
""",
    },
)

def create_module(*, name, clang = None, swift = None):
    """Creates a value containing Clang/Swift module artifacts of a dependency.

    At least one of the `clang` and `swift` arguments must not be `None`. It is
    valid for both to be present; this is the case for most Swift modules, which
    provide both Swift module artifacts as well as a generated header/module map
    for Objective-C targets to depend on.

    Args:
        name: The name of the module.
        clang: A value returned by `swift_common.create_clang_module` that
            contains artifacts related to Clang modules, such as a module map or
            precompiled module. This may be `None` if the module is a pure Swift
            module with no generated Objective-C interface.
        swift: A value returned by `swift_common.create_swift_module` that
            contains artifacts related to Swift modules, such as the
            `.swiftmodule`, `.swiftdoc`, and/or `.swiftinterface` files emitted
            by the compiler. This may be `None` if the module is a pure
            C/Objective-C module.

    Returns:
        A `struct` containing the `name`, `clang`, and `swift` fields provided
        as arguments.
    """
    if clang == None and swift == None:
        fail("Must provide atleast a clang or swift module.")
    return struct(
        clang = clang,
        name = name,
        swift = swift,
    )

def create_clang_module(
        *,
        compilation_context,
        module_map,
        precompiled_module = None):
    """Creates a value representing a Clang module used as a Swift dependency.

    Args:
        compilation_context: A `CcCompilationContext` that contains the header
            files, include paths, and other context necessary to compile targets
            that depend on this module (if using the text module map instead of
            the precompiled module).
        module_map: The text module map file that defines this module. This
            argument may be specified as a `File` or as a `string`; in the
            latter case, it is assumed to be the path to a file that cannot
            be provided as an action input because it is outside the workspace
            (for example, the module map for a module from an Xcode SDK).
        precompiled_module: A `File` representing the precompiled module (`.pcm`
            file) if one was emitted for the module. This may be `None` if no
            explicit module was built for the module; in that case, targets that
            depend on the module will fall back to the text module map and
            headers.

    Returns:
        A `struct` containing the `compilation_context`, `module_map`, and
        `precompiled_module` fields provided as arguments.
    """
    return struct(
        compilation_context = compilation_context,
        module_map = module_map,
        precompiled_module = precompiled_module,
    )

def create_swift_module(
        *,
        swiftdoc,
        swiftmodule,
        defines = [],
        swiftinterface = None):
    """Creates a value representing a Swift module use as a Swift dependency.

    Args:
        swiftdoc: The `.swiftdoc` file emitted by the compiler for this module.
        swiftmodule: The `.swiftmodule` file emitted by the compiler for this
            module.
        defines: A list of defines that will be provided as `copts` to targets
            that depend on this module. If omitted, the empty list will be used.
        swiftinterface: The `.swiftinterface` file emitted by the compiler for
            this module. May be `None` if no module interface file was emitted.

    Returns:
        A `struct` containing the `defines`, `swiftdoc`, `swiftmodule`, and
        `swiftinterface` fields provided as arguments.
    """
    return struct(
        defines = defines,
        swiftdoc = swiftdoc,
        swiftinterface = swiftinterface,
        swiftmodule = swiftmodule,
    )

def create_swift_info(
        *,
        modules = [],
        swift_infos = [],
        swift_version = None):
    """Creates a new `SwiftInfo` provider with the given values.

    This function is recommended instead of directly creating a `SwiftInfo`
    provider because it encodes reasonable defaults for fields that some rules
    may not be interested in and ensures that the direct and transitive fields
    are set consistently.

    This function can also be used to do a simple merge of `SwiftInfo`
    providers, by leaving all of the arguments except for `swift_infos` as their
    empty defaults. In that case, the returned provider will not represent a
    true Swift module; it is merely a "collector" for other dependencies.

    Args:
        modules: A list of values (as returned by `swift_common.create_module`)
            that represent Clang and/or Swift module artifacts that are direct
            outputs of the target being built.
        swift_infos: A list of `SwiftInfo` providers from dependencies, whose
            transitive fields should be merged into the new one. If omitted, no
            transitive data is collected.
        swift_version: A string containing the value of the `-swift-version`
            flag used when compiling this target, or `None` (the default) if it
            was not set or is not relevant.

    Returns:
        A new `SwiftInfo` provider with the given values.
    """

    defines_set = sets.make()
    for module in modules:
        swift_module = module.swift
        if not swift_module:
            continue

        if swift_module.defines:
            defines_set = sets.union(
                defines_set,
                sets.make(swift_module.defines),
            )

    defines = sets.to_list(defines_set)

    transitive_defines = []
    transitive_modules = []
    for swift_info in swift_infos:
        transitive_defines.append(swift_info.transitive_defines)
        transitive_modules.append(swift_info.transitive_modules)

    return SwiftInfo(
        direct_defines = defines,
        direct_modules = modules,
        swift_version = swift_version,
        transitive_defines = depset(defines, transitive = transitive_defines),
        transitive_modules = depset(modules, transitive = transitive_modules),
    )
