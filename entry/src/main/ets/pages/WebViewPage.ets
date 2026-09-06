import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct WebViewPage {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @State url: string = 'https://www.v2ex.com';
  @State title: string = '浏览器';
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    const value: string = String(params?.['url'] ?? 'https://www.v2ex.com');
    this.url = /^https?:\/\//i.test(value) ? value : 'https://www.v2ex.com';
    this.title = String(params?.['title'] ?? '浏览器');
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text(this.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.height(60).width('100%').backgroundColor(Color.White)
      Web({ src: this.url, controller: this.controller }).javaScriptAccess(true).domStorageAccess(true).layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
