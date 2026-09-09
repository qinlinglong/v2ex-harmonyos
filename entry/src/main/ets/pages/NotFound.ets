import { router } from '@kit.ArkUI';
import { themeBackground, themePrimaryText, themeSurface, themeOnColor } from '../common/Theme';

@Entry
@Component
struct NotFound {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @State message: string = '页面不存在';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    const value: string = String(params?.['message'] ?? '页面不存在');
    if (value.trim().length > 0) this.message = value;
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(46).textAlign(TextAlign.Center)
          .onClick(() => router.back())
        Text('V2EX').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
      }.height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      Blank().layoutWeight(1)
      Text('404').fontSize(56).fontWeight(FontWeight.Bold).fontColor(this.themeColor)
      Text(this.message).fontSize(16).fontColor(themePrimaryText(this.darkMode)).margin({ top: 12 })
      Button('返回首页').fontSize(15).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor))
        .margin({ top: 24 }).onClick(() => router.replaceUrl({ url: 'pages/Index' }))
      Blank().layoutWeight(1)
    }.width('100%').height('100%')
      .padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 })
      .backgroundColor(themeBackground(this.darkMode))
  }
}
