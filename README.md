# Camera2 Video Recorder for HarmonyOS

A professional video recording application built with HarmonyOS Camera2 API, featuring Picture-in-Picture (PiP) mode, real-time video parameter display, and seamless gallery integration.

## Features

- **Camera2 API Integration**: Professional-grade video recording using HarmonyOS Camera2 interfaces
- **Picture-in-Picture (PiP) Mode**: Continue recording while using other apps
- **Real-time Parameter Display**: View resolution, frame rate, bitrate, codec info during recording
- **Gallery Integration**: Save recorded videos directly to photo gallery with system SaveButton
- **Front Camera Support**: Optimized preview with mirror effect for front camera
- **Recording Timer**: Real-time recording duration display

## Prerequisites

### Development Environment
- **DevEco Studio**: Version 4.0 or later
- **HarmonyOS SDK**: API 12 or later
- **Node.js**: Version 14.x or later (for hvigor build system)

### Device Requirements
- HarmonyOS device or emulator running API 12+
- Camera hardware support
- Storage permission for video saving

## Installation & Configuration

### Step 1: Clone the Repository

```bash
git clone https://github.com/qjy-liveforover/Camera_HOS.git
cd Camera_HOS
```

### Step 2: Open in DevEco Studio

1. Launch DevEco Studio
2. Select **File > Open**
3. Navigate to the cloned project directory and click **OK**
4. Wait for project synchronization to complete

### Step 3: Configure Signing (Required for Real Devices)

1. In DevEco Studio, go to **File > Project Structure > Signing Configs**
2. Enable **Automatically generate signature** for development
3. Or configure your own signing certificate:
   - **Store File**: Select your .p12 certificate file
   - **Store Password**: Enter your keystore password
   - **Key Alias**: Enter your key alias
   - **Key Password**: Enter your key password
   - **Sign Alg**: Select SHA256withECDSA (recommended)
   - **Profile File**: Select your .p7b provisioning profile
   - **Certpath File**: Select your .cer certificate file

### Step 4: Configure Device/Emulator

#### Option A: Use Emulator
1. In DevEco Studio, go to **Tools > Device Manager**
2. Click **New Emulator**
3. Select a device template (Phone recommended)
4. Select HarmonyOS system image (API 12+)
5. Complete setup and start the emulator

#### Option B: Use Real Device
1. Enable **Developer Mode** on your HarmonyOS device:
   - Go to **Settings > About phone**
   - Tap **Build number** 7 times
2. Enable **USB debugging**:
   - Go to **Settings > Developer options**
   - Enable **USB debugging**
3. Connect device via USB
4. Accept debugging authorization on device

### Step 5: Build and Run

1. Select your device/emulator from the dropdown menu
2. Click **Run** (green play button) or press **Shift+F10**
3. Wait for build and installation to complete
4. Grant camera and storage permissions when prompted

## Project Structure

```
Camera_HOS/
├── entry/                          # Main entry module
│   ├── src/main/
│   │   ├── ets/                    # ArkTS source code
│   │   │   ├── entryability/       # Application entry point
│   │   │   │   └── EntryAbility.ets
│   │   │   ├── pages/              # UI pages
│   │   │   │   └── Index.ets       # Main recording page
│   │   │   ├── camera/             # Camera logic
│   │   │   │   ├── CameraManager.ets
│   │   │   │   ├── CameraVideoRecorder.ets
│   │   │   │   └── RecordingParams.ets
│   │   │   └── pip/                # Picture-in-Picture
│   │   │       └── PiPController.ets
│   │   ├── resources/              # Resources
│   │   │   └── base/
│   │   │       ├── element/        # Colors, strings
│   │   │       └── media/          # Icons, images
│   │   └── module.json5            # Module configuration
│   └── build-profile.json5         # Build configuration
├── build-profile.json5             # App-level build config
├── hvigorfile.ts                   # Build script
├── oh-package.json5                # Dependencies
└── README.md                       # This file
```

## Usage Guide

### Basic Recording

1. **Start Recording**: Tap the red record button
2. **View Parameters**: Real-time display shows:
   - Resolution (4K/2K/FHD/HD)
   - Frame rate (fps)
   - Video/Audio bitrate
   - Codec information
   - HDR status
3. **Stop Recording**: Tap the stop button (red square)
4. **Save Video**: 
   - Enter video name in dialog
   - Tap **Save** button (system SaveButton handles permissions)
   - Or tap **Cancel** to discard

### Picture-in-Picture Mode

- PiP mode activates automatically when recording starts
- Tap the PiP window to expand back to full screen
- Continue using other apps while recording

## Permissions

The application requires the following permissions (configured in `module.json5`):

| Permission | Purpose |
|------------|---------|
| `ohos.permission.CAMERA` | Camera access for video recording |
| `ohos.permission.MICROPHONE` | Audio recording |
| `ohos.permission.WRITE_IMAGEVIDEO` | Save videos to gallery (handled by SaveButton) |

**Note**: The SaveButton system component automatically handles WRITE_IMAGEVIDEO permission, providing a secure and user-friendly permission flow.

## Configuration Files

### module.json5
Contains module metadata, abilities, and permission declarations.

### build-profile.json5
Configures build settings including:
- API version targets
- Build variants
- Signing configurations

### oh-package.json5
Manages project dependencies and OHPM packages.

## Troubleshooting

### Build Errors

**Problem**: "SDK not found"
**Solution**: 
1. Go to **File > Settings > HarmonyOS SDK**
2. Download API 12+ SDK

**Problem**: "Signing configuration missing"
**Solution**: Configure signing as described in Step 3

### Runtime Issues

**Problem**: Camera preview black screen
**Solution**: 
- Ensure camera permission is granted
- Restart the app after granting permission

**Problem**: Video not saved to gallery
**Solution**: 
- Check storage permission
- Ensure sufficient storage space
- Use the system SaveButton for reliable permission handling

**Problem**: PiP mode not working
**Solution**: 
- PiP requires API 12+
- Some devices may not support PiP

## Technical Details

### Camera2 API Usage
- Uses `camera.createCameraInput()` for camera input
- `camera.createVideoOutput()` for video capture
- `camera.createPreviewOutput()` for preview display
- `avRecorder` for video encoding

### State Management
- `@State` decorators for reactive UI updates
- `XComponent` for camera preview surface
- Proper lifecycle management in `aboutToAppear`/`aboutToDisappear`

### Video Parameters
- Resolution: Automatically selected based on camera capabilities
- Frame Rate: 30fps default
- Video Codec: H.264/H.265 (device dependent)
- Audio Codec: AAC
- Bitrate: Dynamically adjusted

## Development

### Build Commands

```bash
# Debug build
hvigorw assembleHap --mode module -p product=default

# Release build
hvigorw assembleHap --mode module -p product=default -p buildMode=release
```

### Clean Build

```bash
hvigorw clean
hvigorw assembleHap --mode module -p product=default
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- HarmonyOS Camera2 API documentation
- DevEco Studio development tools
- HarmonyOS developer community

## Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/qjy-liveforover/Camera_HOS/issues) page.

---

**Made with ❤️ for HarmonyOS**
