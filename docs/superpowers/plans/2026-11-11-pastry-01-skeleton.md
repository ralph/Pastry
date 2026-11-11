# Pastry Feature 1: Skeleton — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Pastry repository and a buildable, launchable macOS agent app that shows a scissors icon in the menu bar with a working Quit item.

**Architecture:** A hand-written `Pastry.xcodeproj` using Xcode's synchronized folder groups, so Swift files added to `Pastry/` and `PastryTests/` join their targets with no `project.pbxproj` edits. The app is a SwiftUI `App` whose only scene is a placeholder `Settings` scene; all menu-bar behaviour lives in an AppKit `NSApplicationDelegate`. The menu-bar glyph is extracted into its own unit so it can be tested without launching anything.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Testing, Xcode 27, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md`

## Global Constraints

These apply to every task in this plan and every later Pastry plan.

- Minimum deployment target: **macOS 26.0**.
- Swift language mode **6.0** (strict concurrency on).
- **Zero third-party dependencies.** No SwiftPM packages, no CocoaPods, no vendored sources.
- Bundle identifier: **`de.rvdh.Pastry`**. Test bundle: `de.rvdh.PastryTests`.
- Apple Team ID: **`89S4HZY343`**.
- App is an agent: `LSUIElement = YES`, no Dock icon, no app menu bar.
- Not sandboxed. Hardened runtime enabled.
- Repository: **`ralph/Pastry`**, private, standalone (not a GitHub fork).
- Flycut is MIT licensed — `license.txt` stays, and attribution is preserved.
- The Objective-C tree stays untouched in this feature. It is deleted in feature 10.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `Pastry.xcodeproj/project.pbxproj` | Two targets, synchronized folder groups, build settings |
| `Pastry.xcodeproj/xcshareddata/xcschemes/Pastry.xcscheme` | Shared scheme so `xcodebuild -scheme Pastry` works in CI |
| `Pastry/PastryApp.swift` | `@main` entry point; wires the AppKit delegate, declares the placeholder Settings scene |
| `Pastry/AppDelegate.swift` | Owns the `NSStatusItem` and its menu; skips setup under tests |
| `Pastry/MenuBarIcon.swift` | Resolves the menu-bar glyph as a template image |
| `Pastry/AppEnvironment.swift` | Detects whether the process is running a test bundle |
| `PastryTests/MenuBarIconTests.swift` | Verifies the glyph resolves and is a template image |
| `PastryTests/AppEnvironmentTests.swift` | Verifies test detection from a supplied environment |
| `.github/workflows/ci.yml` | Builds and tests on every push and pull request |
| `.gitignore` | Updated so the shared scheme is **not** ignored |

---

## Task 1: Repository

Move the working copy onto a new private standalone repository, keeping full git history so that feature 10's deletion commit has meaning.

**Files:**
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces: an `origin` remote pointing at `ralph/Pastry`; the old fork reachable as the `flycut` remote.

- [ ] **Step 1: Confirm the working tree is clean and on master**

```bash
git status --short && git branch --show-current
```

Expected: no output from `git status --short`, and `master`. Stop and resolve if anything is uncommitted.

- [ ] **Step 2: Create the private repository**

```bash
gh repo create ralph/Pastry --private --description "A small macOS clipboard history manager, in Swift"
```

Expected: prints the URL of the new repository. If it reports the name is taken, stop and ask — do not pick a different name silently.

- [ ] **Step 3: Repoint the remotes**

```bash
git remote remove upstream
git remote rename origin flycut
git remote add origin https://github.com/ralph/Pastry.git
git remote -v
```

Expected: `origin` → `ralph/Pastry`, `flycut` → `ralph/Flycut`. The old fork stays reachable but is never pushed to again.

- [ ] **Step 4: Push history to the new repository**

```bash
git push -u origin master
```

Expected: the push succeeds and prints a new-branch confirmation. `master` now carries the full Flycut history plus the spec and this plan, so feature 10's deletion commit has something to delete against.

---

## Task 2: Feature branch and draft pull request

Open the pull request before writing code, so the implementation lands as reviewable commits on an existing branch.

**Files:**
- Modify: `.gitignore`

