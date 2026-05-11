import { PiPWindow } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'PiPController';
const DOMAIN = 0xFF00;

export class PiPController {
  private pipController: PiPWindow.PiPController | null = null;
  private context: common.UIAbilityContext;
  private xComponentController: XComponentController | null = null;
  private isRunning: boolean = false;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  setXComponentController(controller: XComponentController): void {
    this.xComponentController = controller;
  }

  async createPipController(): Promise<boolean> {
    if (this.pipController) {
      return true;
    }

    if (!this.xComponentController) {
      hilog.error(DOMAIN, TAG, 'XComponentController is null');
      return false;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Creating PiP controller...');
      
      // Use VIDEO_CALL template, more suitable for camera recording scenario
      this.pipController = await PiPWindow.create({
        context: this.context,
        componentController: this.xComponentController,
        templateType: PiPWindow.PiPTemplateType.VIDEO_CALL
      });

      // Register state listener
      this.pipController.on('stateChange', (state: PiPWindow.PiPState, reason: string) => {
        this.onStateChange(state, reason);
      });

      // Enable auto-start (auto enter PiP when moving to background)
      this.pipController.setAutoStartEnabled(true);
      
      hilog.info(DOMAIN, TAG, 'PiP controller created successfully');
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Create PiP failed: ${error}`);
      return false;
    }
  }

  private onStateChange(state: PiPWindow.PiPState, reason: string): void {
    hilog.info(DOMAIN, TAG, `PiP state: ${state}, reason: ${reason}`);
    
    switch (state) {
      case PiPWindow.PiPState.STARTED:
        this.isRunning = true;
        hilog.info(DOMAIN, TAG, 'PiP started');
        // Portrait ratio 9:16, matches phone screen direction
        this.updateContentSize(9, 16);
        break;
      case PiPWindow.PiPState.STOPPED:
        this.isRunning = false;
        hilog.info(DOMAIN, TAG, 'PiP stopped');
        break;
      case PiPWindow.PiPState.ABOUT_TO_RESTORE:
        hilog.info(DOMAIN, TAG, 'PiP about to restore');
        break;
      default:
        break;
    }
  }

  // Update PiP window content aspect ratio
  private updateContentSize(width: number, height: number): void {
    if (!this.pipController) {
      return;
    }
    try {
      this.pipController.updateContentSize(width, height);
      hilog.info(DOMAIN, TAG, `PiP content size updated: ${width}x${height}`);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Update content size failed: ${error}`);
    }
  }

  async startPip(): Promise<boolean> {
    if (!this.pipController) {
      const created = await this.createPipController();
      if (!created) {
        return false;
      }
    }

    try {
      if (this.pipController) {
        await this.pipController.startPiP();
        hilog.info(DOMAIN, TAG, 'PiP started');
        return true;
      }
      return false;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Start PiP failed: ${error}`);
      return false;
    }
  }

  async stopPip(): Promise<void> {
    if (!this.pipController) {
      return;
    }

    try {
      await this.pipController.stopPiP();
      hilog.info(DOMAIN, TAG, 'PiP stopped');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Stop PiP failed: ${error}`);
    }
  }

  destroyPipController(): void {
    if (!this.pipController) {
      return;
    }

    try {
      this.pipController.setAutoStartEnabled(false);
      this.pipController.off('stateChange');
      this.pipController = null;
      hilog.info(DOMAIN, TAG, 'PiP controller destroyed');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Destroy PiP failed: ${error}`);
    }
  }

  isPipRunning(): boolean {
    return this.isRunning;
  }
}
