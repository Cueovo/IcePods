# IcePods

QQ Music iPod-style Flutter player.

## GitHub Actions 构建 IPA

仓库内的 `.github/workflows/build-ios-ipa.yml` 会在以下情况运行：

- 在 GitHub Actions 页面手动触发 `Build iOS IPA`
- 推送形如 `v1.0.0` 的 Git tag

工作流会在 macOS runner 上执行 `flutter analyze`、`flutter test` 和 `flutter build ios --release --no-codesign`，然后把 `IcePods-unsigned.ipa` 上传为 Actions artifact。

### 手动构建

1. 打开 GitHub 仓库 `https://github.com/Cueovo/IcePods`。
2. 进入 `Actions`。
3. 选择 `Build iOS IPA`。
4. 点击 `Run workflow`，选择分支后确认运行。
5. 等待任务完成，在 workflow summary 的 `Artifacts` 区域下载 `IcePods-iOS-<run number>`。
6. 解压后得到 `IcePods-unsigned.ipa`。

### 触发版本构建

```bash
git tag v1.0.0
git push origin v1.0.0
```

### 关于签名

当前工作流生成的是**未签名 IPA**，不需要 Apple 证书或 App Store Connect 密钥，适合先构建和下载验证。

要安装到真实 iPhone，需要使用 AltStore、SideStore、Sideloadly 等工具重新签名，或在 GitHub Actions 中配置 Apple Developer 签名文件和 secrets。未签名 IPA 不能直接通过普通 iPhone 安装，也不能直接提交 App Store。

如果要做签名构建，需要准备并安全配置：

- Apple Developer Team ID
- Distribution certificate（`.p12`）及密码
- Provisioning profile（`.mobileprovision`）
- App Store Connect API key（如果采用自动签名或 TestFlight 上传）

这些证书、私钥和密码不要提交到仓库。

## 本地开发

```bash
flutter pub get
flutter analyze
flutter test
```

## 自己安装（Android Release）

适合日常在自己手机上覆盖安装。

### 1. 准备

- 已安装 [Flutter SDK](https://docs.flutter.dev/get-started/install)
- 手机打开 **开发者选项 → USB 调试**
- USB 连接电脑，允许调试

检查设备：

```bash
flutter devices
# 或
adb devices
```

设备状态需为 `device`（不是 `offline` / `unauthorized`）。

### 2. 编译 Release APK

在项目根目录：

```bash
flutter pub get
flutter build apk --release
```

产物路径：

```text
build/app/outputs/flutter-apk/app-release.apk
```

### 3. 覆盖安装到手机

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

多设备时指定序列号：

```bash
adb devices
adb -s <设备序列号> install -r build/app/outputs/flutter-apk/app-release.apk
```

### 4. 一条龙（本机常用）

```bash
flutter build apk --release && adb install -r build/app/outputs/flutter-apk/app-release.apk
E:\FlutterSDK\flutter\bin\flutter.bat build apk --release | adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### 常见问题

| 现象 | 处理 |
| --- | --- |
| `device offline` | `adb kill-server` 后 `adb start-server`，重插 USB |
| `unauthorized` | 手机弹出授权框，点允许 |
| 安装失败 / 签名冲突 | 先卸旧包再装：`adb uninstall com.qqmusic.ipod.qqmusic_ipod`（包名以 `android/app/src/main/AndroidManifest.xml` 为准） |
| 找不到设备 | 换线/口，确认 USB 调试已开 |

### 包信息（参考）

- 应用名：Ambient Player / IcePods
- APK：`build/app/outputs/flutter-apk/app-release.apk`
- 约 50MB 量级（随依赖变化）

## iOS 无签名 Release

```bash
flutter build ios --release --no-codesign
```

真机安装仍需签名（AltStore / SideStore / 开发者证书等），见上文 GitHub Actions 说明。