**Interfaces:**
- Consumes: the `origin` remote from Task 1.
- Produces: branch `feature/01-skeleton` and an open draft pull request against `master`.

- [ ] **Step 1: Create the feature branch**

```bash
git checkout -b feature/01-skeleton
```

- [ ] **Step 2: Fix `.gitignore` so shared schemes are tracked**

The inherited file ignores `xcshareddata` wholesale, which would silently drop the scheme CI needs. Replace the whole file with:

```gitignore
.DS_Store
*.swp
*~.nib
build/
DerivedData/
*.pbxuser
*.perspective
*.perspectivev3
*.mode1v3
*.mode2v3
xcuserdata/
*.xcuserdatad
.swiftpm/
```

Shared schemes live under `*.xcodeproj/xcshareddata/xcschemes/` and must be committed.

- [ ] **Step 3: Verify the scheme path is not ignored**

```bash
git check-ignore -v Pastry.xcodeproj/xcshareddata/xcschemes/Pastry.xcscheme; echo "exit=$?"
```

Expected: `exit=1` and no output — meaning the path is **not** ignored. If it prints a matching rule, the replacement above did not take effect.

- [ ] **Step 4: Commit and push the branch**

```bash
git add .gitignore
git commit -m "Track shared Xcode schemes, ignore derived data

The inherited rule ignored xcshareddata wholesale, which would drop the
shared scheme that CI needs to build the project.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push -u origin feature/01-skeleton
```

- [ ] **Step 5: Open the draft pull request**

```bash
gh pr create --repo ralph/Pastry --base master --head feature/01-skeleton \
  --draft --title "Feature 1: project skeleton" --body "$(cat <<'BODY'
First step of the Swift rewrite described in
`docs/superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md`.

Adds the Pastry Xcode project, an LSUIElement agent app showing a
scissors status item with a working Quit, a unit test target, and CI.

The Objective-C Flycut sources are untouched; they are deleted in
feature 10.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"
```

Expected: prints the pull request URL. Keep it — later steps push to this branch and the review happens here.

---

## Task 3: Xcode project that builds an empty agent app

**Files:**
- Create: `Pastry.xcodeproj/project.pbxproj`
- Create: `Pastry.xcodeproj/xcshareddata/xcschemes/Pastry.xcscheme`
- Create: `Pastry/PastryApp.swift`
- Create: `PastryTests/PlaceholderTests.swift`

**Interfaces:**
- Consumes: the `origin` remote from Task 1.
- Produces: an `xcodebuild`-buildable scheme named `Pastry`; targets `Pastry` (app) and `PastryTests` (app-hosted unit tests); an app module importable as `@testable import Pastry`.

- [ ] **Step 1: Create the source folders**

```bash
mkdir -p Pastry PastryTests Pastry.xcodeproj/xcshareddata/xcschemes
```

- [ ] **Step 2: Write `Pastry/PastryApp.swift`**

A SwiftUI `App` needs at least one scene. `Settings` is the conventional choice for a menu-bar-only app: it contributes no window until something opens it. It is a placeholder here and is filled in during feature 8.

```swift
import SwiftUI

@main
struct PastryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

- [ ] **Step 3: Write a placeholder `Pastry/AppDelegate.swift`**

Replaced with the real implementation in Task 3. It exists now so the project compiles.

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
    }
}
```

- [ ] **Step 4: Write `PastryTests/PlaceholderTests.swift`**

Proves the test target is wired up and `@testable import` links against the app. Deleted at the end of Task 3, once real tests exist.

```swift
import Testing
@testable import Pastry

@Test func testTargetIsWiredUp() {
    #expect(Bool(true))
}
```

- [ ] **Step 5: Write `Pastry.xcodeproj/project.pbxproj`**

`objectVersion = 77` and `PBXFileSystemSynchronizedRootGroup` are what make the folders self-maintaining: any `.swift` file placed in `Pastry/` or `PastryTests/` joins its target automatically.

