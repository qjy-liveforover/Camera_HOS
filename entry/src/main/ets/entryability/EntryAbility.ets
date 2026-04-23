import { AbilityConstant, ConfigurationConstant, UIAbility, Want, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { CameraVideoRecorder, RecordingParams } from '../camera/CameraVideoRecorder';
import { BackgroundTaskManager } from '../background/BackgroundTaskManager';

const DOMAIN = 0xFF00;
const TAG = 'EntryAbility';

// 全局录像管理器
export class RecordingManager {
  private static instance: RecordingManager | null = null;
  private videoRecorder: CameraVideoRecorder | null = null;
  private backgroundTask: BackgroundTaskManager | null = null;
  private isRecording: boolean = false;
  private context: common.UIAbilityContext | null = null;

  static getInstance(): RecordingManager {
    if (!RecordingManager.instance) {
      RecordingManager.instance = new RecordingManager();
    }
    return RecordingManager.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  setPreviewSurface(surfaceId: string): void {
    if (this.videoRecorder) {
      this.videoRecorder.setPreviewSurface(surfaceId);
    }
  }

  async startPreview(): Promise<boolean> {
    if (this.videoRecorder) {
      return await this.videoRecorder.startPreview();
    }
    return false;
  }

  async init(context: common.UIAbilityContext): Promise<boolean> {
    this.context = context;
    if (!this.videoRecorder) {
      this.videoRecorder = new CameraVideoRecorder(context);
      const success = await this.videoRecorder.init();
      hilog.info(DOMAIN, TAG, `Recorder init: ${success}`);
      return success;
    }
    return true;
  }

  async startRecording(): Promise<string> {
    if (!this.context) {
      return 'Context is null';
    }

    if (this.isRecording) {
      return 'Already recording';
    }

    try {
      // Start background task
      if (!this.backgroundTask) {
        this.backgroundTask = new BackgroundTaskManager(this.context);
      }
      
      hilog.info(DOMAIN, TAG, 'Starting background task...');
      const bgSuccess = await this.backgroundTask.startLongRunningTask();
      if (!bgSuccess) {
        hilog.error(DOMAIN, TAG, 'Background task failed');
        return 'Background task failed';
      }
      hilog.info(DOMAIN, TAG, 'Background task started');

      // Start recording
      if (!this.videoRecorder) {
        this.videoRecorder = new CameraVideoRecorder(this.context);
        await this.videoRecorder.init();
      }

      const result = await this.videoRecorder.startRecording();
      if (result.includes('started') || result.includes('已开始')) {
        this.isRecording = true;
        hilog.info(DOMAIN, TAG, 'Recording started');
      } else {
        await this.backgroundTask.stopLongRunningTask();
      }
      return result;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Start recording error: ${error}`);
      return `Start failed: ${error}`;
    }
  }

  async stopRecording(): Promise<string> {
    if (!this.isRecording) {
      return 'Not recording';
    }

    try {
      hilog.info(DOMAIN, TAG, 'Stopping recording...');
      
      if (this.videoRecorder) {
        const result = await this.videoRecorder.stopRecording();
        hilog.info(DOMAIN, TAG, `Recorder stopped: ${result}`);
      }

      if (this.backgroundTask) {
        await this.backgroundTask.stopLongRunningTask();
        hilog.info(DOMAIN, TAG, 'Background task stopped');
      }

      this.isRecording = false;
      return '录像已停止';
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Stop recording error: ${error}`);
      this.isRecording = false;
      return `停止失败: ${error}`;
    }
  }

  getVideoPath(): string {
    return this.videoRecorder?.getVideoPath() || '';
  }

  clearVideoPath(): void {
    this.videoRecorder?.clearVideoPath();
  }

  isCurrentlyRecording(): boolean {
    return this.isRecording;
  }

  // 获取当前录制参数
  getRecordingParams(): RecordingParams | null {
    return this.videoRecorder?.getRecordingParams() || null;
  }

  async release(): Promise<void> {
    await this.stopRecording();
    this.videoRecorder = null;
    this.backgroundTask = null;
  }
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
    
    // 初始化录像管理器
    RecordingManager.getInstance().setContext(this.context);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
    RecordingManager.getInstance().release();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground - recording continues in background');
  }
}
