#!/usr/bin/env python3
from pathlib import Path
import os
import plistlib
import re

ROOT = Path(__file__).resolve().parents[1]
BUNDLE_ID = os.environ.get('FOLIO_BUNDLE_ID', 'com.folio.wallet').strip() or 'com.folio.wallet'
DISPLAY_NAME = 'Folio'


def patch_android() -> None:
    app = ROOT / 'android' / 'app'
    if not app.exists():
        return

    kts = app / 'build.gradle.kts'
    groovy = app / 'build.gradle'
    gradle = kts if kts.exists() else groovy
    if gradle.exists():
        text = gradle.read_text()
        text = re.sub(r'namespace\s*=\s*["\'][^"\']+["\']', f'namespace = "{BUNDLE_ID}"', text)
        text = re.sub(r'applicationId\s*=\s*["\'][^"\']+["\']', f'applicationId = "{BUNDLE_ID}"', text)
        text = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24', text)
        text = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24', text)
        gradle.write_text(text)

    for manifest_path in [
        app / 'src' / 'main' / 'AndroidManifest.xml',
        app / 'src' / 'debug' / 'AndroidManifest.xml',
        app / 'src' / 'profile' / 'AndroidManifest.xml',
    ]:
        if manifest_path.exists():
            text = manifest_path.read_text()
            text = re.sub(r'android:label="[^"]*"', f'android:label="{DISPLAY_NAME}"', text)
            if manifest_path.name == 'AndroidManifest.xml' and manifest_path.parent.name == 'main':
                permissions = []
                if 'android.permission.CAMERA' not in text:
                    permissions.append('    <uses-permission android:name="android.permission.CAMERA" />')
                if 'android.permission.USE_BIOMETRIC' not in text:
                    permissions.append('    <uses-permission android:name="android.permission.USE_BIOMETRIC" />')
                if permissions:
                    text = text.replace(
                        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
                        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n' + '\n'.join(permissions),
                        1,
                    )
            manifest_path.write_text(text)

    main_activities = list((app / 'src' / 'main').rglob('MainActivity.kt'))
    for activity in main_activities:
        text = activity.read_text()
        text = re.sub(r'^package\s+[^\n]+', f'package {BUNDLE_ID}', text, flags=re.MULTILINE)
        text = text.replace('FlutterActivity', 'FlutterFragmentActivity')
        target = app / 'src' / 'main' / 'kotlin' / Path(*BUNDLE_ID.split('.')) / 'MainActivity.kt'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
        if activity.resolve() != target.resolve():
            activity.unlink()


def patch_android_auth_theme() -> None:
    values_root = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
    if not values_root.exists():
        return
    for style_file in values_root.rglob('styles.xml'):
        text = style_file.read_text()
        text = re.sub(
            r'(<style\s+name="LaunchTheme"\s+parent=")[^"]+("[^>]*>)',
            r'\1Theme.AppCompat.DayNight.NoActionBar\2',
            text,
        )
        style_file.write_text(text)


def patch_ios() -> None:
    runner = ROOT / 'ios' / 'Runner'
    info = runner / 'Info.plist'
    if info.exists():
        with info.open('rb') as handle:
            data = plistlib.load(handle)
        data['CFBundleDisplayName'] = DISPLAY_NAME
        data['NSCameraUsageDescription'] = 'Fiş fotoğrafı çekerek harcamalarını otomatik ekleyebilmen için kameraya erişim gerekir.'
        data['NSMicrophoneUsageDescription'] = 'Kamera bileşeninin iOS medya izin yapılandırması için bu açıklama gereklidir; Folio fiş tararken ses kaydetmez.'
        data['NSPhotoLibraryUsageDescription'] = 'Galerindeki fiş fotoğraflarını seçebilmen için fotoğraf arşivine erişim gerekir.'
        data['NSFaceIDUsageDescription'] = 'Finansal görünümünü Face ID ile koruyabilmen için Face ID erişimi gerekir.'
        with info.open('wb') as handle:
            plistlib.dump(data, handle, sort_keys=False)

    pbx = ROOT / 'ios' / 'Runner.xcodeproj' / 'project.pbxproj'
    if pbx.exists():
        text = pbx.read_text()
        def bundle_repl(match: re.Match[str]) -> str:
            original = match.group(1)
            suffix = '.RunnerTests' if 'RunnerTests' in original else ''
            return f'PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}{suffix};'
        text = re.sub(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);', bundle_repl, text)
        text = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.5;', text)
        pbx.write_text(text)

    podfile = ROOT / 'ios' / 'Podfile'
    if podfile.exists():
        text = podfile.read_text()
        platform_pattern = r"^\s*#?\s*platform :ios, '[^']+'\s*$"
        if re.search(platform_pattern, text, flags=re.MULTILINE):
            text = re.sub(platform_pattern, "platform :ios, '15.5'", text, count=1, flags=re.MULTILINE)
        else:
            text = "platform :ios, '15.5'\n" + text

        # google_mlkit_text_recognition requires all Pods to target iOS 15.5+
        # and armv7 to be excluded. Patch the generated Flutter Podfile once.
        #
        # Load the Apple Silicon simulator helper inside post_install: Flutter
        # only creates ios/.symlinks during flutter_install_all_ios_pods, so a
        # top-level require of that path fails on a clean machine.
        text = text.replace(
            "require File.expand_path(\n"
            "  '.symlinks/plugins/google_mlkit_commons/ios/scripts/apple_silicon_simulator',\n"
            "  __dir__,\n"
            ")\n",
            "",
            1,
        )
        if '# FOLIO_MLKIT_PATCH' not in text:
            text = text.replace(
                "post_install do |installer|",
                "$iOSVersion = '15.5'\n# FOLIO_MLKIT_PATCH\npost_install do |installer|\n"
                "  installer.pods_project.build_configurations.each do |config|\n"
                "    config.build_settings[\"EXCLUDED_ARCHS[sdk=*]\"] = \"armv7\"\n"
                "    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = $iOSVersion\n"
                "  end",
                1,
            )
            text = text.replace(
                "    flutter_additional_ios_build_settings(target)",
                "    flutter_additional_ios_build_settings(target)\n"
                "    target.build_configurations.each do |config|\n"
                "      current = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']\n"
                "      if current.nil? || Gem::Version.new($iOSVersion) > Gem::Version.new(current)\n"
                "        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = $iOSVersion\n"
                "      end\n"
                "    end",
                1,
            )
            if 'mlkit_apple_silicon_simulator_patch' not in text:
                text = text.replace(
                    "  end\nend\n",
                    "  end\n"
                    "  require File.expand_path(\n"
                    "    '.symlinks/plugins/google_mlkit_commons/ios/scripts/apple_silicon_simulator',\n"
                    "    __dir__,\n"
                    "  )\n"
                    "  mlkit_apple_silicon_simulator_patch(installer)\nend\n",
                    1,
                )
        podfile.write_text(text)


if __name__ == '__main__':
    patch_android()
    patch_android_auth_theme()
    patch_ios()
    print('Platform ayarları güncellendi.')
