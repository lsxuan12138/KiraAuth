import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';
import { LOG_DOMAIN, LOG_TAG } from '../utils/LogUtils';

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup() {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onBackup ok');
  }

  async onRestore(bundleVersion: BundleVersion) {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onRestore ok %{public}s', JSON.stringify(bundleVersion));
  }
}
