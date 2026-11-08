#!/usr/bin/env python3
"""Generates Crowns.xcodeproj from the folders on disk.

    python3 Tools/gen_xcodeproj.py

Target membership is by folder:
    Crowns/        app
    CrownsShare/   share extension
    Shared/        compiled into the app, the extension and the tests
    CrownsTests/   unit tests (Swift Testing), Fixtures/ as resources
    Config/        xcconfig, Info.plists, entitlements (not compiled)

Re-run after adding or removing files. Adding files in Xcode also works; the
next run of this script picks them up from disk either way. Object IDs are
derived from paths, so the output is stable and diffs stay small.
"""
import hashlib
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJ = os.path.join(ROOT, "Crowns.xcodeproj")


def oid(*parts):
    return hashlib.md5("/".join(parts).encode()).hexdigest()[:24].upper()


def q(s):
    s = str(s)
    if s and all(c.isalnum() or c in "._/$" for c in s) and not s.startswith("$"):
        return s
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".js": "sourcecode.javascript",
    ".json": "text.json",
    ".plist": "text.plist.xml",
    ".entitlements": "text.plist.entitlements",
    ".xcconfig": "text.xcconfig",
    ".xcassets": "folder.assetcatalog",
    ".icon": "folder.iconcomposer.icon",
    ".md": "net.daringfireball.markdown",
    ".xcprivacy": "text.xml",
}

TOP_GROUPS = ["Crowns", "CrownsShare", "Shared", "CrownsTests", "Config"]

objects = {}  # id -> (isa, dict)
files = {}  # relpath -> file ref id
groups = {}  # relpath -> (group id, [child ids])


def add(obj_id, isa, **fields):
    objects[obj_id] = (isa, fields)
    return obj_id


def walk(rel):
    gid = oid("group", rel)
    children = []
    full = os.path.join(ROOT, rel)
    for name in sorted(os.listdir(full), key=lambda n: (not os.path.isdir(os.path.join(full, n)) or n.endswith((".xcassets", ".icon")), n.lower())):
        if name.startswith(".") or name == "node_modules":
            continue
        child_rel = os.path.join(rel, name)
        child_full = os.path.join(ROOT, child_rel)
        ext = os.path.splitext(name)[1]
        if os.path.isdir(child_full) and ext not in (".xcassets", ".icon"):
            children.append(walk(child_rel))
        elif ext in FILE_TYPES:
            fid = oid("file", child_rel)
            add(fid, "PBXFileReference", lastKnownFileType=FILE_TYPES[ext], path=name, sourceTree="<group>")
            files[child_rel] = fid
            children.append(fid)
    add(gid, "PBXGroup", children=children, path=os.path.basename(rel), sourceTree="<group>")
    return gid


top = [walk(g) for g in TOP_GROUPS]


def matching(prefixes, exts):
    return sorted(p for p in files if any(p.startswith(pre + "/") for pre in prefixes) and os.path.splitext(p)[1] in exts)


# ---------------------------------------------------------------- products
PRODUCTS = {
    "Crowns": ("Crowns.app", "wrapper.application", "com.apple.product-type.application"),
    "CrownsShare": ("CrownsShare.appex", "wrapper.app-extension", "com.apple.product-type.app-extension"),
    "CrownsTests": ("CrownsTests.xctest", "wrapper.cfbundle", "com.apple.product-type.bundle.unit-test"),
}
product_refs = {}
for t, (name, ftype, _) in PRODUCTS.items():
    product_refs[t] = add(oid("product", t), "PBXFileReference", explicitFileType=ftype, includeInIndex="0", path=name, sourceTree="BUILT_PRODUCTS_DIR")
products_group = add(oid("group", "Products"), "PBXGroup", children=list(product_refs.values()), name="Products", sourceTree="<group>")
main_group = add(oid("group", "<main>"), "PBXGroup", children=top + [products_group], sourceTree="<group>")

MEMBERSHIP = {
    "Crowns": {
        "sources": matching(["Crowns", "Shared"], {".swift"}),
        "resources": matching(["Crowns"], {".xcassets", ".icon", ".xcprivacy"}) + matching(["Shared"], {".js"}),
    },
    "CrownsShare": {
        "sources": matching(["CrownsShare", "Shared"], {".swift"}),
        "resources": matching(["CrownsShare"], {".xcprivacy"}) + matching(["Shared"], {".js"}),
    },
    "CrownsTests": {
        "sources": matching(["CrownsTests", "Shared"], {".swift"}),
        "resources": matching(["CrownsTests"], {".json"}),
    },
}