```
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 77;
	objects = {

/* Begin PBXContainerItemProxy section */
		1A000000000000000000002A /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = 1A0000000000000000000001 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = 1A0000000000000000000010;
			remoteInfo = Pastry;
		};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
		1A0000000000000000000017 /* Pastry.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Pastry.app; sourceTree = BUILT_PRODUCTS_DIR; };
		1A0000000000000000000027 /* PastryTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = PastryTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		1A0000000000000000000018 /* Pastry */ = {isa = PBXFileSystemSynchronizedRootGroup; path = Pastry; sourceTree = "<group>"; };
		1A0000000000000000000028 /* PastryTests */ = {isa = PBXFileSystemSynchronizedRootGroup; path = PastryTests; sourceTree = "<group>"; };
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		1A0000000000000000000015 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		1A0000000000000000000025 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		1A0000000000000000000005 = {
			isa = PBXGroup;
			children = (
				1A0000000000000000000018 /* Pastry */,
				1A0000000000000000000028 /* PastryTests */,
				1A0000000000000000000006 /* Products */,
			);
			sourceTree = "<group>";
		};
		1A0000000000000000000006 /* Products */ = {
			isa = PBXGroup;
			children = (
				1A0000000000000000000017 /* Pastry.app */,
				1A0000000000000000000027 /* PastryTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		1A0000000000000000000010 /* Pastry */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 1A0000000000000000000011 /* Build configuration list for PBXNativeTarget "Pastry" */;
			buildPhases = (
				1A0000000000000000000014 /* Sources */,
				1A0000000000000000000015 /* Frameworks */,
				1A0000000000000000000016 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				1A0000000000000000000018 /* Pastry */,
			);
			name = Pastry;
			packageProductDependencies = (
			);
			productName = Pastry;
			productReference = 1A0000000000000000000017 /* Pastry.app */;
			productType = "com.apple.product-type.application";
		};
		1A0000000000000000000020 /* PastryTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 1A0000000000000000000021 /* Build configuration list for PBXNativeTarget "PastryTests" */;
			buildPhases = (
				1A0000000000000000000024 /* Sources */,
				1A0000000000000000000025 /* Frameworks */,
				1A0000000000000000000026 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				1A0000000000000000000029 /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				1A0000000000000000000028 /* PastryTests */,
			);
			name = PastryTests;
			packageProductDependencies = (
			);
			productName = PastryTests;
			productReference = 1A0000000000000000000027 /* PastryTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		1A0000000000000000000001 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2700;
				LastUpgradeCheck = 2700;
				TargetAttributes = {
					1A0000000000000000000010 = {
						CreatedOnToolsVersion = 27.0;
					};
					1A0000000000000000000020 = {
						CreatedOnToolsVersion = 27.0;
						TestTargetID = 1A0000000000000000000010;
					};
				};
			};
			buildConfigurationList = 1A0000000000000000000002 /* Build configuration list for PBXProject "Pastry" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 1A0000000000000000000005;
			minimizedProjectReferenceProxies = 1;
			preferredProjectObjectVersion = 77;
			productRefGroup = 1A0000000000000000000006 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				1A0000000000000000000010 /* Pastry */,
				1A0000000000000000000020 /* PastryTests */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		1A0000000000000000000016 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		1A0000000000000000000026 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		1A0000000000000000000014 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		1A0000000000000000000024 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		1A0000000000000000000029 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = 1A0000000000000000000010 /* Pastry */;
			targetProxy = 1A000000000000000000002A /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		1A0000000000000000000003 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_OBJC_WEAK = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				MACOSX_DEPLOYMENT_TARGET = 26.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 6.0;
			};
			name = Debug;
		};
		1A0000000000000000000004 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_OBJC_WEAK = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				MACOSX_DEPLOYMENT_TARGET = 26.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_VERSION = 6.0;
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		1A0000000000000000000012 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 89S4HZY343;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_LSUIElement = YES;
				MARKETING_VERSION = 0.1.0;
				PRODUCT_BUNDLE_IDENTIFIER = de.rvdh.Pastry;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
			};
			name = Debug;
		};
		1A0000000000000000000013 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 89S4HZY343;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_LSUIElement = YES;
				MARKETING_VERSION = 0.1.0;
				PRODUCT_BUNDLE_IDENTIFIER = de.rvdh.Pastry;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
			};
			name = Release;
		};
		1A0000000000000000000022 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				DEVELOPMENT_TEAM = 89S4HZY343;
				GENERATE_INFOPLIST_FILE = YES;
				PRODUCT_BUNDLE_IDENTIFIER = de.rvdh.PastryTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Pastry.app/Contents/MacOS/Pastry";
			};
			name = Debug;
		};
		1A0000000000000000000023 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				DEVELOPMENT_TEAM = 89S4HZY343;
				GENERATE_INFOPLIST_FILE = YES;
				PRODUCT_BUNDLE_IDENTIFIER = de.rvdh.PastryTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Pastry.app/Contents/MacOS/Pastry";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		1A0000000000000000000002 /* Build configuration list for PBXProject "Pastry" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				1A0000000000000000000003 /* Debug */,
				1A0000000000000000000004 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		1A0000000000000000000011 /* Build configuration list for PBXNativeTarget "Pastry" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				1A0000000000000000000012 /* Debug */,
				1A0000000000000000000013 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		1A0000000000000000000021 /* Build configuration list for PBXNativeTarget "PastryTests" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				1A0000000000000000000022 /* Debug */,
				1A0000000000000000000023 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = 1A0000000000000000000001 /* Project object */;
}
```

