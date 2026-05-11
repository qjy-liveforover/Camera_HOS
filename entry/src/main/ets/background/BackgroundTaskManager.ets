import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, WantAgent, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'BackgroundTaskManager';
const DOMAIN = 0xFF00;

export class BackgroundTaskManager {
  private context: common.UIAbilityContext;
  private isRunning: boolean = false;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async startLongRunningTask(): Promise<boolean> {
    if (this.isRunning) {
      hilog.warn(DOMAIN, TAG, 'Background task already running');
      return true;
    }

    try {
      // Get bundleName from hapModuleInfo
      const bundleName = this.context.abilityInfo.bundleName;
      hilog.info(DOMAIN, TAG, `Starting background task for: ${bundleName}`);
      
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: bundleName,
            abilityName: 'EntryAbility'
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };

      const wantAgentObj: WantAgent = await wantAgent.getWantAgent(wantAgentInfo);
      
      await new Promise<void>((resolve, reject) => {
        backgroundTaskManager.startBackgroundRunning(
          this.context,
          backgroundTaskManager.BackgroundMode.AUDIO_RECORDING,
          wantAgentObj,
          (error: BusinessError) => {
            if (error) {
              hilog.error(DOMAIN, TAG, `Start background running failed: ${error.code} - ${error.message}`);
              reject(error);
            } else {
              hilog.info(DOMAIN, TAG, 'Background task started successfully');
              this.isRunning = true;
              resolve();
            }
          }
        );
      });

      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, `Failed to start background task: ${err.code} - ${err.message}`);
      return false;
    }
  }

  async stopLongRunningTask(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    try {
      backgroundTaskManager.stopBackgroundRunning(this.context);
      this.isRunning = false;
      hilog.info(DOMAIN, TAG, 'Background task stopped');
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, `Failed to stop background task: ${err.code} - ${err.message}`);
    }
  }

  isTaskRunning(): boolean {
    return this.isRunning;
  }
}