def phase(target, kind, paths):
    build_files = []
    for p in paths:
        bid = add(oid("build", target, kind, p), "PBXBuildFile", fileRef=files[p])
        build_files.append(bid)
    isa = {"sources": "PBXSourcesBuildPhase", "resources": "PBXResourcesBuildPhase", "frameworks": "PBXFrameworksBuildPhase"}[kind]
    return add(oid("phase", target, kind), isa, buildActionMask="2147483647", files=build_files, runOnlyForDeploymentPostprocessing="0")


# ---------------------------------------------------------------- settings
COMMON = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_ENABLE_OBJC_WEAK": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
    "MTL_FAST_MATH": "YES",
    "SDKROOT": "iphoneos",
    "TARGETED_DEVICE_FAMILY": "1,2",
}
DEBUG = {
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
}
RELEASE = {
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "ENABLE_NS_ASSERTIONS": "NO",
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "VALIDATE_PRODUCT": "YES",
}
TARGET_SETTINGS = {
    "Crowns": {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "Crowns",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_ENTITLEMENTS": "Config/Crowns.entitlements",
        "CODE_SIGN_STYLE": "Automatic",
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "YES",
        "INFOPLIST_FILE": "Config/Crowns-Info.plist",
        "INFOPLIST_KEY_CFBundleDisplayName": "Crowns",
        "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.lifestyle",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
        "PRODUCT_BUNDLE_IDENTIFIER": "$(CROWNS_APP_BUNDLE_ID)",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
    },
    "CrownsShare": {
        "APPLICATION_EXTENSION_API_ONLY": "YES",
        "CODE_SIGN_ENTITLEMENTS": "Config/CrownsShare.entitlements",
        "CODE_SIGN_STYLE": "Automatic",
        "GENERATE_INFOPLIST_FILE": "YES",
        "INFOPLIST_FILE": "Config/CrownsShare-Info.plist",
        "INFOPLIST_KEY_CFBundleDisplayName": "Crowns",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"],
        "PRODUCT_BUNDLE_IDENTIFIER": "$(CROWNS_APP_BUNDLE_ID).share",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SKIP_INSTALL": "YES",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
    },
    "CrownsTests": {
        "CODE_SIGN_STYLE": "Automatic",
        "GENERATE_INFOPLIST_FILE": "YES",
        "PRODUCT_BUNDLE_IDENTIFIER": "$(CROWNS_APP_BUNDLE_ID).tests",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SWIFT_EMIT_LOC_STRINGS": "NO",
    },
}


def config_list(owner, debug, release, base=None):
    ids = []
    for name, settings in (("Debug", debug), ("Release", release)):
        fields = {"buildSettings": settings, "name": name}
        if base:
            fields["baseConfigurationReference"] = base
        ids.append(add(oid("config", owner, name), "XCBuildConfiguration", **fields))
    return add(oid("configlist", owner), "XCConfigurationList", buildConfigurations=ids, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")


xcconfig = files["Config/Crowns.xcconfig"]
project_id = oid("project")

targets = {}
for t in ["CrownsShare", "Crowns", "CrownsTests"]:
    phases = [phase(t, "sources", MEMBERSHIP[t]["sources"]), phase(t, "frameworks", []), phase(t, "resources", MEMBERSHIP[t]["resources"])]
    deps = []
    if t == "Crowns":
        embed_file = add(oid("build", "Crowns", "embed", "CrownsShare"), "PBXBuildFile", fileRef=product_refs["CrownsShare"], settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]})
        phases.append(add(oid("phase", "Crowns", "embed"), "PBXCopyFilesBuildPhase", buildActionMask="2147483647", dstPath="", dstSubfolderSpec="13", files=[embed_file], name="Embed Foundation Extensions", runOnlyForDeploymentPostprocessing="0"))
        proxy = add(oid("proxy", "Crowns", "CrownsShare"), "PBXContainerItemProxy", containerPortal=project_id, proxyType="1", remoteGlobalIDString=oid("target", "CrownsShare"), remoteInfo="CrownsShare")
        deps.append(add(oid("dep", "Crowns", "CrownsShare"), "PBXTargetDependency", target=oid("target", "CrownsShare"), targetProxy=proxy))
    cl = config_list(t, dict(TARGET_SETTINGS[t]), dict(TARGET_SETTINGS[t]))
    targets[t] = add(
        oid("target", t), "PBXNativeTarget",
        buildConfigurationList=cl, buildPhases=phases, buildRules=[], dependencies=deps,
        name=t, productName=t, productReference=product_refs[t], productType=PRODUCTS[t][2],
    )