- [ ] **Step 6: Verify Xcode can parse the project**

```bash
xcodebuild -list -project Pastry.xcodeproj
```

Expected: targets `Pastry` and `PastryTests` listed, build configurations `Debug` and `Release`.

If this fails with a parse error, the problem is in the file written in Step 5 — the most likely causes are a missing trailing comma inside a list, an unbalanced brace, or a 24-character object ID that was mistyped. Do not proceed until it parses.

- [ ] **Step 7: Write the shared scheme**

CI invokes `-scheme Pastry`, which only works if the scheme is shared and committed.

File `Pastry.xcodeproj/xcshareddata/xcschemes/Pastry.xcscheme`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2700"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "1A0000000000000000000010"
               BuildableName = "Pastry.app"
               BlueprintName = "Pastry"
               ReferencedContainer = "container:Pastry.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "1A0000000000000000000020"
               BuildableName = "PastryTests.xctest"
               BlueprintName = "PastryTests"
               ReferencedContainer = "container:Pastry.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
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
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "1A0000000000000000000010"
            BuildableName = "Pastry.app"
            BlueprintName = "Pastry"
            ReferencedContainer = "container:Pastry.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "1A0000000000000000000010"
            BuildableName = "Pastry.app"
            BlueprintName = "Pastry"
            ReferencedContainer = "container:Pastry.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
```

- [ ] **Step 8: Verify the scheme is visible to `xcodebuild`**

```bash
xcodebuild -list -project Pastry.xcodeproj | grep -A3 Schemes
```

Expected: `Pastry` appears under `Schemes:`.

- [ ] **Step 9: Build the app**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 10: Run the test target**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry -configuration Debug test 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **` with one passing test. Note this build signs for real (app-hosted tests must be runnable), so it uses the Developer ID / development identity already on this Mac.

- [ ] **Step 11: Commit**

```bash
git add Pastry.xcodeproj Pastry PastryTests
git commit -m "Add Pastry Xcode project and app skeleton

Two targets, built from synchronized folder groups so adding a Swift
file never means editing project.pbxproj. The app is an LSUIElement
agent whose only scene is a placeholder Settings scene; menu-bar
behaviour arrives in the next commit.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: Scissors menu-bar item with Quit

**Files:**
- Create: `Pastry/MenuBarIcon.swift`
- Create: `Pastry/AppEnvironment.swift`
- Create: `PastryTests/MenuBarIconTests.swift`
- Create: `PastryTests/AppEnvironmentTests.swift`
- Modify: `Pastry/AppDelegate.swift`
- Delete: `PastryTests/PlaceholderTests.swift`

**Interfaces:**
- Consumes: `AppDelegate` from Task 2.
- Produces:
  - `enum MenuBarIcon { static let symbolName: String; static func image() -> NSImage? }`
  - `enum AppEnvironment { static var isRunningTests: Bool { get }; static func isRunningTests(environment: [String: String], hasXCTestClass: Bool) -> Bool }`
  - `AppDelegate.statusItem: NSStatusItem?` — later features attach their menu to this.

- [ ] **Step 1: Write the failing test for the menu-bar glyph**

File `PastryTests/MenuBarIconTests.swift`:

```swift
import AppKit
import Testing
@testable import Pastry

