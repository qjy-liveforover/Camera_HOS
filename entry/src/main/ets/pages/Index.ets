import { common } from '@kit.AbilityKit';
import { RecordingManager } from '../entryability/EntryAbility';
import { PiPController } from '../pip/PiPController';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';

const TAG = 'Index';
const DOMAIN = 0xFF00;

@Entry
@Component
struct Index {
  @State isRecording: boolean = false;
  @State statusText: string = 'Ready';
  @State recordingTime: number = 0;
  @State showSaveDialog: boolean = false;
  @State videoFilePath: string = '';
  @State isPipEnabled: boolean = false;
  @State videoName: string = '';
  @State videoInfo: string = 'Waiting...';
  @State currentResolution: string = '';
  @State showInfo: boolean = false;
  // 动态录制参数
  @State currentFrameRate: number = 0;
  @State currentVideoBitrate: number = 0;
  @State currentAudioBitrate: number = 0;
  @State currentVideoCodec: string = '';
  @State currentAudioCodec: string = '';
  @State currentIsHdr: boolean = false;
  @State currentAspectRatio: string = '';
  
  private context: common.UIAbilityContext | null = null;
  private recordingManager: RecordingManager | null = null;
  private pipController: PiPController | null = null;
  private xComponentController: XComponentController = new XComponentController();
  private timer: number = -1;

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    this.recordingManager = RecordingManager.getInstance();
    this.pipController = new PiPController(this.context);
    this.pipController.setXComponentController(this.xComponentController);
    this.initRecorder();
  }

  aboutToDisappear(): void {
    this.stopTimer();
    if (this.pipController) {
      this.pipController.destroyPipController();
    }
  }

  async initRecorder(): Promise<void> {
    if (this.recordingManager && this.context) {
      const success = await this.recordingManager.init(this.context);
      if (success) {
        hilog.info(DOMAIN, TAG, 'Recorder initialized');
        this.statusText = 'Ready';
      } else {
        this.statusText = 'Init Failed';
      }
    }
  }

  startTimer(): void {
    this.recordingTime = 0;
    this.timer = setInterval(() => {
      this.recordingTime++;
    }, 1000);
  }

  stopTimer(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  formatTime(seconds: number): string {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;
    return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }

  // 获取分辨率名称
  getResolutionName(resolution: string): string {
    const parts = resolution.split('x');
    const w = parseInt(parts[0]);
    const h = parseInt(parts[1]);
    const pixels = w * h;
    if (pixels >= 3840 * 2160) {
      return '4K';
    } else if (pixels >= 2560 * 1440) {
      return '2K';
    } else if (pixels >= 1920 * 1080) {
      return 'FHD';
    } else if (pixels >= 1280 * 720) {
      return 'HD';
    }
    return 'SD';
  }

  // 格式化比特率
  formatBitrate(bitrate: number): string {
    if (bitrate >= 1000000) {
      return `${Math.round(bitrate / 1000000)}Mbps`;
    } else {
      return `${Math.round(bitrate / 1000)}kbps`;
    }
  }

  async toggleRecording(): Promise<void> {
    if (!this.recordingManager) {
      return;
    }

    if (this.isRecording) {
      this.statusText = 'Stopping...';
      
      if (this.pipController && this.isPipEnabled) {
        await this.pipController.stopPip();
      }
      
      const result = await this.recordingManager.stopRecording();
      this.stopTimer();
      this.isRecording = false;
      this.isPipEnabled = false;
      
      this.videoFilePath = this.recordingManager.getVideoPath();
      if (this.videoFilePath) {
        this.videoName = `Video_${Date.now()}`;
        this.showSaveDialog = true;
        this.statusText = 'Complete';
      } else {
        this.statusText = result;
      }
    } else {
      this.statusText = 'Starting...';
      
      hilog.info(DOMAIN, TAG, 'Starting recording from UI...');
      const result = await this.recordingManager.startRecording();
      hilog.info(DOMAIN, TAG, `Recording result: ${result}`);
      
      const match = result.match(/(\d+x\d+)/);
      if (match) {
        this.currentResolution = match[1];
      }
      
      // 获取并更新实际录制参数
      const params = this.recordingManager.getRecordingParams();
      if (params) {
        this.currentFrameRate = params.frameRate;
        this.currentVideoBitrate = params.videoBitrate;
        this.currentAudioBitrate = params.audioBitrate;
        this.currentVideoCodec = params.videoCodec;
        this.currentAudioCodec = params.audioCodec;
        this.currentIsHdr = params.isHdr;
        this.currentAspectRatio = params.aspectRatio;
        
        // 更新videoInfo显示
        const resName = this.getResolutionName(params.resolution);
        this.videoInfo = `${resName} (${params.resolution}) @ ${params.frameRate}fps`;
        
        hilog.info(DOMAIN, TAG, `Recording params updated: ${JSON.stringify(params)}`);
      }
      
      if (result.includes('started') || result.includes('已开始')) {
        this.isRecording = true;
        this.statusText = 'REC';
        this.startTimer();
        
        if (this.pipController) {
          try {
            const pipCreated = await this.pipController.createPipController();
            if (pipCreated) {
              hilog.info(DOMAIN, TAG, 'PiP enabled');
              this.isPipEnabled = true;
            }
          } catch (e) {
            hilog.warn(DOMAIN, TAG, 'PiP creation failed');
          }
          try {
            promptAction.showToast({ message: 'Recording started' });
          } catch (e) {
            hilog.warn(DOMAIN, TAG, 'Toast failed');
          }
        }
      } else {
        this.statusText = 'Failed';
        promptAction.showToast({ message: result });
      }
    }
  }

  async saveVideoToGallery(): Promise<void> {
    if (!this.videoFilePath || !this.context) {
      return;
    }
    
    try {
      hilog.info(DOMAIN, TAG, `Saving video to gallery: ${this.videoFilePath}`);
      
      const helper = photoAccessHelper.getPhotoAccessHelper(this.context);
      
      const createOption: photoAccessHelper.CreateOptions = {
        title: this.videoName
      };
      
      const videoUri = await helper.createAsset(
        photoAccessHelper.PhotoType.VIDEO,
        'mp4',
        createOption
      );
      
      hilog.info(DOMAIN, TAG, `Created video asset: ${videoUri}`);
      
      const albumFile = fs.openSync(videoUri, fs.OpenMode.READ_WRITE);
      const tempFile = fs.openSync(this.videoFilePath, fs.OpenMode.READ_ONLY);
      
      const stat = fs.statSync(this.videoFilePath);
      const bufferSize = 8192;
      let offset = 0;
      const totalSize = stat.size;
      
      hilog.info(DOMAIN, TAG, `Copying video data: ${totalSize} bytes`);
      
      while (offset < totalSize) {
        const readSize = Math.min(bufferSize, totalSize - offset);
        const buffer = new ArrayBuffer(readSize);
        fs.readSync(tempFile.fd, buffer, { offset: offset });
        fs.writeSync(albumFile.fd, buffer);
        offset += readSize;
      }
      
      fs.closeSync(tempFile.fd);
      fs.closeSync(albumFile.fd);
      
      hilog.info(DOMAIN, TAG, `Video saved to gallery: ${videoUri}`);
      
      try {
        fs.unlinkSync(this.videoFilePath);
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'Failed to delete temp file');
      }
      
      this.videoFilePath = '';
      this.showSaveDialog = false;
      this.statusText = 'Saved';
      
      promptAction.showToast({ message: 'Video saved' });
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, `Save failed: ${err.message}`);
      promptAction.showToast({ message: `Save failed: ${err.message}` });
    }
  }

  build() {
    Stack() {
      // Camera preview - full screen background with mirror for front camera
      XComponent({
        id: 'cameraPreview',
        type: XComponentType.SURFACE,
        controller: this.xComponentController
      })
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .scale({ x: -1, y: 1 }) // Mirror horizontally for front camera
        .onLoad(async () => {
          hilog.info(DOMAIN, TAG, 'XComponent loaded');
          // Get surface ID and pass to recorder for preview
          const surfaceId = this.xComponentController.getXComponentSurfaceId();
          hilog.info(DOMAIN, TAG, `Surface ID: ${surfaceId}, length: ${surfaceId?.length}`);
          if (this.recordingManager && surfaceId && surfaceId.length > 0) {
            this.recordingManager.setPreviewSurface(surfaceId);
            hilog.info(DOMAIN, TAG, 'Preview surface set');
            
            // Start preview immediately
            const previewOk = await this.recordingManager.startPreview();
            hilog.info(DOMAIN, TAG, `Preview started: ${previewOk}`);
            if (previewOk) {
              this.statusText = 'Ready';
            } else {
              this.statusText = 'Preview failed';
            }
          } else {
            hilog.warn(DOMAIN, TAG, `Cannot set preview surface`);
          }
        })

      // UI overlay
      Column() {
        // Top bar - fixed at top
        Row() {
          Text('BG Recorder')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)

          Blank()

          // Info button
          Column() {
            Text('?')
              .fontSize(18)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
          }
          .width(36)
          .height(36)
          .borderRadius(18)
          .backgroundColor('#55000000')
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.showInfo = !this.showInfo;
            hilog.info(DOMAIN, TAG, `Show info: ${this.showInfo}`);
          })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)

        // Recording indicator
        if (this.isRecording) {
          Row() {
            Circle()
              .width(10)
              .height(10)
              .fill('#FF0000')

            Text(` ${this.formatTime(this.recordingTime)}`)
              .fontSize(16)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
          }
          .margin({ top: 10 })
        }

        // Info panel (expandable)
        if (this.showInfo) {
          Column() {
            Text('Video Settings')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .margin({ bottom: 12 })

            // 动态显示实际参数
            Text(`Resolution: ${this.currentResolution ? this.getResolutionName(this.currentResolution) + ' (' + this.currentResolution + ')' : 'Detecting...'}`)
              .fontSize(13)
              .fontColor('#CCCCCC')
              .margin({ bottom: 6 })
            Text(`Aspect Ratio: ${this.currentAspectRatio || 'Detecting...'}`)
              .fontSize(13)
              .fontColor('#CCCCCC')
              .margin({ bottom: 6 })
            Text(`Frame Rate: ${this.currentFrameRate ? this.currentFrameRate + 'fps' : 'Detecting...'}`)
              .fontSize(13)
              .fontColor('#CCCCCC')
              .margin({ bottom: 6 })
            Text(`Video Codec: ${this.currentVideoCodec || 'Detecting...'}`)
              .fontSize(13)
              .fontColor('#CCCCCC')
              .margin({ bottom: 6 })
            Text(`Bitrate: ${this.currentVideoBitrate ? this.formatBitrate(this.currentVideoBitrate) : 'Detecting...'}`)
              .fontSize(13)
              .fontColor('#CCCCCC')
              .margin({ bottom: 6 })
            Text(`Audio: ${this.currentAudioCodec || 'AAC'} ${this.currentAudioBitrate ? this.formatBitrate(this.currentAudioBitrate) : '128kbps'}`)
              .fontSize(13)
              .fontColor('#CCCCCC')
              .margin({ bottom: 6 })
            if (this.currentIsHdr) {
              Text('HDR: Enabled')
                .fontSize(13)
                .fontColor('#00FF00')
                .margin({ bottom: 12 })
            } else {
              Blank().height(6)
            }

            Text('Features')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .margin({ bottom: 12 })

            Text('• Front camera recording')
              .fontSize(13)
              .fontColor('#CCCCCC')
              .margin({ bottom: 4 })
            Text('• Auto max parameters')
              .fontSize(13)
              .fontColor('#CCCCCC')
              .margin({ bottom: 4 })
            Text('• PiP background mode')
              .fontSize(13)
              .fontColor('#CCCCCC')
              .margin({ bottom: 4 })
            Text('• Tap PiP to return')
              .fontSize(13)
              .fontColor('#CCCCCC')
              .margin({ bottom: 4 })
            Text('• Close PiP to stop')
              .fontSize(13)
              .fontColor('#CCCCCC')
          }
          .width('90%')
          .padding(16)
          .backgroundColor('#AA000000')
          .borderRadius(12)
          .margin({ top: 15 })
        }

        Blank()

        // Bottom controls
        Column() {
          // Status text
          Text(this.statusText)
            .fontSize(14)
            .fontColor(this.isRecording ? '#FF4444' : '#FFFFFF')
            .margin({ bottom: 8 })

          // Resolution info
          if (!this.showInfo) {
            Text(this.videoInfo)
              .fontSize(12)
              .fontColor('#888888')
              .margin({ bottom: 15 })
          } else {
            Blank().height(15)
          }

          // Record button
          Column() {
            if (this.isRecording) {
              // Stop icon (square)
              Rect()
                .width(28)
                .height(28)
                .fill(Color.White)
                .radius(4)
            } else {
              // Record icon
              Circle()
                .width(55)
                .height(55)
                .fill('#FF4444')
            }
          }
          .width(72)
          .height(72)
          .borderRadius(36)
          .backgroundColor(this.isRecording ? '#FF4444' : 'transparent')
          .border({ width: 4, color: Color.White })
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.toggleRecording();
          })
        }
        .width('100%')
        .padding({ bottom: 40 })
      }
      .width('100%')
      .height('100%')

      // Save dialog
      if (this.showSaveDialog) {
        Column() {
          Column() {
            Text('Save Video')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 20 })

            Text('Video name:')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 8 })
              .width('100%')

            TextInput({ text: this.videoName })
              .width('100%')
              .height(45)
              .onChange((value: string) => {
                this.videoName = value;
              })
              .margin({ bottom: 20 })

            Row() {
              Button('Cancel')
                .width('45%')
                .height(40)
                .backgroundColor(Color.Gray)
                .fontColor(Color.Black)
                .onClick(() => {
                  this.showSaveDialog = false;
                  this.statusText = 'Cancelled';
                })

              Blank()

              SaveButton()
                .width('45%')
                .height(40)
                .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
                  if (result === SaveButtonOnClickResult.SUCCESS) {
                    this.showSaveDialog = false;
                    this.saveVideoToGallery();
                  } else {
                    promptAction.showToast({ message: 'Permission denied' });
                  }
                })
            }
            .width('100%')
          }
          .width('85%')
          .padding(20)
          .backgroundColor(Color.White)
          .borderRadius(16)
          .shadow({ radius: 20, color: '#33000000', offsetX: 0, offsetY: 5 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#55000000')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
