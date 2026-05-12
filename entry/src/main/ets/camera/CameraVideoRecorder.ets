import { camera } from '@kit.CameraKit';
import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { colorSpaceManager } from '@kit.ArkGraphics2D';

const TAG = 'CameraVideoRecorder';
const DOMAIN = 0xFF00;

// Recording parameters interface
export interface RecordingParams {
  resolution: string;       // Resolution e.g. "2160x3840"
  frameRate: number;        // Frame rate
  videoBitrate: number;     // Video bitrate (bps)
  audioBitrate: number;     // Audio bitrate (bps)
  videoCodec: string;       // Video codec
  audioCodec: string;       // Audio codec
  isHdr: boolean;           // Whether HDR
  isHdrVivid: boolean;      // Whether HDR Vivid
  aspectRatio: string;      // Aspect ratio
  stabilization: string;    // Stabilization mode
  colorSpace: string;       // Color space
  exposureMode: string;     // AE mode (LOCKED / MANUAL)
  iso: number;              // ISO sensitivity (0 = auto)
  exposureTime: number;     // Exposure duration (µs, 0 = auto)
  exposureBias: number;     // Exposure compensation (EV)
  whiteBalanceMode: string; // WB mode (DAYLIGHT / MANUAL_XXXXK)
  focusMode: string;        // Focus mode (LOCKED / MANUAL)
}

