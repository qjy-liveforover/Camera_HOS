import { camera } from '@kit.CameraKit';
import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { colorSpaceManager } from '@kit.ArkGraphics2D';

const TAG = 'CameraVideoRecorder';
const DOMAIN = 0xFF00;

// 录制参数接口
export interface RecordingParams {
  resolution: string;       // 分辨率 如 "2160x3840"
  frameRate: number;        // 帧率
  videoBitrate: number;     // 视频比特率 (bps)
  audioBitrate: number;     // 音频比特率 (bps)
  videoCodec: string;       // 视频编码器
  audioCodec: string;       // 音频编码器
  isHdr: boolean;           // 是否HDR
  isHdrVivid: boolean;      // 是否HDR Vivid
  aspectRatio: string;      // 宽高比
  stabilization: string;    // 防抖模式
  colorSpace: string;       // 色彩空间
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
  private recordingParams: RecordingParams | null = null;  // 当前录制参数
  private isHdrVivid: boolean = false;       // 是否HDR Vivid
  private stabilizationMode: string = 'OFF';  // 当前防抖模式
  private activeColorSpace: string = 'BT709'; // 当前色彩空间
  
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

      this.videoSession.beginConfig();
      this.videoSession.addInput(this.cameraInput);
      this.videoSession.addOutput(this.previewOutput);
      
      hilog.info(DOMAIN, TAG, 'Committing preview session config');
      await this.videoSession.commitConfig();
      
      // Mate 70 Pro+ 最佳质量配置
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

    const capability = this.cameraManager.getSupportedOutputCapability(
      this.currentCameraDevice, 
      camera.SceneMode.NORMAL_VIDEO
    );
    
    const videoProfiles = capability.videoProfiles;
    if (!videoProfiles || videoProfiles.length === 0) {
      hilog.error(DOMAIN, TAG, 'No video profiles available');
      return null;
    }

    // Mate 70 Pro+ 最佳录制策略：优先选择 HDR(P010) 格式的最高分辨率和最高帧率
    // HDR Vivid 格式: CAMERA_FORMAT_YCBCR_P010 或 CAMERA_FORMAT_YCRCB_P010
    const isHdrFormat = (format: camera.CameraFormat): boolean => {
      return format === camera.CameraFormat.CAMERA_FORMAT_YCBCR_P010 ||
             format === camera.CameraFormat.CAMERA_FORMAT_YCRCB_P010;
    };

    // Step 1: 收集 HDR 4K profile (最高质量)
    const hdr4KProfiles: camera.VideoProfile[] = [];
    const sdr4KProfiles: camera.VideoProfile[] = [];
    const hdrProfiles: camera.VideoProfile[] = [];
    const sdrProfiles: camera.VideoProfile[] = [];

    for (const profile of videoProfiles) {
      const w = profile.size.width;
      const h = profile.size.height;
      const fps = profile.frameRateRange?.max || 30;
      const pixels = w * h;
      hilog.info(DOMAIN, TAG, `Video profile: ${w}x${h} @ ${fps}fps, format=${profile.format}`);

      if (pixels >= 3840 * 2160) {
        // 4K+
        if (isHdrFormat(profile.format)) {
          hdr4KProfiles.push(profile);
        } else {
          sdr4KProfiles.push(profile);
        }
      } else {
        if (isHdrFormat(profile.format)) {
          hdrProfiles.push(profile);
        } else {
          sdrProfiles.push(profile);
        }
      }
    }

    // 选择策略：HDR 4K > SDR 4K > HDR lower > SDR lower
    // 每种优先选择最高帧率和最大分辨率
    const selectBestFromList = (profiles: camera.VideoProfile[]): camera.VideoProfile | null => {
      if (profiles.length === 0) return null;
      let best: camera.VideoProfile | null = null;
      let bestScore = 0;
      for (const p of profiles) {
        const fps = p.frameRateRange?.max || 30;
        const pixels = p.size.width * p.size.height;
        // Score: pixels as primary, fps as secondary weight
        const score = pixels + fps * 10000;
        if (score > bestScore) {
          bestScore = score;
          best = p;
        }
      }
      return best;
    };

