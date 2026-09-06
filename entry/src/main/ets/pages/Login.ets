import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct Login {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDomain') domain: string = 'https://www.v2ex.com';
  private controller: webview.WebviewController = new webview.WebviewController();
  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('登录 V2EX').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
      }.height(60).width('100%').backgroundColor(Color.White)
      Web({ src: `${this.domain.replace(/\/$/, '')}/signin`, controller: this.controller })
        .javaScriptAccess(true).domStorageAccess(true).layoutWeight(1).width('100%')
        .onPageEnd((event: OnPageEndEvent) => {
          if (event.url.indexOf(this.domain.replace(/^https?:\/\//, '').replace(/\/$/, '')) >= 0 && event.url.indexOf('/signin') < 0 &&
            event.url.indexOf('/recover') < 0) {
            setTimeout(() => router.back(), 300);
          }
        })
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
