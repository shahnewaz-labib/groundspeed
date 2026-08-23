#!/usr/bin/env python3
"""Injects a release signing config into the CI-generated Android gradle
files, driven by android/key.properties.

Idempotent and conditional: if key.properties is absent (e.g. PR builds
without secrets) the generated debug-signed configuration is left untouched.
Handles both Groovy (build.gradle) and Kotlin DSL (build.gradle.kts)
templates.
"""
import os
import sys

APP_DIR = os.path.join("android", "app")
KEY_PROPS = os.path.join("android", "key.properties")


def find_gradle_file():
    for name in ("build.gradle", "build.gradle.kts"):
        path = os.path.join(APP_DIR, name)
        if os.path.exists(path):
            return path
    return None


def patch_groovy(src: str) -> str:
    loader = """def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

"""
    signing = """    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

"""
    if "signingConfig = signingConfigs.release" in src:
        return src  # already patched
    src = src.replace("android {", loader + "android {", 1)
    src = src.replace("    buildTypes {", signing + "    buildTypes {", 1)
    src = src.replace(
        "signingConfig = signingConfigs.debug",
        "signingConfig = signingConfigs.release",
    )
    return src


def patch_kts(src: str) -> str:
    loader = """import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

"""
    signing = """    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

"""
    if 'signingConfig = signingConfigs.getByName("release")' in src:
        return src
    src = src.replace("android {", loader + "android {", 1)
    src = src.replace("    buildTypes {", signing + "    buildTypes {", 1)
    src = src.replace(
        "signingConfig = signingConfigs.getByName(\"debug\")",
        'signingConfig = signingConfigs.getByName("release")',
    )
    return src


def main():
    if not os.path.exists(KEY_PROPS):
        print("key.properties not present; leaving debug signing untouched")
        return
    gradle = find_gradle_file()
    if gradle is None:
        sys.exit("ERROR: no android/app gradle file found")
    with open(gradle, encoding="utf-8") as f:
        src = f.read()

    patched = patch_groovy(src) if gradle.endswith(".gradle") else patch_kts(src)

    if patched == src:
        print("no changes applied (already patched or anchor missing!)")
        if "signingConfigs.release" not in patched and 'create("release")' not in patched:
            sys.exit("ERROR: signing anchors not found in gradle template")
        return

    with open(gradle, "w", encoding="utf-8") as f:
        f.write(patched)
    print(f"release signing injected into {gradle}")


if __name__ == "__main__":
    main()