    let bestProfile = selectBestFromList(hdr4KProfiles);
    if (bestProfile) {
      this.isHdrVivid = true;
      hilog.info(DOMAIN, TAG, `HDR Vivid 4K selected: ${bestProfile.size.width}x${bestProfile.size.height} @ ${bestProfile.frameRateRange?.max}fps`);
    } else {
      bestProfile = selectBestFromList(sdr4KProfiles);
    }
    if (!bestProfile) {
      bestProfile = selectBestFromList(hdrProfiles);
      if (bestProfile) this.isHdrVivid = true;
    }
    if (!bestProfile) {
      bestProfile = selectBestFromList(sdrProfiles);
    }

    if (bestProfile) {
      const fps = bestProfile.frameRateRange?.max || 30;
      hilog.info(DOMAIN, TAG, `Selected video profile: ${bestProfile.size.width}x${bestProfile.size.height} @ ${fps}fps, HDR:${this.isHdrVivid}`);
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

  // Apply Mate 70 Pro+ best quality enhancements: stabilization, color space, quality prioritization
  private async applyBestQualityEnhancements(): Promise<void> {
    if (!this.videoSession) return;

    // 1. 视频防抖 - Mate 70 Pro+ 支持高级防抖
    this.applyVideoStabilization();

    // 2. 色彩空间 - HDR Vivid 使用 BT2020_HLG, SDR 使用 BT709
    this.applyColorSpace();

    // 3. 质量优先级设为最高质量
    this.applyQualityPrioritization();
  }

  // 设置视频防抖为最高级别
  private applyVideoStabilization(): void {
    if (!this.videoSession) return;
    
    try {
      // Mate 70 Pro+ 尝试使用 HIGH 级别防抖
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

  // 设置色彩空间：HDR Vivid 用 BT2020_HLG, 否则用 BT709
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

  // 设置录像质量优先级为最高画质
  private applyQualityPrioritization(): void {
    if (!this.videoSession) return;
    
    try {
      this.videoSession.setQualityPrioritization(camera.QualityPrioritization.HIGH_QUALITY);
      hilog.info(DOMAIN, TAG, 'Quality prioritization set to HIGH_QUALITY');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `Quality prioritization error: ${(e as BusinessError).message}`);
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

      // 获取设备支持的最高帧率
      const maxFrameRate = this.videoProfile.frameRateRange?.max || 60;
      hilog.info(DOMAIN, TAG, `Max frame rate from device: ${maxFrameRate}fps, HDR Vivid: ${this.isHdrVivid}`);
      
      // Mate 70 Pro+ 最佳比特率计算
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
        // 其他分辨率
        videoBitrate = Math.round(pixels * maxFrameRate * 0.8);
      }
      hilog.info(DOMAIN, TAG, `Calculated video bitrate: ${videoBitrate / 1000000}Mbps`);
      
      // 音频比特率使用高质量 256kbps (AAC-LC stereo)
      const audioBitrate = 256000;

      // Mate 70 Pro+: 优先使用 HEVC/H.265 编码以获得最佳画质
      // HDR 必须使用 HEVC, SDR 也推荐 HEVC
      const useHevc = isHdr || this.isHdrVivid || true; // 强制使用 HEVC 最佳画质

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
      
      // 保存录制参数供界面显示
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
        colorSpace: this.activeColorSpace
      };
      hilog.info(DOMAIN, TAG, `Recording params: ${JSON.stringify(this.recordingParams)}`);

      const recorderConfig: media.AVRecorderConfig = {
        videoSourceType: media.VideoSourceType.VIDEO_SOURCE_TYPE_SURFACE_YUV,
        audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
        profile: recorderProfile,
        url: `fd://${this.videoFile.fd}`,
        rotation: 270,  // 竖屏方向输出 (前置摄像头竖屏手持)
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
