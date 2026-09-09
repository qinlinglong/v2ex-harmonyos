import { router } from '@kit.ArkUI';
import { themeBackground, themePrimaryText, themeSurface } from '../common/Theme';

@Entry
@Component
struct SortTabs {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exTopicSort') sort: string = 'default';
  build() {
    Column() {
      Row() { Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back()); Text('回复排序').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode)) }.height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      Column() {
        Row() { Text('默认排序').fontColor(themePrimaryText(this.darkMode)).layoutWeight(1); Button(this.sort === 'default' ? '已选择' : '选择').fontSize(13).backgroundColor(this.themeColor).fontColor(Color.White).onClick(() => this.sort = 'default') }.width('100%').padding(18).backgroundColor(themeSurface(this.darkMode))
        Row() { Text('最新回复在前').fontColor(themePrimaryText(this.darkMode)).layoutWeight(1); Button(this.sort === 'latest' ? '已选择' : '选择').fontSize(13).backgroundColor(this.themeColor).fontColor(Color.White).onClick(() => this.sort = 'latest') }.width('100%').padding(18).backgroundColor(themeSurface(this.darkMode)).margin({ top: 1 })
      }.width('100%').padding(18)
      Blank()
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
