/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      // Bind the preference before the start window is resolved. Otherwise a
      // device running in dark system mode can show a dark splash while the
      // app preference (and the first page) is light.
      PersistentStorage.persistProp('v2exDarkMode', false);
      const darkMode: boolean = AppStorage.get<boolean>('v2exDarkMode') ?? false;
      this.context.getApplicationContext().setColorMode(
        darkMode ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
      );
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // Render the native client edge-to-edge so the gesture area uses the same
    // surface as the page instead of falling back to the platform black bar.
    // Keep the system-bar icons enabled and light-on-dark handling explicit;
    // page roots still apply their own content spacing where needed.
    windowStage.getMainWindow().then((mainWindow: window.Window) => {
      const darkMode: boolean = AppStorage.get<boolean>('v2exDarkMode') ?? false;
      mainWindow.setWindowLayoutFullScreen(true);
      mainWindow.setWindowSystemBarEnable(['status', 'navigation']);
      return mainWindow.setWindowSystemBarProperties({
        statusBarColor: darkMode ? '#18202A' : '#FFFFFF',
        navigationBarColor: darkMode ? '#0F141A' : '#F5F7FA',
        statusBarContentColor: darkMode ? '#F2F5F8' : '#202124',
        navigationBarContentColor: darkMode ? '#F2F5F8' : '#202124',
        isStatusBarLightIcon: !darkMode,
        isNavigationBarLightIcon: !darkMode
      });
    }).catch((barError: Error) => {
      hilog.warn(DOMAIN, 'testTag', 'Unable to configure immersive bars: %{public}s', JSON.stringify(barError));
    });

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      // Keep recently opened topics available immediately on the next visit;
      // the detail page refreshes these records in the background.
      PersistentStorage.persistProp('v2exTopicCache', '{}');
      PersistentStorage.persistProp('v2exRepliesCache', '{}');
      PersistentStorage.persistProp('v2exProfileCache', '{}');
      // Menu pages use cache-first rendering so reopening a page is instant
      // while the same page refreshes quietly in the background.
      PersistentStorage.persistProp('v2exMyNodesCache', '[]');
      PersistentStorage.persistProp('v2exFavoritesCache', '[]');
      PersistentStorage.persistProp('v2exNotificationsCache', '[]');
      PersistentStorage.persistProp('v2exFollowingCache', '[]');
      PersistentStorage.persistProp('v2exMyTopicsCache', '[]');
      PersistentStorage.persistProp('v2exRecentTopicsCache', '[]');
      PersistentStorage.persistProp('v2exHotestTopicsCache', '{}');
      PersistentStorage.persistProp('v2exNodesCache', '[]');
      PersistentStorage.persistProp('v2exNodeTopicsCache', '{}');
      AppStorage.setOrCreate('v2exSafeAreaTop', 0);
      AppStorage.setOrCreate('v2exSafeAreaBottom', 0);
      const uiContext = windowStage.getMainWindowSync().getUIContext();
      const updateSafeAreas = (): void => {
        try {
          const systemArea = windowStage.getMainWindowSync().getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
          AppStorage.setOrCreate('v2exSafeAreaTop', uiContext.px2vp(systemArea.topRect.height));
        } catch (_) { }
        try {
          const navigationArea = windowStage.getMainWindowSync().getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
          AppStorage.setOrCreate('v2exSafeAreaBottom', uiContext.px2vp(navigationArea.bottomRect.height));
        } catch (_) { }
      };
      updateSafeAreas();
      windowStage.getMainWindowSync().on('avoidAreaChange', (data) => {
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
          AppStorage.setOrCreate('v2exSafeAreaTop', uiContext.px2vp(data.area.topRect.height));
        } else if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          AppStorage.setOrCreate('v2exSafeAreaBottom', uiContext.px2vp(data.area.bottomRect.height));
        }
      });
      // Keep the native pages visually continuous with the web client: the
      // system bars use the same light surface instead of the platform black default.
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
