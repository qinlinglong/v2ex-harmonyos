import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { V2exService } from '../service/V2exService';
import { applyThemeSystemBars, themeAccentText, themeBackground, themePrimaryText, themeSurface } from '../common/Theme';

@Entry
@Component
struct BilibiliLogin {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exSafeAreaTop') safeAreaTop: number = 0;
  @StorageLink('v2exSafeAreaBottom') safeAreaBottom: number = 0;
  @State status: string = '请在页面内登录 Bilibili';
  @State completed: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private timer: number = -1;

  aboutToAppear(): void { applyThemeSystemBars(this.darkMode); this.timer = setInterval(() => this.checkCookie(), 700); }
  aboutToDisappear(): void { if (this.timer >= 0) clearInterval(this.timer); }
  async checkCookie(): Promise<void> {
    if (this.completed || !V2exService.biliLoggedIn()) return;
    this.completed = true; this.status = 'Bilibili 登录成功';
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    try { await webview.WebCookieManager.saveCookieAsync(); } catch (_) { }
    setTimeout(() => router.back(), 500);
  }
  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(themeAccentText(this.themeColor, this.darkMode)).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('Bilibili 图床登录').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode)).margin({ left: 14 })
      }.height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      Text(this.status).fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode)).margin({ top: 8, bottom: 8 })
      Web({ src: 'https://passport.bilibili.com/login', controller: this.controller }).javaScriptAccess(true).domStorageAccess(true).fileAccess(true).databaseAccess(true).layoutWeight(1).width('100%').onPageEnd(() => this.checkCookie())
    }.width('100%').height('100%').padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom }).backgroundColor(themeBackground(this.darkMode))
  }
}
