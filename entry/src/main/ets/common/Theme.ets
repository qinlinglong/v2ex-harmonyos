import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

/** Keep system bars continuous with every native page and the current theme. */
export function applyThemeSystemBars(darkMode: boolean): void {
  try {
    const context = getContext() as common.UIAbilityContext;
    context.windowStage.getMainWindow().then((mainWindow: window.Window) => {
      // The status area belongs to the top app bar; keep it the same color as
      // every page header so there is no seam below the system clock.
      const surface: string = darkMode ? '#18202A' : '#FFFFFF';
      const canvas: string = darkMode ? '#0F141A' : '#F5F7FA';
      const content: string = darkMode ? '#F2F5F8' : '#202124';
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: surface,
        navigationBarColor: canvas,
        statusBarContentColor: content,
        navigationBarContentColor: content,
        isStatusBarLightIcon: !darkMode,
        isNavigationBarLightIcon: !darkMode
      });
    });
  } catch (_) { /* system bars are best effort on older devices */ }
}

export function themeSurface(darkMode: boolean): string {
  return darkMode ? '#18202A' : '#FFFFFF';
}

export function themeBackground(darkMode: boolean): string {
  return darkMode ? '#0F141A' : '#F5F7FA';
}

export function themePrimaryText(darkMode: boolean): string {
  return darkMode ? '#F2F5F8' : '#202124';
}

export function themeBodyText(darkMode: boolean): string {
  return darkMode ? '#D4DCE5' : '#30343B';
}

export function themeInputBackground(darkMode: boolean): string {
  return darkMode ? '#26313D' : '#F1F4F7';
}

export function themeSecondaryText(darkMode: boolean): string {
  return darkMode ? '#AAB7C4' : '#7B8794';
}

export function themeMutedText(darkMode: boolean): string {
  return darkMode ? '#94A3B2' : '#8A97A6';
}

export function themeAvatarBackground(darkMode: boolean): string {
  return darkMode ? '#435466' : '#B7C4D2';
}

/** Pick readable foreground text for a user-selected accent color. */
export function themeOnColor(color: string): string {
  const value: string = color.trim().replace(/^#/, '');
  if (!/^[0-9A-Fa-f]{6}$/.test(value)) return '#FFFFFF';
  const red: number = Number.parseInt(value.substring(0, 2), 16);
  const green: number = Number.parseInt(value.substring(2, 4), 16);
  const blue: number = Number.parseInt(value.substring(4, 6), 16);
  const brightness: number = (red * 299 + green * 587 + blue * 114) / 1000;
  return brightness >= 165 ? '#202124' : '#FFFFFF';
}

/** Keep accent labels and icons readable against the current page surface. */
export function themeAccentText(color: string, darkMode: boolean): string {
  const value: string = color.trim().replace(/^#/, '');
  if (!/^[0-9A-Fa-f]{6}$/.test(value)) return darkMode ? '#F2F5F8' : '#202124';
  const red: number = Number.parseInt(value.substring(0, 2), 16);
  const green: number = Number.parseInt(value.substring(2, 4), 16);
  const blue: number = Number.parseInt(value.substring(4, 6), 16);
  const brightness: number = (red * 299 + green * 587 + blue * 114) / 1000;
  if (!darkMode && brightness >= 165) return '#202124';
  if (darkMode && brightness < 80) return '#F2F5F8';
  return color;
}
