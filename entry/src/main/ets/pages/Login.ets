import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct Login {
  @StorageLink('v2exDomain') domain: string = 'https://www.v2ex.com';
  private controller: webview.WebviewController = new webview.WebviewController();
  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor('#4F7CAC').width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('登录 V2EX').fontSize(20).fontWeight(FontWeight.Bold)
      }.height(60).width('100%').backgroundColor(Color.White)
      Web({ src: `${this.domain.replace(/\/$/, '')}/signin`, controller: this.controller })
        .javaScriptAccess(true).domStorageAccess(true).layoutWeight(1).width('100%')
        .onPageEnd((event: OnPageEndEvent) => {
          if (event.url.indexOf(this.domain.replace(/^https?:\/\//, '').replace(/\/$/, '')) >= 0 && event.url.indexOf('/signin') < 0 &&
            event.url.indexOf('/recover') < 0) {
            setTimeout(() => router.back(), 300);
          }
        })
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