export class CameraVideoRecorder {
  private context: common.UIAbilityContext;
  private cameraManager: camera.CameraManager | null = null;
  private cameraInput: camera.CameraInput | null = null;
  private previewOutput: camera.PreviewOutput | null = null;
  private videoOutput: camera.VideoOutput | null = null;
  private videoSession: camera.VideoSession | null = null;
  private avRecorder: media.AVRecorder | null = null;
  private videoFile: fs.File | null = null;
  private isRecording: boolean = false;
  private currentCameraDevice: camera.CameraDevice | null = null;
  private currentVideoPath: string = '';
  private previewSurfaceId: string = '';
  private isPreviewStarted: boolean = false;
  private videoProfile: camera.VideoProfile | null = null;
  private previewProfile: camera.Profile | null = null;
  private recordingParams: RecordingParams | null = null;  // Current recording parameters
  private isHdrVivid: boolean = false;       // Whether HDR Vivid
  private stabilizationMode: string = 'OFF';  // Current stabilization mode
  private activeColorSpace: string = 'BT709'; // Current color space
  // Reflectance analysis locked parameters
  private activeExposureMode: string = 'LOCKED';    // AE mode
  private activeIso: number = 0;                    // ISO (0=auto)
  private activeExposureTime: number = 0;           // Exposure time µs (0=auto)
  private activeExposureBias: number = 0;           // EV compensation
  private activeWhiteBalanceMode: string = 'DAYLIGHT'; // WB mode
  private activeFocusMode: string = 'LOCKED';       // Focus mode
  
  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }
  
  // Set preview surface from XComponent
  setPreviewSurface(surfaceId: string): void {
    this.previewSurfaceId = surfaceId;
    hilog.info(DOMAIN, TAG, `Preview surface set: ${surfaceId}`);
  }
  
  // Check if preview is active
  isPreviewActive(): boolean {
    return this.isPreviewStarted;
  }

  async init(): Promise<boolean> {
    try {
      this.cameraManager = camera.getCameraManager(this.context);
      if (!this.cameraManager) {
        hilog.error(DOMAIN, TAG, 'Failed to get camera manager');
        return false;
      }
      
      const cameras = this.cameraManager.getSupportedCameras();
      hilog.info(DOMAIN, TAG, `Available cameras: ${cameras.length}`);
      for (const cam of cameras) {
        hilog.info(DOMAIN, TAG, `Camera: ${cam.cameraId}, position: ${cam.cameraPosition}`);
      }
      
      hilog.info(DOMAIN, TAG, 'Camera manager initialized');
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, `Init failed: ${err.code} - ${err.message}`);
      return false;
    }
  }

  // Start preview only (before recording)
  async startPreview(): Promise<boolean> {
    if (this.isPreviewStarted) {
      return true;
    }

    try {
      if (!this.cameraManager) {
        hilog.error(DOMAIN, TAG, 'Camera manager not initialized');
        return false;
      }

      this.currentCameraDevice = this.selectFrontCamera();
      if (!this.currentCameraDevice) {
        hilog.error(DOMAIN, TAG, 'No front camera available');
        return false;
      }

      // Get video profile
      this.videoProfile = this.getBestVideoProfile();
      if (!this.videoProfile) {
        hilog.error(DOMAIN, TAG, 'Cannot get video profile');
        return false;
      }

      // Get preview profile matching video aspect ratio
      this.previewProfile = this.getPreviewProfileMatchingVideo(this.videoProfile);
      if (!this.previewProfile) {
        hilog.error(DOMAIN, TAG, 'Cannot get preview profile');
        return false;
      }

      this.cameraInput = this.cameraManager.createCameraInput(this.currentCameraDevice);
      await this.cameraInput.open();

      // Create preview output
      hilog.info(DOMAIN, TAG, `Preview surface ID: ${this.previewSurfaceId}`);
      if (!this.previewSurfaceId || this.previewSurfaceId.length === 0) {
        hilog.error(DOMAIN, TAG, 'No preview surface ID');
        return false;
      }

      hilog.info(DOMAIN, TAG, `Creating preview output ${this.previewProfile.size.width}x${this.previewProfile.size.height}`);
      this.previewOutput = this.cameraManager.createPreviewOutput(this.previewProfile, this.previewSurfaceId);
      hilog.info(DOMAIN, TAG, 'Preview output created');

      // Create session
      this.videoSession = this.cameraManager.createSession(camera.SceneMode.NORMAL_VIDEO) as camera.VideoSession;
      if (!this.videoSession) {
        hilog.error(DOMAIN, TAG, 'Failed to create video session');
        return false;
      }

      // Reflectance analysis: no preconfig — manually lock all parameters for frame-to-frame consistency
      this.videoSession.beginConfig();
      this.videoSession.addInput(this.cameraInput);
      this.videoSession.addOutput(this.previewOutput);
      
      hilog.info(DOMAIN, TAG, 'Committing preview session config');
      await this.videoSession.commitConfig();
      
      // Mate 70 Pro+ best quality configuration
      await this.applyBestQualityEnhancements();
      
      hilog.info(DOMAIN, TAG, 'Starting preview session');
      await this.videoSession.start();
      
      this.isPreviewStarted = true;
      hilog.info(DOMAIN, TAG, 'Preview started successfully');
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, `Start preview failed: ${err.code} - ${err.message}`);
      return false;
    }
  }

  private getBestVideoProfile(): camera.VideoProfile | null {
    if (!this.cameraManager || !this.currentCameraDevice) {
      return null;
    }

    // TODO: When API 23+ available, replace with getSupportedFullOutputCapability for full HDR capability
    const capability = this.cameraManager.getSupportedOutputCapability(
      this.currentCameraDevice,
      camera.SceneMode.NORMAL_VIDEO
    );
    
    const videoProfiles = capability.videoProfiles;
    if (!videoProfiles || videoProfiles.length === 0) {
      hilog.error(DOMAIN, TAG, 'No video profiles available');
      return null;
    }

    // Reflectance analysis mode: skip HDR Vivid entirely.
    // HDR tone mapping alters the reflectance → pixel-value relationship non-linearly
    // and scene-dependently, making quantitative material analysis impossible.
    // SDR with BT.709 provides a predictable, fixed color response.
    const isHdrFormat = (format: camera.CameraFormat): boolean => {
      return format === camera.CameraFormat.CAMERA_FORMAT_YCBCR_P010 ||
             format === camera.CameraFormat.CAMERA_FORMAT_YCRCB_P010;
    };

    const sdrProfiles: camera.VideoProfile[] = [];

    for (const profile of videoProfiles) {
      const w = profile.size.width;
      const h = profile.size.height;
      const fps = profile.frameRateRange?.max || 30;
      hilog.info(DOMAIN, TAG, `Video profile: ${w}x${h} @ ${fps}fps, format=${profile.format}`);
      if (!isHdrFormat(profile.format)) {
        sdrProfiles.push(profile);
      }
    }

    if (sdrProfiles.length === 0) {
      hilog.error(DOMAIN, TAG, 'No SDR video profiles available');
      return null;
    }

    // Select maximum resolution + highest frame rate SDR profile
    let bestProfile: camera.VideoProfile | null = null;
    let bestScore = 0;
    for (const p of sdrProfiles) {
      const fps = p.frameRateRange?.max || 30;
      const pixels = p.size.width * p.size.height;
      const score = pixels + fps * 10000;
      if (score > bestScore) {
        bestScore = score;
        bestProfile = p;
      }
    }

    this.isHdrVivid = false;
    if (bestProfile) {
      hilog.info(DOMAIN, TAG,
        `Selected SDR profile: ${bestProfile.size.width}x${bestProfile.size.height} @ ${bestProfile.frameRateRange?.max}fps`);
    }
    return bestProfile;
  }

  private getPreviewProfileMatchingVideo(videoProfile: camera.VideoProfile): camera.Profile | null {
    if (!this.cameraManager || !this.currentCameraDevice) {
      return null;
    }

    const capability = this.cameraManager.getSupportedOutputCapability(
      this.currentCameraDevice, 
      camera.SceneMode.NORMAL_VIDEO
    );
    
    const previewProfiles = capability.previewProfiles;
    if (!previewProfiles || previewProfiles.length === 0) {
      hilog.error(DOMAIN, TAG, 'No preview profiles available');
      return null;
    }

    hilog.info(DOMAIN, TAG, `Finding preview profile matching video ${videoProfile.size.width}x${videoProfile.size.height}`);
    
    // Find preview profile with same aspect ratio as video
    const videoRatio = videoProfile.size.width / videoProfile.size.height;
    for (const p of previewProfiles) {
      const previewRatio = p.size.width / p.size.height;
      if (Math.abs(previewRatio - videoRatio) < 0.01) {
        hilog.info(DOMAIN, TAG, `Found matching preview: ${p.size.width}x${p.size.height}`);
        return p;
      }
    }

    // Fallback to first profile
    hilog.warn(DOMAIN, TAG, `No matching aspect ratio, using first: ${previewProfiles[0].size.width}x${previewProfiles[0].size.height}`);
    return previewProfiles[0];
  }

  // Apply Mate 70 Pro+ best quality enhancements + reflectance analysis locks
  private async applyBestQualityEnhancements(): Promise<void> {
    if (!this.videoSession) return;

    // 1. Video stabilization - Mate 70 Pro+ supports advanced stabilization
    this.applyVideoStabilization();

    // 2. Color space - HDR Vivid uses BT2020_HLG, SDR uses BT709
    this.applyColorSpace();

    // 3. Set quality prioritization to highest quality
    this.applyQualityPrioritization();

    // 4. Lock AE/AWB/AF for reflectance analysis — pixel-to-reflectance consistency
    this.applyReflectanceAnalysisLocks();
  }

  // Set video stabilization to highest level
  private applyVideoStabilization(): void {
    if (!this.videoSession) return;
    
    try {
      // Mate 70 Pro+: try HIGH level stabilization first
      const modes: camera.VideoStabilizationMode[] = [
        camera.VideoStabilizationMode.HIGH,
        camera.VideoStabilizationMode.MIDDLE,
        camera.VideoStabilizationMode.LOW,
        camera.VideoStabilizationMode.AUTO
      ];
      
      for (const mode of modes) {
        const supported = this.videoSession.isVideoStabilizationModeSupported(mode);
        if (supported) {
          this.videoSession.setVideoStabilizationMode(mode);
          const active = this.videoSession.getActiveVideoStabilizationMode();
          this.stabilizationMode = mode.toString();
          hilog.info(DOMAIN, TAG, `Video stabilization set: ${mode} (active: ${active})`);
          return;
        }
      }
      hilog.info(DOMAIN, TAG, 'Video stabilization not supported');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `Video stabilization error: ${(e as BusinessError).message}`);
    }
  }

  // Set color space: HDR Vivid uses BT2020_HLG, otherwise BT709
  private applyColorSpace(): void {
    if (!this.videoSession) return;
    
    try {
      const targetColorSpace = this.isHdrVivid
        ? colorSpaceManager.ColorSpace.BT2020_HLG_LIMIT
        : colorSpaceManager.ColorSpace.BT709_LIMIT;
      
      const supportedSpaces = this.videoSession.getSupportedColorSpaces();
      if (supportedSpaces.indexOf(targetColorSpace) >= 0) {
        this.videoSession.setColorSpace(targetColorSpace);
        const active = this.videoSession.getActiveColorSpace();
        this.activeColorSpace = targetColorSpace.toString();
        hilog.info(DOMAIN, TAG, `Color space set: ${targetColorSpace} (active: ${active})`);
      } else {
        hilog.info(DOMAIN, TAG, `Color space ${targetColorSpace} not supported, available: ${supportedSpaces}`);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `Color space error: ${(e as BusinessError).message}`);
    }
  }

  // Set recording quality prioritization to highest quality
  private applyQualityPrioritization(): void {
    if (!this.videoSession) return;
    
    try {
      this.videoSession.setQualityPrioritization(camera.QualityPrioritization.HIGH_QUALITY);
      hilog.info(DOMAIN, TAG, 'Quality prioritization set to HIGH_QUALITY');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `Quality prioritization error: ${(e as BusinessError).message}`);
    }
  }

  // ───── Reflectance Analysis: Lock all auto-adjustments ─────
  // For quantitative analysis of spice powder reflectance under pure-color light,
  // every automatic adjustment must be frozen to maintain a fixed, predictable
  // pixel-value → reflectance mapping across all frames and captures.
  //
  // Strategy:
  //   AE  → LOCKED (freezes exposure at current metered value)
  //   AWB → DAYLIGHT (5500K fixed, avoiding AWB_OFF green-tint bug on Huawei)
  //   AF  → CONTINUOUS_AUTO then lock via software (no AF drift)
  //   ISO → queried but left at current lock value
  private applyReflectanceAnalysisLocks(): void {
    if (!this.videoSession) return;
    hilog.info(DOMAIN, TAG, '───── Applying reflectance analysis locks ─────');

    this.lockAutoExposure();
    this.lockWhiteBalance();
    this.lockAutoFocus();
    this.zeroExposureCompensation();

    hilog.info(DOMAIN, TAG, '───── Reflectance analysis locks complete ─────');
  }

  // Lock AE at current metered value — prevents exposure drift between frames
  private lockAutoExposure(): void {
    if (!this.videoSession) return;
    try {
      const aeSupported = this.videoSession.isExposureModeSupported(
        camera.ExposureMode.EXPOSURE_MODE_LOCKED
      );
      if (aeSupported) {
        this.videoSession.setExposureMode(camera.ExposureMode.EXPOSURE_MODE_LOCKED);
        const mode = this.videoSession.getExposureMode();
        this.activeExposureMode = 'LOCKED';
        hilog.info(DOMAIN, TAG, `AE locked (mode: ${mode})`);
      } else {
        hilog.warn(DOMAIN, TAG, 'EXPOSURE_MODE_LOCKED not supported');
        this.activeExposureMode = 'UNAVAILABLE';
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `AE lock error: ${(e as BusinessError).message}`);
      this.activeExposureMode = 'ERROR';
    }
  }

  // Lock white balance to fixed DAYLIGHT (≈5500K)
  // Uses preset mode instead of AWB_OFF + manual matrix to avoid the known
  // Huawei green-preview bug when COLOR_CORRECTION_MODE_TRANSFORM_MATRIX is set.
  // For pure-color light experiments, DAYLIGHT provides a fixed, reproducible
  // reference that will not attempt to "neutralize" the illuminating color.
  private lockWhiteBalance(): void {
    if (!this.videoSession) return;
    try {
      // Priority: MANUAL mode with explicit Kelvin value for precise control
      const manualSupported = this.videoSession.isWhiteBalanceModeSupported(
        camera.WhiteBalanceMode.MANUAL
      );
      if (manualSupported) {
        const wbRange = this.videoSession.getWhiteBalanceRange();
        if (wbRange && wbRange.length === 2) {
          // Use 5500K (daylight reference) — center of the supported range
          const targetK = Math.max(wbRange[0], Math.min(wbRange[1], 5500));
          this.videoSession.setWhiteBalanceMode(camera.WhiteBalanceMode.MANUAL);
          this.videoSession.setWhiteBalance(targetK);
          const actualK = this.videoSession.getWhiteBalance();
          this.activeWhiteBalanceMode = `MANUAL_${actualK}K`;
          hilog.info(DOMAIN, TAG, `WB locked: MANUAL ${actualK}K (requested ${targetK}K, range [${wbRange[0]},${wbRange[1]}])`);
          return;
        }
      }

      // Fallback: DAYLIGHT preset (fixed ~5500K)
      const daylightSupported = this.videoSession.isWhiteBalanceModeSupported(
        camera.WhiteBalanceMode.DAYLIGHT
      );
      if (daylightSupported) {
        this.videoSession.setWhiteBalanceMode(camera.WhiteBalanceMode.DAYLIGHT);
        this.activeWhiteBalanceMode = 'DAYLIGHT';
        hilog.info(DOMAIN, TAG, 'WB locked: DAYLIGHT preset (~5500K)');
        return;
      }

      // Last resort: try INCANDESCENT as a fixed preset (3200K)
      const incandescentSupported = this.videoSession.isWhiteBalanceModeSupported(
        camera.WhiteBalanceMode.INCANDESCENT
      );
      if (incandescentSupported) {
        this.videoSession.setWhiteBalanceMode(camera.WhiteBalanceMode.INCANDESCENT);
        this.activeWhiteBalanceMode = 'INCANDESCENT';
        hilog.info(DOMAIN, TAG, 'WB locked: INCANDESCENT preset (fallback)');
        return;
      }

      hilog.warn(DOMAIN, TAG, 'No fixed WB mode supported — AWB may drift');
      this.activeWhiteBalanceMode = 'AUTO (WARNING)';
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `WB lock error: ${(e as BusinessError).message}`);
      this.activeWhiteBalanceMode = 'ERROR';
    }
  }

  // Lock focus at center using CONTINUOUS_AUTO then freeze
  private lockAutoFocus(): void {
    if (!this.videoSession) return;
    try {
      // Set to continuous auto-focus, center-weighted, to establish stable focus,
      // then switch to locked mode to prevent hunting during recording.
      const caSupported = this.videoSession.isFocusModeSupported(
        camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO
      );
      if (caSupported) {
        // Set center focus point
        const centerPoint: camera.Point = { x: 0.5, y: 0.5 };
        this.videoSession.setFocusPoint(centerPoint);
        this.videoSession.setFocusMode(camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO);
        hilog.info(DOMAIN, TAG, 'AF: CONTINUOUS_AUTO with center point');

        // Attempt to switch to FOCUS_MODE_LOCKED if available
        const lockedSupported = this.videoSession.isFocusModeSupported(
          camera.FocusMode.FOCUS_MODE_LOCKED
        );
        if (lockedSupported) {
          this.videoSession.setFocusMode(camera.FocusMode.FOCUS_MODE_LOCKED);
          this.activeFocusMode = 'LOCKED';
          hilog.info(DOMAIN, TAG, 'AF locked (FOCUS_MODE_LOCKED)');
          return;
        }

        this.activeFocusMode = 'CONTINUOUS_AUTO (best effort)';
        hilog.info(DOMAIN, TAG, 'AF: LOCKED unsupported, using CONTINUOUS_AUTO');
        return;
      }

      // Fallback: basic AUTO
      const autoSupported = this.videoSession.isFocusModeSupported(
        camera.FocusMode.FOCUS_MODE_AUTO
      );
      if (autoSupported) {
        const centerPoint: camera.Point = { x: 0.5, y: 0.5 };
        this.videoSession.setFocusPoint(centerPoint);
        this.videoSession.setFocusMode(camera.FocusMode.FOCUS_MODE_AUTO);
        this.activeFocusMode = 'AUTO (best effort)';
        hilog.info(DOMAIN, TAG, 'AF: AUTO with center point');
        return;
      }

      hilog.warn(DOMAIN, TAG, 'No AF mode supported');
      this.activeFocusMode = 'UNAVAILABLE';
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `AF lock error: ${(e as BusinessError).message}`);
      this.activeFocusMode = 'ERROR';
    }
  }

  // Set exposure compensation to zero (no bias)
  private zeroExposureCompensation(): void {
    if (!this.videoSession) return;
    try {
      const biasRange = this.videoSession.getExposureBiasRange();
      if (biasRange && biasRange.length >= 2) {
        this.videoSession.setExposureBias(0);
        const actualBias = this.videoSession.getExposureValue();
        this.activeExposureBias = actualBias;
        hilog.info(DOMAIN, TAG, `Exposure bias zeroed: ${actualBias} EV (range [${biasRange[0]},${biasRange[1]}])`);
      } else {
        hilog.info(DOMAIN, TAG, 'Exposure bias range unavailable');
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `Exposure bias error: ${(e as BusinessError).message}`);
    }
  }

  private selectFrontCamera(): camera.CameraDevice | null {
    if (!this.cameraManager) {
      return null;
    }

    const cameras = this.cameraManager.getSupportedCameras();
    for (const cam of cameras) {
      if (cam.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT) {
        hilog.info(DOMAIN, TAG, `Selected front camera: ${cam.cameraId}`);
        return cam;
      }
    }
    
    if (cameras.length > 0) {
      hilog.warn(DOMAIN, TAG, `No front camera, using: ${cameras[0].cameraId}`);
      return cameras[0];
    }
    
    return null;
  }

  async startRecording(): Promise<string> {
    if (this.isRecording) {
      return 'Already recording';
    }

    try {
      // If preview is not started, start it first
      if (!this.isPreviewStarted) {
        const previewOk = await this.startPreview();
        if (!previewOk) {
          return 'Failed to start preview';
        }
      }

      if (!this.videoProfile || !this.videoSession || !this.previewOutput) {
        return 'Preview not properly initialized';
      }

      const timestamp = Date.now();
      const fileName = `video_${timestamp}.mp4`;
      this.currentVideoPath = `${this.context.filesDir}/${fileName}`;
      this.videoFile = fs.openSync(this.currentVideoPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      hilog.info(DOMAIN, TAG, `Video file: ${this.currentVideoPath}`);

      this.avRecorder = await media.createAVRecorder();
      if (!this.avRecorder) {
        return 'Failed to create recorder';
      }
      
      // Check if HDR format
      const isHdr: boolean = [
        camera.CameraFormat.CAMERA_FORMAT_YCBCR_P010,
        camera.CameraFormat.CAMERA_FORMAT_YCRCB_P010
      ].includes(this.videoProfile.format);

      // Get the highest frame rate supported by device
      const maxFrameRate = this.videoProfile.frameRateRange?.max || 60;
      hilog.info(DOMAIN, TAG, `Max frame rate from device: ${maxFrameRate}fps, HDR Vivid: ${this.isHdrVivid}`);
      
      // Mate 70 Pro+ optimal bitrate calculation
      // HDR Vivid 4K: 120-160Mbps, SDR 4K: 100-120Mbps, 1080p: 60-80Mbps
      const pixels = this.videoProfile.size.width * this.videoProfile.size.height;
      let videoBitrate: number;
      if (pixels >= 3840 * 2160) {
        if (this.isHdrVivid) {
          // HDR Vivid 4K+: base 140Mbps @ 60fps, max 160Mbps
          videoBitrate = Math.round(140000000 * (maxFrameRate / 60));
          videoBitrate = Math.min(videoBitrate, 160000000);
        } else {
          // SDR 4K+: base 100Mbps @ 60fps, max 120Mbps
          videoBitrate = Math.round(100000000 * (maxFrameRate / 60));
          videoBitrate = Math.min(videoBitrate, 120000000);
        }
      } else if (pixels >= 1920 * 1080) {
        // 1080p: base 60Mbps @ 60fps, max 80Mbps
        videoBitrate = Math.round(60000000 * (maxFrameRate / 60));
        videoBitrate = Math.min(videoBitrate, 80000000);
      } else {
        // Other resolutions
        videoBitrate = Math.round(pixels * maxFrameRate * 0.8);
      }
      hilog.info(DOMAIN, TAG, `Calculated video bitrate: ${videoBitrate / 1000000}Mbps`);
      
      // Audio bitrate: highest quality 320kbps (AAC-LC stereo)
      const audioBitrate = 320000;

      // Mate 70 Pro+: prefer HEVC/H.265 encoding for best quality
      // HDR requires HEVC, SDR also recommended to use HEVC
      const useHevc = isHdr || this.isHdrVivid || true; // Force HEVC for best quality

      const recorderProfile: media.AVRecorderProfile = {
        fileFormat: media.ContainerFormatType.CFT_MPEG_4,
        videoBitrate: videoBitrate,
        videoCodec: useHevc ? media.CodecMimeType.VIDEO_HEVC : media.CodecMimeType.VIDEO_AVC,
        videoFrameWidth: this.videoProfile.size.width,
        videoFrameHeight: this.videoProfile.size.height,
        videoFrameRate: maxFrameRate,
        audioBitrate: audioBitrate,
        audioChannels: 2,
        audioCodec: media.CodecMimeType.AUDIO_AAC,
        audioSampleRate: 48000,
        isHdr: isHdr
      };
      
      // Save recording parameters for UI display
      const w = this.videoProfile.size.width;
      const h = this.videoProfile.size.height;
      const ratio = w > h ? `${w/h === 16/9 ? '16:9' : w/h === 4/3 ? '4:3' : (w/h).toFixed(2)}` : 
                          `${h/w === 16/9 ? '16:9' : h/w === 4/3 ? '4:3' : (h/w).toFixed(2)}`;
      this.recordingParams = {
        resolution: `${w}x${h}`,
        frameRate: maxFrameRate,
        videoBitrate: videoBitrate,
        audioBitrate: audioBitrate,
        videoCodec: useHevc ? 'H.265 HEVC' : 'H.264 AVC',
        audioCodec: 'AAC',
        isHdr: isHdr,
        isHdrVivid: this.isHdrVivid,
        aspectRatio: w > h ? `${ratio} Landscape` : `${ratio} Portrait`,
        stabilization: this.stabilizationMode,
        colorSpace: this.activeColorSpace,
        exposureMode: this.activeExposureMode,
        iso: this.activeIso,
        exposureTime: this.activeExposureTime,
        exposureBias: this.activeExposureBias,
        whiteBalanceMode: this.activeWhiteBalanceMode,
        focusMode: this.activeFocusMode
      };
      hilog.info(DOMAIN, TAG, `Recording params: ${JSON.stringify(this.recordingParams)}`);

      const recorderConfig: media.AVRecorderConfig = {
        videoSourceType: media.VideoSourceType.VIDEO_SOURCE_TYPE_SURFACE_YUV,
        audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
        profile: recorderProfile,
        url: `fd://${this.videoFile.fd}`,
        rotation: 270,  // Portrait orientation output (front camera portrait handheld)
        location: { latitude: 0, longitude: 0 }
      };

      await this.avRecorder.prepare(recorderConfig);
      
      const videoSurfaceId = await this.avRecorder.getInputSurface();
      if (!videoSurfaceId) {
        return 'Failed to get video surface';
      }

      if (!this.cameraManager) {
        return 'Camera manager is null';
      }

      // Create video output
      hilog.info(DOMAIN, TAG, `Creating video output ${this.videoProfile.size.width}x${this.videoProfile.size.height}`);
      this.videoOutput = this.cameraManager.createVideoOutput(this.videoProfile, videoSurfaceId);
      if (!this.videoOutput) {
        return 'Failed to create video output';
      }

      // Reconfigure session with both preview and video outputs
      hilog.info(DOMAIN, TAG, 'Reconfiguring session for recording');
      
      // Stop session
      hilog.info(DOMAIN, TAG, 'Stopping session');
      await this.videoSession.stop();
      
      // Begin reconfiguration
      hilog.info(DOMAIN, TAG, 'Beginning session config');
      this.videoSession.beginConfig();
      
      // Remove old preview output
      hilog.info(DOMAIN, TAG, 'Removing old preview output');
      this.videoSession.removeOutput(this.previewOutput!);
      
      // Check if video output can be added
      const canAddVideo = this.videoSession.canAddOutput(this.videoOutput);
      hilog.info(DOMAIN, TAG, `canAddOutput(videoOutput): ${canAddVideo}`);
      if (!canAddVideo) {
        return 'Cannot add video output to session';
      }
      
      // Add video output first
      hilog.info(DOMAIN, TAG, 'Adding video output');
      this.videoSession.addOutput(this.videoOutput);
      
      // Check if preview output can be added
      const canAddPreview = this.videoSession.canAddOutput(this.previewOutput!);
      hilog.info(DOMAIN, TAG, `canAddOutput(previewOutput): ${canAddPreview}`);
      if (!canAddPreview) {
        return 'Cannot add preview output to session';
      }
      
      // Add preview output
      hilog.info(DOMAIN, TAG, 'Adding preview output');
      this.videoSession.addOutput(this.previewOutput!);
      
      // Commit and restart
      hilog.info(DOMAIN, TAG, 'Committing session config');
      await this.videoSession.commitConfig();
      
      hilog.info(DOMAIN, TAG, 'Starting session');
      await this.videoSession.start();
      
      // Start video output
      hilog.info(DOMAIN, TAG, 'Starting video output');
      await this.videoOutput.start();
      
      // Start AVRecorder
      hilog.info(DOMAIN, TAG, 'Starting AVRecorder');
      await this.avRecorder.start();

      this.isRecording = true;
      const hdrLabel = this.isHdrVivid ? ' HDR Vivid' : (isHdr ? ' HDR' : '');
      return `Recording started (${this.videoProfile.size.width}x${this.videoProfile.size.height}${hdrLabel})`;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, `Start recording failed: ${err.code} - ${err.message}`);
      await this.cleanup();
      return `Recording failed: ${err.message}`;
    }
  }

  async stopRecording(): Promise<string> {
    if (!this.isRecording) {
      return 'Not recording';
    }

    this.isRecording = false;
    
    try {
      // Stop video output
      if (this.videoOutput) {
        try { await this.videoOutput.stop(); } catch (e) {}
        
        // Remove video output from session
        if (this.videoSession) {
          try {
            await this.videoSession.stop();
            this.videoSession.beginConfig();
            this.videoSession.removeOutput(this.videoOutput);
            await this.videoSession.commitConfig();
            await this.videoSession.start();
          } catch (e) {
            hilog.warn(DOMAIN, TAG, `Failed to remove video output: ${(e as BusinessError).code}`);
          }
        }
        
        this.videoOutput = null;
      }

      // Stop and release AVRecorder
      if (this.avRecorder) {
        try {
          await this.avRecorder.stop();
          await this.avRecorder.release();
        } catch (e) {}
        this.avRecorder = null;
      }

      // Close video file
      if (this.videoFile) {
        fs.closeSync(this.videoFile.fd);
        this.videoFile = null;
      }

      return 'Recording stopped';
    } catch (error) {
      const err = error as BusinessError;
      return `Stop failed: ${err.message}`;
    }
  }

  // Get video file path
  getVideoPath(): string {
    return this.currentVideoPath;
  }

  // Clear video file path
  clearVideoPath(): void {
    this.currentVideoPath = '';
  }

  // Get current recording parameters
  getRecordingParams(): RecordingParams | null {
    return this.recordingParams;
  }

  private async cleanup(): Promise<void> {
    this.isRecording = false;
    this.isPreviewStarted = false;
    
    if (this.previewOutput) {
      try { await this.previewOutput.stop(); } catch (e) {}
      this.previewOutput = null;
    }
    
    if (this.videoOutput) {
      try { await this.videoOutput.stop(); } catch (e) {}
      this.videoOutput = null;
    }
    
    if (this.avRecorder) {
      try {
        await this.avRecorder.stop();
        await this.avRecorder.release();
      } catch (e) {}
      this.avRecorder = null;
    }
    
    if (this.videoSession) {
      try {
        await this.videoSession.stop();
        await this.videoSession.release();
      } catch (e) {}
      this.videoSession = null;
    }
    
    if (this.cameraInput) {
      try { await this.cameraInput.close(); } catch (e) {}
      this.cameraInput = null;
    }
    
    if (this.videoFile) {
      try { fs.closeSync(this.videoFile.fd); } catch (e) {}
      this.videoFile = null;
    }
  }

  getRecordingState(): boolean {
    return this.isRecording;
  }

  async release(): Promise<void> {
    await this.cleanup();
    this.cameraManager = null;
  }
}
