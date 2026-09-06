import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct MyNodes {
  private controller: webview.WebviewController = new webview.WebviewController();
  build() {
    Column() {
      Row() { Text('‹').fontSize(34).fontColor('#4F7CAC').width(42).textAlign(TextAlign.Center).onClick(() => router.back()); Text('我的节点').fontSize(20).fontWeight(FontWeight.Bold) }
        .height(60).width('100%').backgroundColor(Color.White)
      Web({ src: 'https://www.v2ex.com/my/nodes', controller: this.controller }).javaScriptAccess(true).domStorageAccess(true).layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