project_cl = config_list("project", {**COMMON, **DEBUG}, {**COMMON, **RELEASE}, base=xcconfig)
add(
    project_id, "PBXProject",
    attributes={
        "BuildIndependentTargetsInParallel": "1",
        "LastSwiftUpdateCheck": "2600",
        "LastUpgradeCheck": "2600",
        "TargetAttributes": {targets[t]: {"CreatedOnToolsVersion": "26.0"} for t in targets},
    },
    buildConfigurationList=project_cl,
    compatibilityVersion="Xcode 14.0",
    developmentRegion="en",
    hasScannedForEncodings="0",
    knownRegions=["en", "Base"],
    mainGroup=main_group,
    productRefGroup=products_group,
    projectDirPath="",
    projectRoot="",
    targets=[targets["Crowns"], targets["CrownsShare"], targets["CrownsTests"]],
)


# ---------------------------------------------------------------- writer
def render(value, indent):
    pad = "\t" * indent
    if isinstance(value, dict):
        if not value:
            return "{\n" + pad + "}"
        lines = ["{"]
        for k in sorted(value):
            lines.append(pad + "\t" + q(k) + " = " + render(value[k], indent + 1) + ";")
        lines.append(pad + "}")
        return "\n".join(lines)
    if isinstance(value, list):
        if not value:
            return "(\n" + pad + ")"
        lines = ["("]
        for v in value:
            lines.append(pad + "\t" + render(v, indent + 1) + ",")
        lines.append(pad + ")")
        return "\n".join(lines)
    return q(value)


sections = {}
for obj_id, (isa, fields) in objects.items():
    sections.setdefault(isa, []).append((obj_id, fields))

out = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {", "\t};", "\tobjectVersion = 56;", "\tobjects = {"]
for isa in sorted(sections):
    out.append("")
    out.append("/* Begin " + isa + " section */")
    for obj_id, fields in sorted(sections[isa]):
        body = {"isa": isa, **fields}
        out.append("\t\t" + obj_id + " = " + render(body, 2) + ";")
    out.append("/* End " + isa + " section */")
out += ["\t};", "\trootObject = " + project_id + ";", "}", ""]

os.makedirs(os.path.join(PROJ, "project.xcworkspace"), exist_ok=True)
with open(os.path.join(PROJ, "project.pbxproj"), "w") as f:
    f.write("\n".join(out))
with open(os.path.join(PROJ, "project.xcworkspace", "contents.xcworkspacedata"), "w") as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n<Workspace\n   version = "1.0">\n   <FileRef\n      location = "self:">\n   </FileRef>\n</Workspace>\n')


# ---------------------------------------------------------------- schemes
def ref(t):
    return (
        f'            <BuildableReference\n'
        f'               BuildableIdentifier = "primary"\n'
        f'               BlueprintIdentifier = "{targets[t]}"\n'
        f'               BuildableName = "{PRODUCTS[t][0]}"\n'
        f'               BlueprintName = "{t}"\n'
        f'               ReferencedContainer = "container:Crowns.xcodeproj">\n'
        f'            </BuildableReference>\n'
    )


def scheme(build, launch, tests=()):
    entries = "".join(
        f'         <BuildActionEntry\n            buildForTesting = "YES"\n            buildForRunning = "YES"\n            buildForProfiling = "YES"\n            buildForArchiving = "YES"\n            buildForAnalyzing = "YES">\n{ref(t)}         </BuildActionEntry>\n'
        for t in build
    )
    testables = "".join(f'         <TestableReference\n            skipped = "NO">\n{ref(t)}         </TestableReference>\n' for t in tests)
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
{entries}      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
{testables}      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
{ref(launch)}      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''


schemes_dir = os.path.join(PROJ, "xcshareddata", "xcschemes")
os.makedirs(schemes_dir, exist_ok=True)
with open(os.path.join(schemes_dir, "Crowns.xcscheme"), "w") as f:
    f.write(scheme(["Crowns", "CrownsTests"], "Crowns", tests=["CrownsTests"]))

print(f"Wrote {PROJ} ({len(objects)} objects, {len(files)} files)")
