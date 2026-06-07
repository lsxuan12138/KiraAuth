import { common } from '@kit.AbilityKit';
import { UIContext } from '@kit.ArkUI';

export function getUIAbilityContext(uiContext: UIContext): common.UIAbilityContext {
  const hostContext = uiContext.getHostContext();
  if (!hostContext) {
    throw new Error('UIAbilityContext is unavailable');
  }
  return hostContext as common.UIAbilityContext;
}
