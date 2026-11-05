from pathlib import Path
import re

manifest = Path("android/app/src/main/AndroidManifest.xml")
manifest_text = manifest.read_text(encoding="utf-8")

permission = '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />'
if permission not in manifest_text:
    manifest_text = manifest_text.replace(
        "<application",
        permission + "\n    <application",
        1,
    )

receivers = """
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
"""
if "ScheduledNotificationReceiver" not in manifest_text:
    manifest_text = manifest_text.replace(
        "</application>",
        receivers + "\n    </application>",
        1,
    )
manifest.write_text(manifest_text, encoding="utf-8")

kotlin_gradle = Path("android/app/build.gradle.kts")
groovy_gradle = Path("android/app/build.gradle")

if kotlin_gradle.exists():
    gradle_path = kotlin_gradle
    gradle_text = gradle_path.read_text(encoding="utf-8")

    if "isCoreLibraryDesugaringEnabled" not in gradle_text:
        gradle_text, count = re.subn(
            r"(compileOptions\s*\{)",
            r"\1\n        isCoreLibraryDesugaringEnabled = true",
            gradle_text,
            count=1,
        )
        if count == 0:
            raise SystemExit("Could not find compileOptions block in build.gradle.kts")

    if "coreLibraryDesugaring(" not in gradle_text:
        gradle_text, count = re.subn(
            r"(dependencies\s*\{)",
            r'\1\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
            gradle_text,
            count=1,
        )
        if count == 0:
            raise SystemExit("Could not find dependencies block in build.gradle.kts")

elif groovy_gradle.exists():
    gradle_path = groovy_gradle
    gradle_text = gradle_path.read_text(encoding="utf-8")

    if "coreLibraryDesugaringEnabled" not in gradle_text:
        gradle_text, count = re.subn(
            r"(compileOptions\s*\{)",
            r"\1\n        coreLibraryDesugaringEnabled true",
            gradle_text,
            count=1,
        )
        if count == 0:
            raise SystemExit("Could not find compileOptions block in build.gradle")

    if "coreLibraryDesugaring " not in gradle_text:
        gradle_text, count = re.subn(
            r"(dependencies\s*\{)",
            r"\1\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'",
            gradle_text,
            count=1,
        )
        if count == 0:
            raise SystemExit("Could not find dependencies block in build.gradle")
else:
    raise SystemExit("Could not find Android app Gradle build file")

gradle_path.write_text(gradle_text, encoding="utf-8")
print("Android notification receivers and core library desugaring configured.")
