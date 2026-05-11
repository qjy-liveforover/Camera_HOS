<div align="center">

# 📹 Camera2 Video Recorder for HarmonyOS

<img src="https://img.shields.io/badge/HarmonyOS-API%2012%2B-blue?style=for-the-badge&logo=huawei" alt="HarmonyOS"/>
<img src="https://img.shields.io/badge/License-Apache%202.0-green?style=for-the-badge" alt="License"/>
<img src="https://img.shields.io/badge/Language-ArkTS-orange?style=for-the-badge" alt="ArkTS"/>
<img src="https://img.shields.io/badge/Platform-HarmonyOS-purple?style=for-the-badge" alt="Platform"/>

<br/>
<br/>

**🎬 A professional video recording application built with HarmonyOS Camera2 API**

*Featuring Picture-in-Picture (PiP) mode, real-time video parameter display, and seamless gallery integration*

<br/>

[🚀 Quick Start](#-installation--configuration) · [📖 Documentation](#-usage-guide) · [🤝 Contributing](#-contributing) · [💬 Support](#-support)

</div>

---

## 📖 Table of Contents

- [✨ Features](#-features)
- [🔧 Prerequisites](#-prerequisites)
- [🚀 Installation & Configuration](#-installation--configuration)
- [📖 Usage Guide](#-usage-guide)
- [🔐 Permissions](#-permissions)
- [📁 Project Structure](#-project-structure)
- [🔬 Technical Details](#-technical-details)
- [🛠️ Development](#️-development)
- [❓ Troubleshooting](#-troubleshooting)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)
- [💬 Support](#-support)

---

## ✨ Features

<div align="center">

| 🎥 **Camera2 API Integration** | 🖼️ **Picture-in-Picture Mode** |
|:---:|:---:|
| Professional-grade video recording with full control over camera parameters | Continue recording while using other apps with minimally intrusive PiP window |

| 📊 **Real-time Parameter Display** | 🖼️ **Gallery Integration** |
|:---:|:---:|
| View resolution, frame rate, bitrate, codec info during recording | Save recorded videos directly to photo gallery with system SaveButton |

| 🎞️ **Front Camera Support** | ⏱️ **Recording Timer** |
|:---:|:---:|
| Optimized preview with mirror effect for front camera | Real-time recording duration display |

</div>

### 🔥 Key Innovation: Background Recording Solution

<table>
<tr>
<td width="50%">

**❌ Problem**

Running the native camera in background would normally cause the system to automatically kill the recording thread.

</td>
<td width="50%">

**✅ Solution**

This app uses **Picture-in-Picture (PiP) mode** with a hidden sidebar position to effectively achieve background recording with the front camera. The PiP window keeps the camera service alive while being minimally intrusive, allowing continuous recording even when using other applications.

</td>
</tr>
</table>

---

## 🔧 Prerequisites

### 💻 Development Environment

| Requirement | Version | Status |
|-------------|---------|--------|
| DevEco Studio | 4.0 or later | ✅ Required |
| HarmonyOS SDK | API 12 or later | ✅ Required |
| Node.js | 14.x or later | ✅ Required |

### 📱 Device Requirements

- ✅ HarmonyOS device or emulator running API 12+
- ✅ Camera hardware support
- ✅ Storage permission for video saving

---

## 🚀 Installation & Configuration

### 📥 Step 1: Clone the Repository

```bash
# Clone the repository
git clone https://github.com/qjy-liveforover/ColorCycling_HOS.git

# Navigate to project directory
cd ColorCycling_HOS
```

### 🖥️ Step 2: Open in DevEco Studio

| Step | Action |
|:----:|--------|
| 1️⃣ | Launch **DevEco Studio** |
| 2️⃣ | Select **File > Open** |
| 3️⃣ | Navigate to the cloned project directory and click **OK** |
| 4️⃣ | Wait for project synchronization to complete |

### 🔐 Step 3: Configure Signing (Required for Real Devices)

<details>
<summary><b>🔑 Automatic Signing (Recommended for Development)</b></summary>

1. In DevEco Studio, go to **File > Project Structure > Signing Configs**
2. Enable **Automatically generate signature**
3. Click **OK** to save

</details>

<details>
<summary><b>🔏 Manual Signing Configuration</b></summary>

| Field | Description | Format |
|-------|-------------|--------|
| Store File | Your keystore file | `.p12` |
| Store Password | Your keystore password | - |
| Key Alias | Your key alias | - |
| Key Password | Your key password | - |
| Sign Alg | Signing algorithm | `SHA256withECDSA` (recommended) |
| Profile File | Provisioning profile | `.p7b` |
| Certpath File | Certificate file | `.cer` |

</details>

### 📱 Step 4: Configure Device/Emulator

<table>
<tr>
<td width="50%">

#### 🖥️ Option A: Use Emulator

1. Go to **Tools > Device Manager**
2. Click **New Emulator**
3. Select a device template (Phone recommended)
4. Select HarmonyOS system image (API 12+)
5. Complete setup and start the emulator

</td>
<td width="50%">

#### 📲 Option B: Use Real Device

1. **Enable Developer Mode**:
   - Go to **Settings > About phone**
   - Tap **Build number** 7 times

2. **Enable USB debugging**:
   - Go to **Settings > Developer options**
   - Enable **USB debugging**

3. Connect device via USB
4. Accept debugging authorization on device

</td>
</tr>
</table>

### ▶️ Step 5: Build and Run

| Step | Action | Shortcut |
|:----:|--------|----------|
| 1️⃣ | Select your device/emulator from the dropdown menu | - |
| 2️⃣ | Click **Run** (green play button) | `Shift+F10` |
| 3️⃣ | Wait for build and installation to complete | - |
| 4️⃣ | Grant camera and storage permissions when prompted | - |

---

## 📖 Usage Guide

### 🎬 Basic Recording

<div align="center">

| Step | Action | Icon |
|:----:|--------|:----:|
| 1️⃣ | **Start Recording**: Tap the red record button | 🔴 |
| 2️⃣ | **View Parameters**: Real-time display shows resolution, frame rate, bitrate, codec, HDR status | 📊 |
| 3️⃣ | **Stop Recording**: Tap the stop button (red square) | ⏹️ |
| 4️⃣ | **Save Video**: Enter video name and tap Save button | 💾 |

</div>

### 🖼️ Picture-in-Picture Mode

| Feature | Description |
|---------|-------------|
| 🔄 **Auto Activation** | PiP mode activates automatically when recording starts |
| 👆 **Interactive** | Tap the PiP window to expand back to full screen |
| 📱 **Multitasking** | Continue using other apps while recording |
| 🎯 **Minimal Intrusion** | Hidden sidebar position for unobtrusive recording |

---

## 🔐 Permissions

The application requires the following permissions (configured in `module.json5`):

| Permission | Purpose | Type |
|------------|---------|------|
| `ohos.permission.CAMERA` | Camera access for video recording | 🔒 System |
| `ohos.permission.MICROPHONE` | Audio recording | 🔒 System |
| `ohos.permission.WRITE_IMAGEVIDEO` | Save videos to gallery | 🔒 System |

> **💡 Note**: The `SaveButton` system component automatically handles `WRITE_IMAGEVIDEO` permission, providing a secure and user-friendly permission flow.

---

## 📁 Project Structure

```
ColorCycling_HOS/
│
├── 📂 entry/                          # Main entry module
│   ├── 📂 src/main/
│   │   ├── 📂 ets/                    # ArkTS source code
│   │   │   ├── 📂 entryability/       # Application entry point
│   │   │   │   └── 📄 EntryAbility.ets
│   │   │   ├── 📂 pages/              # UI pages
│   │   │   │   └── 📄 Index.ets       # Main recording page
│   │   │   ├── 📂 camera/             # Camera logic
│   │   │   │   ├── 📄 CameraVideoRecorder.ets
│   │   │   │   └── 📄 RecordingParams.ets
│   │   │   └── 📂 pip/                # Picture-in-Picture
│   │   │       └── 📄 PiPController.ets
│   │   ├── 📂 resources/              # Resources
│   │   │   └── 📂 base/
│   │   │       ├── 📂 element/        # Colors, strings
│   │   │       └── 📂 media/          # Icons, images
│   │   └── 📄 module.json5            # Module configuration
│   └── 📄 build-profile.json5         # Build configuration
│
├── 📄 build-profile.json5             # App-level build config
├── 📄 hvigorfile.ts                   # Build script
├── 📄 oh-package.json5                # Dependencies
└── 📄 README.md                       # This file
```

---

## 🔬 Technical Details

### 🎥 Camera2 API Usage

| API | Purpose | Description |
|-----|---------|-------------|
| `camera.createCameraInput()` | Camera input creation | Initialize camera device |
| `camera.createVideoOutput()` | Video capture output | Configure video stream |
| `camera.createPreviewOutput()` | Preview display | Setup preview surface |
| `avRecorder` | Video encoding | Handle video encoding |

### 🔄 State Management

| Decorator | Purpose |
|-----------|---------|
| `@State` | Reactive UI updates |
| `XComponent` | Camera preview surface |
| Lifecycle | Proper management in `aboutToAppear`/`aboutToDisappear` |

### 📊 Video Parameters

| Parameter | Value | Note |
|-----------|-------|------|
| Resolution | Auto-selected | Based on camera capabilities |
| Frame Rate | 30fps | Default value |
| Video Codec | H.264/H.265 | Device dependent |
| Audio Codec | AAC | Standard audio codec |
| Bitrate | Dynamic | Dynamically adjusted |

---

## 🛠️ Development

### 🔨 Build Commands

```bash
# 🔧 Debug build
hvigorw assembleHap --mode module -p product=default

# 🚀 Release build
hvigorw assembleHap --mode module -p product=default -p buildMode=release

# 🧹 Clean build
hvigorw clean
hvigorw assembleHap --mode module -p product=default
```

### 📦 Project Dependencies

All dependencies are managed through `oh-package.json5` and automatically resolved by DevEco Studio.

---

## ❓ Troubleshooting

### 🔨 Build Errors

<details>
<summary><b>❌ SDK not found</b></summary>

**Solution:**
1. Go to **File > Settings > HarmonyOS SDK**
2. Download API 12+ SDK
3. Click **Apply** and restart DevEco Studio

</details>

<details>
<summary><b>❌ Signing configuration missing</b></summary>

**Solution:**
Configure signing as described in [Step 3: Configure Signing](#-step-3-configure-signing-required-for-real-devices)

</details>

<details>
<summary><b>❌ Module synchronization failed</b></summary>

**Solution:**
1. Clean project: **Build > Clean Project**
2. Rebuild: **Build > Rebuild Project**
3. If still failing, invalidate caches: **File > Invalidate Caches / Restart**

</details>

### 📱 Runtime Issues

<details>
<summary><b>⬛ Camera preview black screen</b></summary>

**Possible causes and solutions:**
- ✅ Ensure camera permission is granted
- ✅ Restart the app after granting permission
- ✅ Check if camera is being used by another app
- ✅ Verify device camera hardware is functional

</details>

<details>
<summary><b>💾 Video not saved to gallery</b></summary>

**Possible causes and solutions:**
- ✅ Check storage permission
- ✅ Ensure sufficient storage space
- ✅ Use the system SaveButton for reliable permission handling
- ✅ Verify video recording completed successfully

</details>

<details>
<summary><b>🖼️ PiP mode not working</b></summary>

**Possible causes and solutions:**
- ✅ PiP requires API 12+
- ✅ Some devices may not support PiP
- ✅ Check device PiP settings
- ✅ Ensure app has necessary permissions

</details>

<details>
<summary><b>🎤 Audio not recorded</b></summary>

**Possible causes and solutions:**
- ✅ Check microphone permission
- ✅ Verify microphone is not being used by another app
- ✅ Test device microphone hardware

</details>

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

<div align="center">

| Step | Action | Command |
|:----:|--------|---------|
| 1️⃣ | Fork the repository | - |
| 2️⃣ | Create feature branch | `git checkout -b feature/AmazingFeature` |
| 3️⃣ | Commit changes | `git commit -m 'Add some AmazingFeature'` |
| 4️⃣ | Push to branch | `git push origin feature/AmazingFeature` |
| 5️⃣ | Open Pull Request | - |

</div>

### 📋 Coding Standards

- ✅ Follow ArkTS coding conventions
- ✅ Add appropriate comments for complex logic
- ✅ Update documentation for new features
- ✅ Test on both emulator and real device

---

## 📄 License

This project is licensed under the **Apache License 2.0** - see the [LICENSE](LICENSE) file for details.

<div align="center">

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=for-the-badge)](LICENSE)

</div>

---

## 🙏 Acknowledgments

<div align="center">

| 🎯 Resource | 📝 Description |
|-------------|----------------|
| [HarmonyOS Documentation](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/) | Official HarmonyOS development guides |
| [Camera2 API Reference](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/) | Camera2 API documentation |
| [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) | Official IDE for HarmonyOS development |
| [HarmonyOS Community](https://developer.huawei.com/consumer/cn/forum/) | Developer community support |

</div>

---

## 💬 Support

<div align="center">

**Having issues? We're here to help!**

[![GitHub Issues](https://img.shields.io/badge/GitHub-Issues-blue?style=for-the-badge&logo=github)](https://github.com/qjy-liveforover/ColorCycling_HOS/issues)
[![GitHub Discussions](https://img.shields.io/badge/GitHub-Discussions-purple?style=for-the-badge&logo=github)](https://github.com/qjy-liveforover/ColorCycling_HOS/discussions)

</div>

---

<div align="center">

**Made with ❤️ for HarmonyOS**

<br/>

**⭐ If this project helps you, please consider giving it a star! ⭐**

<br/>

<img src="https://img.shields.io/github/stars/qjy-liveforover/ColorCycling_HOS?style=social" alt="Stars"/>
<img src="https://img.shields.io/github/forks/qjy-liveforover/ColorCycling_HOS?style=social" alt="Forks"/>
<img src="https://img.shields.io/github/watchers/qjy-liveforover/ColorCycling_HOS?style=social" alt="Watchers"/>

<br/>
<br/>

**Copyright © 2024 - Present**

</div>