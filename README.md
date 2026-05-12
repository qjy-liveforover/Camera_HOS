<div align="center">

# 📹 Camera2 Video Recorder for HarmonyOS

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-API%2012%2B-blue.svg)](https://www.harmonyos.com/)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![Language](https://img.shields.io/badge/Language-ArkTS-orange.svg)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-getting-started-V5)

**A professional video recording application built with HarmonyOS Camera2 API**

Featuring Picture-in-Picture (PiP) mode, real-time video parameter display, and seamless gallery integration.

</div>

---

## 📖 Table of Contents

- [Purpose](#-purpose)
- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Installation & Configuration](#-installation--configuration)
- [Usage Guide](#-usage-guide)
- [Permissions](#-permissions)
- [Project Structure](#-project-structure)
- [Technical Details](#-technical-details)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [Support](#-support)

---

## 🎯 Purpose

This application is designed for **reflectance analysis of adulterated spice powders** using the front camera of Huawei Mate 70 Pro+. It captures videos of spice powder samples under different monochromatic light illuminations with varying adulteration ratios (0% to 100%). The recorded video frames are extracted for quantitative analysis of adulteration levels.

To maximize the characterization of reflectance differences across different adulteration ratios, the app implements **optimized camera parameter locking** for consistent frame-to-frame measurement:

- **Exposure control**: Manual exposure locking (AE LOCKED) with fixed ISO, exposure time, and exposure bias
- **White balance locking**: Fixed white balance mode (DAYLIGHT or MANUAL) to eliminate color temperature variations
- **Focus locking**: Manual focus locking to maintain consistent focal distance
- **HDR/Vivid disabled**: SDR with BT.709 color space ensures linear pixel‑value response
- **Stabilization disabled**: Optical stabilization turned off to prevent frame‑to‑frame intensity shifts

These settings guarantee that the recorded video frames provide a stable, reproducible signal for reflectance‑based adulteration detection.

---

## ✨ Features

<table>
<tr>
<td width="50%">

### 🎥 Camera2 API Integration
Professional-grade video recording using HarmonyOS Camera2 interfaces with full control over camera parameters.

</td>
<td width="50%">

### 🖼️ Picture-in-Picture (PiP) Mode
Continue recording while using other apps. PiP window keeps camera service alive.

</td>
</tr>
<tr>
<td width="50%">

### 📊 Real-time Parameter Display
View resolution, frame rate, bitrate, codec info during recording.

</td>
<td width="50%">

### 🖼️ Gallery Integration
Save recorded videos directly to photo gallery with system SaveButton.

</td>
</tr>
<tr>
<td width="50%">

### 🎞️ Front Camera Support
Optimized preview with mirror effect for front camera.

</td>
<td width="50%">

### ⏱️ Recording Timer
Real-time recording duration display.

</td>
</tr>
<tr>
<td width="50%">

### 🔬 Reflectance Analysis Mode
Locked camera parameters (exposure, ISO, white balance, focus) for consistent frame‑to‑frame measurement of spice powder reflectance.

</td>
<td width="50%">

### 📈 Data Collection Ready
Optimized for extracting video frames as datasets for adulteration ratio analysis.

</td>
</tr>
</table>

### 🔥 Key Innovation: Background Recording Solution

> **Problem**: Running the native camera in background would normally cause the system to automatically kill the recording thread.
>
> **Solution**: This app uses **Picture-in-Picture (PiP) mode** with a hidden sidebar position to effectively achieve background recording with the front camera. The PiP window keeps the camera service alive while being minimally intrusive, allowing continuous recording even when using other applications.

---

## 🔧 Prerequisites

### Development Environment

| Requirement | Version |
|-------------|---------|
| DevEco Studio | 4.0 or later |
| HarmonyOS SDK | API 12 or later |
| Node.js | 14.x or later |

### Device Requirements

- ✅ HarmonyOS device or emulator running API 12+
- ✅ Camera hardware support
- ✅ Storage permission for video saving

---

## 🚀 Installation & Configuration

### Step 1: Clone the Repository

```bash
git clone https://github.com/qjy-liveforover/Camera_HOS.git
cd Camera_HOS
```

### Step 2: Open in DevEco Studio

1. Launch **DevEco Studio**
2. Select **File > Open**
3. Navigate to the cloned project directory and click **OK**
4. Wait for project synchronization to complete

### Step 3: Configure Signing (Required for Real Devices)

1. In DevEco Studio, go to **File > Project Structure > Signing Configs**
2. Enable **Automatically generate signature** for development
3. Or configure your own signing certificate:

| Field | Description |
|-------|-------------|
| Store File | Your .p12 certificate file |
| Store Password | Your keystore password |
| Key Alias | Your key alias |
| Key Password | Your key password |
| Sign Alg | SHA256withECDSA (recommended) |
| Profile File | Your .p7b provisioning profile |
| Certpath File | Your .cer certificate file |

### Step 4: Configure Device/Emulator

#### 📱 Option A: Use Emulator

1. Go to **Tools > Device Manager**
2. Click **New Emulator**
3. Select a device template (Phone recommended)
4. Select HarmonyOS system image (API 12+)
5. Complete setup and start the emulator

#### 📲 Option B: Use Real Device

1. **Enable Developer Mode**:
   - Go to **Settings > About phone**
   - Tap **Build number** 7 times

2. **Enable USB debugging**:
   - Go to **Settings > Developer options**
   - Enable **USB debugging**

3. Connect device via USB
4. Accept debugging authorization on device

### Step 5: Build and Run

1. Select your device/emulator from the dropdown menu
2. Click **Run** (green play button) or press `Shift+F10`
3. Wait for build and installation to complete
4. Grant camera and storage permissions when prompted

---

## 📖 Usage Guide

### Basic Recording

| Step | Action |
|------|--------|
| 1️⃣ | **Start Recording**: Tap the red record button |
| 2️⃣ | **View Parameters**: Real-time display shows resolution, frame rate, bitrate, codec, HDR status |
| 3️⃣ | **Stop Recording**: Tap the stop button (red square) |
| 4️⃣ | **Save Video**: Enter video name and tap Save button |

### Picture-in-Picture Mode

- 🔄 PiP mode activates automatically when recording starts
- 👆 Tap the PiP window to expand back to full screen
- 📱 Continue using other apps while recording

---

## 🔐 Permissions

The application requires the following permissions (configured in `module.json5`):

| Permission | Purpose |
|------------|---------|
| `ohos.permission.CAMERA` | Camera access for video recording |
| `ohos.permission.MICROPHONE` | Audio recording |
| `ohos.permission.WRITE_IMAGEVIDEO` | Save videos to gallery |

> **Note**: The SaveButton system component automatically handles WRITE_IMAGEVIDEO permission, providing a secure and user-friendly permission flow.

---

## 📁 Project Structure

```
Camera_HOS/
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
├── 📄 build-profile.json5             # App-level build config
├── 📄 hvigorfile.ts                   # Build script
├── 📄 oh-package.json5                # Dependencies
└── 📄 README.md                       # This file
```

---

## 🔬 Technical Details

### Camera2 API Usage

| API | Purpose |
|-----|---------|
| `camera.createCameraInput()` | Camera input creation |
| `camera.createVideoOutput()` | Video capture output |
| `camera.createPreviewOutput()` | Preview display |
| `avRecorder` | Video encoding |

### State Management

- `@State` decorators for reactive UI updates
- `XComponent` for camera preview surface
- Proper lifecycle management in `aboutToAppear`/`aboutToDisappear`

### Video Parameters

| Parameter | Value |
|-----------|-------|
| Resolution | Automatically selected based on camera capabilities |
| Frame Rate | 30fps default |
| Video Codec | H.264/H.265 (device dependent) |
| Audio Codec | AAC |
| Bitrate | Dynamically adjusted |

---

## 🛠️ Development

### Build Commands

```bash
# Debug build
hvigorw assembleHap --mode module -p product=default

# Release build
hvigorw assembleHap --mode module -p product=default -p buildMode=release

# Clean build
hvigorw clean
hvigorw assembleHap --mode module -p product=default
```

---

## ❓ Troubleshooting

### Build Errors

<details>
<summary><b>SDK not found</b></summary>

1. Go to **File > Settings > HarmonyOS SDK**
2. Download API 12+ SDK

</details>

<details>
<summary><b>Signing configuration missing</b></summary>

Configure signing as described in [Step 3](#step-3-configure-signing-required-for-real-devices)

</details>

### Runtime Issues

<details>
<summary><b>Camera preview black screen</b></summary>

- Ensure camera permission is granted
- Restart the app after granting permission

</details>

<details>
<summary><b>Video not saved to gallery</b></summary>

- Check storage permission
- Ensure sufficient storage space
- Use the system SaveButton for reliable permission handling

</details>

<details>
<summary><b>PiP mode not working</b></summary>

- PiP requires API 12+
- Some devices may not support PiP

</details>

---

## 🤝 Contributing

1. 🍴 Fork the repository
2. 🌿 Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. 💾 Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. 📤 Push to the branch (`git push origin feature/AmazingFeature`)
5. 🔀 Open a Pull Request

---

## 📄 License

This project is licensed under the **Apache License 2.0** - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- HarmonyOS Camera2 API documentation
- DevEco Studio development tools
- HarmonyOS developer community

---

## 💬 Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/qjy-liveforover/Camera_HOS/issues) page.

---

<div align="center">

**Made with ❤️ for HarmonyOS**

⭐ If this project helps you, please consider giving it a star! ⭐

</div>
