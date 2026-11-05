from pathlib import Path
import re

manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text()
permission = '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />'
if permission not in text:
    text = text.replace("<application", permission + "\\n    <application", 1)
receivers = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
"""
if "ScheduledNotificationReceiver" not in text:
    text = text.replace("</application>", receivers + "\\n    </application>")
manifest.write_text(text)

gradle = Path("android/app/build.gradle.kts")
g = gradle.read_text()
if "isCoreLibraryDesugaringEnabled" not in g:
    g = re.sub(r"compileOptions\\s*\\{", "compileOptions {\\n        isCoreLibraryDesugaringEnabled = true", g, count=1)
if "coreLibraryDesugaring(" not in g:
    g = g.replace("dependencies {", 'dependencies {\\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")', 1)
gradle.write_text(g)