@Suite("MenuBarIcon")
struct MenuBarIconTests {
    @Test("resolves the system symbol on this OS")
    func resolvesSymbol() {
        #expect(MenuBarIcon.image() != nil)
    }

    @Test("is a template image so it follows menu bar appearance")
    func isTemplate() {
        #expect(MenuBarIcon.image()?.isTemplate == true)
    }
}
```

- [ ] **Step 2: Run it to make sure it fails**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | tail -20
```

Expected: FAIL to compile — `cannot find 'MenuBarIcon' in scope`.

- [ ] **Step 3: Write the minimal implementation**

File `Pastry/MenuBarIcon.swift`:

```swift
import AppKit

/// The glyph shown in the menu bar.
///
/// Rendered from an SF Symbol as a template image so it tracks light and dark
/// mode, menu bar tinting and accessibility sizes without shipping bitmaps.
enum MenuBarIcon {
    static let symbolName = "scissors"

    static func image() -> NSImage? {
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Pastry"
        )
        image?.isTemplate = true
        return image
    }
}
```

- [ ] **Step 4: Run the tests and make sure they pass**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Write the failing test for test-environment detection**

App-hosted tests launch the real app, so `applicationDidFinishLaunching` runs during every test. Without a guard, every later feature's timers, status items and hotkeys would start up inside the test process. This is the guard, and it is pure enough to test directly.

File `PastryTests/AppEnvironmentTests.swift`:

```swift
import Testing
@testable import Pastry

@Suite("AppEnvironment")
struct AppEnvironmentTests {
    @Test("detects a test run from the XCTest configuration variable")
    func detectsFromEnvironment() {
        let environment = ["XCTestConfigurationFilePath": "/tmp/whatever.xctestconfiguration"]
        #expect(AppEnvironment.isRunningTests(environment: environment, hasXCTestClass: false))
    }

    @Test("detects a test run from the presence of the XCTest runtime")
    func detectsFromRuntime() {
        #expect(AppEnvironment.isRunningTests(environment: [:], hasXCTestClass: true))
    }

    @Test("reports a normal launch when neither signal is present")
    func detectsNormalLaunch() {
        #expect(!AppEnvironment.isRunningTests(environment: [:], hasXCTestClass: false))
    }

    @Test("reports a test run for the live process, since this is one")
    func liveProcessIsATestRun() {
        #expect(AppEnvironment.isRunningTests)
    }
}
```

- [ ] **Step 6: Run it to make sure it fails**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | tail -20
```

Expected: FAIL to compile — `cannot find 'AppEnvironment' in scope`.

- [ ] **Step 7: Write the minimal implementation**

File `Pastry/AppEnvironment.swift`:

```swift
import Foundation

/// Whether this process is running a test bundle rather than a real launch.
///
/// Unit tests are hosted by the app, so the app delegate runs during every
/// test. Side effects such as timers, status items and global hotkeys are
/// skipped when this reports `true`.
enum AppEnvironment {
    static var isRunningTests: Bool {
        isRunningTests(
            environment: ProcessInfo.processInfo.environment,
            hasXCTestClass: NSClassFromString("XCTestCase") != nil
        )
    }

    static func isRunningTests(
        environment: [String: String],
        hasXCTestClass: Bool
    ) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil || hasXCTestClass
    }
}
```

- [ ] **Step 8: Run the tests and make sure they pass**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, seven tests passing — two for `MenuBarIcon`, four for `AppEnvironment`, and the placeholder from Task 2, which Step 10 deletes.

- [ ] **Step 9: Implement the status item**

Replace the whole contents of `Pastry/AppDelegate.swift`:

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isRunningTests else { return }
        installStatusItem()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = MenuBarIcon.image()
        item.menu = makeMenu()
        statusItem = item
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Quit Pastry",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        return menu
    }
}
```

