# Expo / React Native specifics

## Scaffold into an existing repo

```bash
npx --yes create-expo-app@latest /tmp/scaffold --template blank-typescript --no-install
```

Copy `App.tsx index.ts tsconfig.json package.json app.json assets .gitignore AGENTS.md
.claude/` into the repo (skip the template's LICENSE). The generated `AGENTS.md` is worth
keeping: "Expo ships breaking changes every SDK release; read the versioned docs; use
`npx expo install`". Then:

```bash
npm install
npx expo install expo-dev-client expo-build-properties expo-system-ui react-native-safe-area-context
```

`app.json` essentials:

```json
"android": {
  "package": "com.<owner>.<app>",
  "permissions": [],
  "blockedPermissions": ["android.permission.SYSTEM_ALERT_WINDOW", "android.permission.WRITE_EXTERNAL_STORAGE", "android.permission.VIBRATE"]
},
"plugins": [["expo-build-properties", { "android": { "compileSdkVersion": 37, "targetSdkVersion": 37, "minSdkVersion": 30, "buildToolsVersion": "37.0.0" } }]]
```

Expo adds `SYSTEM_ALERT_WINDOW`, `WRITE_EXTERNAL_STORAGE`, `VIBRATE` by default; block what
the app doesn't need (Play policy) and confirm in
`android/app/src/main/AndroidManifest.xml` after `npx expo prebuild -p android`. Read option
names from the installed package (`node_modules/expo-build-properties/build/pluginConfig.d.ts`),
not memory. The package ID is effectively permanent once on Play: ask the user.

`android/` is generated (CNG): never hand-edit, gitignore it, re-run prebuild.

## Dependency hygiene

- Always `npx expo install <pkg>` (SDK-matched versions).
- **Never `--legacy-peer-deps`** to get past ERESOLVE: npm then *removes* previously
  auto-installed peers (on Optimal: `@react-native/babel-preset`, `metro-config`,
  Reanimated, Worklets, gesture-handler) and Metro breaks.
- Fix conflicts by pinning: `npx expo install react-dom` aligned react-dom 19.3.0 → 19.2.3
  with react 19.2.3 after Expo Router pulled the newer one.
- Gate: `rm -rf node_modules && npm ci` must succeed before committing a lockfile.

## Patching a dependency

```bash
# edit node_modules/<pkg>/…, then generate a clean patch:
npx --yes patch-package <pkg> --exclude '(^package\.json$|/build/|\.cxx/|/\.gradle/)'
```

Apply with `scripts/apply-patches` as `"postinstall"` (uses `git apply`, idempotent, no
extra dependency). Without the excludes the patch swallows Gradle outputs inside
`node_modules`.

Known patch for expo-dev-launcher 57.0.x
(`android/src/debug/java/expo/modules/devlauncher/DevLauncherController.kt`,
`createAppIntent`): `categories.addAll(it)` NPEs because a fresh Intent's category set is
null; browser/launcher intents carry categories → "There was a problem loading the
project". Replace with `intent.categories?.forEach { addCategory(it) }`.

## Local Kotlin module (Expo Modules API)

```bash
CI=1 npx --yes create-expo-module@latest modules/<name> --local --name <Name> \
  --package com.<owner>.<app>.<name> --platform android --features AsyncFunction Event
mv modules/modules/<name> modules/<name> && rmdir modules/modules   # it nests one level too deep
rm modules/<name>/LICENSE modules/<name>/src/*Module.web.ts          # template's Expo MIT licence
echo 'modules/*/android/build/' >> .gitignore
```

Autolinking picks up `modules/` automatically; Gradle project name is `:<name>`.

Patterns that worked:

- **Optional module from JS**: `requireOptionalNativeModule<…>('Name')` and call newer
  functions as `engine?.newFn?.()`. JS ships via hot reload long before a phone gets the
  new APK; this keeps old builds working on mock data instead of crashing.
- **Long work**: `AsyncFunction("x") Coroutine { -> withContext(Dispatchers.IO) { … } }`.
  The default async queue is a single thread; don't block it.
- **Progress**: `Events("onProgress")` + `sendEvent(...)` throttled (~250 ms); JS
  `engine.addListener(...)` with cleanup.
- **Runtime permissions**: `appContext.permissions?.askForPermissions({ cont.resume(Unit) }, *perms)`
  inside `suspendCancellableCoroutine`, then re-read the real state with
  `ContextCompat.checkSelfPermission`. On Android 14+ request READ_MEDIA_IMAGES,
  READ_MEDIA_VIDEO **and** READ_MEDIA_VISUAL_USER_SELECTED together, so the system offers
  "Allow limited access". Declare them in the module's `AndroidManifest.xml`
  (+ `READ_EXTERNAL_STORAGE maxSdkVersion=32`).
- **System dialogs that return a result** (e.g. `MediaStore.createTrashRequest(...).intentSender`):
  `activity.startIntentSenderForResult(sender, REQ, null, 0, 0, 0)` on Main, a
  `CompletableDeferred<Boolean>`, completed in `OnActivityResult { _, p -> if (p.requestCode == REQ) … }`.
- **Numbers across the bridge**: send `Long` as `Double`.
- Read API names in `node_modules/expo-modules-core/android/src/main/java/...`
  (`Exceptions.ReactContextLost`, `PermissionsModuleNotFound`, `MissingActivity`,
  `AsyncFunctionBuilder.Coroutine`).

## Unit tests for the Kotlin side

`./gradlew :<module>:testDebugUnitTest` (results in
`modules/<m>/android/build/test-results/`). Keep logic pure and testable:

- Keep `android.net.Uri` out of data classes (store URIs as `String`); framework classes
  throw "not mocked" in JVM tests.
- `org.json` is framework too: add `testImplementation "org.json:json:<latest>"`.
- Put system effects behind an interface (`MediaTrash { trash(); restore() }`) and test the
  policy with a fake (undo restores exactly, declined dialog logs nothing, caps, windows).

## Fast Refresh discipline

- Typecheck (`npx tsc --noEmit`) after each edit batch.
- Renames/moves: update importers first, then delete; or one command. A half-applied
  state is pushed to every device and sticks ("failed to compile") until a manual Reload.
- Changing a component's props: update the parent in the same step.
- `Write` can be rejected if the file changed since read (your own sed/python edits count):
  re-read before rewriting, and never follow a rejected write with deletions that depend on it.

## Hooks gotcha

Selecting a hook implementation by a constant (`engine ? useReal() : useMock()`) works but
reads as a rules-of-hooks violation; pick once at module scope:
`export const useX = engine ? useReal : useMock;`.

## Navigation/state notes

- Tabs that unmount lose state; keep them mounted and hide with `display: 'none'`.
- Detail screens as an absolute overlay must be their own `SafeAreaView`.
- RN 0.86 removed `StyleSheet.absoluteFillObject`; spell out `position/top/right/bottom/left`.
- PanResponder `locationX` is relative to the touched child on Android; use
  `gesture.moveX` minus the frame's `measureInWindow` x.
