import { router } from '@kit.ArkUI';
import { themeBackground, themeBodyText, themeMutedText, themePrimaryText, themeSurface } from '../common/Theme';

@Entry
@Component
struct GitHubMD {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('Markdown 帮助').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
      }.height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      Scroll() {
        Column() {
          Text('编辑格式').fontSize(19).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode)).width('100%')
          Text('V2EX 使用 Markdown 编写主题和回复。下面的示例可以直接复制使用。')
            .fontSize(15).fontColor(themeBodyText(this.darkMode)).lineHeight(24).width('100%').margin({ top: 12 })
          Text('**粗体文字**\n*斜体文字*\n`行内代码`\n\n- 无序列表\n1. 有序列表\n\n[链接文字](https://www.v2ex.com)\n\n![图片描述](https://example.com/image.png)')
            .fontSize(16).fontColor(themeBodyText(this.darkMode)).lineHeight(29).width('100%').padding(16).backgroundColor(themeSurface(this.darkMode)).margin({ top: 20 })
          Text('提示：链接会在内置浏览器或系统浏览器中打开；图片地址会在预览和详情中显示。')
            .fontSize(13).fontColor(themeMutedText(this.darkMode)).lineHeight(21).width('100%').margin({ top: 18 })
        }.width('100%').padding(20)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