- [ ] **Step 10: Delete the placeholder test**

```bash
rm PastryTests/PlaceholderTests.swift
```

- [ ] **Step 11: Run the tests again**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, six tests passing, no reference to the deleted placeholder. This also confirms synchronized folder groups pick up additions and removals without touching `project.pbxproj`.

- [ ] **Step 12: Launch the app and verify it by eye**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry -configuration Debug -derivedDataPath build/dd build 2>&1 | tail -3
open build/dd/Build/Products/Debug/Pastry.app
```

Verify, in order:
1. A scissors icon appears in the menu bar.
2. No Pastry icon appears in the Dock, and no app menu bar appears when it is frontmost.
3. Clicking the icon opens a menu containing "Quit Pastry".
4. Choosing Quit terminates the app and the icon disappears.

If the app does appear in the Dock, `INFOPLIST_KEY_LSUIElement` did not make it into the built `Info.plist` — check with
`plutil -p build/dd/Build/Products/Debug/Pastry.app/Contents/Info.plist | grep LSUIElement`.

- [ ] **Step 13: Commit**

```bash
git add Pastry PastryTests
git commit -m "Show a scissors status item with a Quit menu

The glyph is the SF Symbol rendered as a template image, so it tracks
menu bar appearance without bundled bitmaps. AppEnvironment keeps the
delegate's side effects out of app-hosted test runs, which launch the
real app for every test.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: Continuous integration

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: the shared `Pastry` scheme from Task 2.
- Produces: a required-status-check-able `build-test` job.

- [ ] **Step 1: Confirm a runner image with the macOS 26 SDK exists**

The deployment target is macOS 26.0, so the runner needs the macOS 26 SDK. Check what GitHub currently offers:

```bash
gh api /repos/actions/runner-images/contents/images/macos --jq '.[].name'
```

Expected: a list of image README files such as `macos-26-Readme.md`. Use the highest-numbered macOS label available as `runs-on` in the next step. If no image at macOS 26 or newer exists, stop and report it — CI cannot build this deployment target, and the choice is either to wait or to lower the floor, which is the user's call.

- [ ] **Step 2: Write the workflow**

File `.github/workflows/ci.yml`, substituting the runner label confirmed in Step 1 for `macos-26`:

```yaml
name: CI

on:
  push:
    branches: [master]
  pull_request:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-test:
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable

      - name: Show toolchain
        run: |
          xcodebuild -version
          xcodebuild -showsdks | grep macosx

      - name: Build
        run: |
          xcodebuild -project Pastry.xcodeproj -scheme Pastry \
            -configuration Debug build CODE_SIGNING_ALLOWED=NO

      - name: Test
        run: |
          xcodebuild -project Pastry.xcodeproj -scheme Pastry \
            -configuration Debug test CODE_SIGNING_ALLOWED=NO
```

Signing is disabled on CI; app-hosted tests still run because the runner allows ad-hoc-signed bundles to launch locally.

- [ ] **Step 3: Verify the workflow file parses**

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml')); print('valid YAML')"
```

Expected: `valid YAML`.

- [ ] **Step 4: Commit and push the branch**

```bash
git add .github/workflows/ci.yml
git commit -m "Build and test Pastry on every push and pull request

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
```

- [ ] **Step 5: Confirm CI is green**

```bash
gh pr checks --repo ralph/Pastry --watch
```

Expected: the `build-test` check passes. If the runner image lacks the macOS 26 SDK despite Step 1, that surfaces here as a build failure naming an unavailable deployment target.

---

## Feature-completion checklist

Before marking the pull request ready for review:

- [ ] `xcodebuild -list -project Pastry.xcodeproj` lists both targets and the shared scheme.
- [ ] `xcodebuild ... test` passes locally with six tests.
- [ ] The app launches, shows the scissors icon, has no Dock icon, and Quit works.
- [ ] CI is green on the pull request.
- [ ] `git remote -v` shows `origin` → `ralph/Pastry`.
- [ ] No Objective-C file was modified or deleted.

Then follow the project workflow: `/simplify`, mark ready for review, `/code-review medium`, a Codex review, and squash merge.
