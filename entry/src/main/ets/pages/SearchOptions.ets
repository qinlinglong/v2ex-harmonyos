import { router } from '@kit.ArkUI';
import { themeBackground, themeInputBackground, themeMutedText, themePrimaryText, themeSurface, themeOnColor } from '../common/Theme';

@Entry
@Component
struct SearchOptions {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exSearchMode') mode: string = 'topic';
  @StorageLink('v2exSearchSort') sort: string = 'created';
  @StorageLink('v2exSearchOrder') order: string = '0';
  @StorageLink('v2exSearchGte') gte: string = '';
  @StorageLink('v2exSearchLte') lte: string = '';
  @StorageLink('v2exSearchSource') source: string = 'sov2ex';
  build() {
    Column() {
      Row() { Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back()); Text('搜索选项').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode)) }
        .height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      Scroll() {
        Column() {
          Text('默认搜索类型').fontSize(17).fontWeight(FontWeight.Medium).fontColor(themePrimaryText(this.darkMode)).width('100%').margin({ bottom: 14 })
        Row() { Text('主题和正文').fontColor(themePrimaryText(this.darkMode)).layoutWeight(1); Button(this.mode === 'topic' ? '已选择' : '选择').fontSize(13).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.mode = 'topic') }.width('100%').padding(18).backgroundColor(themeSurface(this.darkMode))
        Row() { Text('用户').fontColor(themePrimaryText(this.darkMode)).layoutWeight(1); Button(this.mode === 'member' ? '已选择' : '选择').fontSize(13).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.mode = 'member') }.width('100%').padding(18).backgroundColor(themeSurface(this.darkMode)).margin({ top: 1 })
        Row() { Text('节点').fontColor(themePrimaryText(this.darkMode)).layoutWeight(1); Button(this.mode === 'node' ? '已选择' : '选择').fontSize(13).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.mode = 'node') }.width('100%').padding(18).backgroundColor(themeSurface(this.darkMode)).margin({ top: 1 })
        Text('查询结果排序').fontSize(17).fontWeight(FontWeight.Medium).fontColor(themePrimaryText(this.darkMode)).width('100%').margin({ top: 22, bottom: 14 })
        Row() { Text('按时间').fontColor(themePrimaryText(this.darkMode)).layoutWeight(1); Button(this.sort === 'created' ? '已选择' : '选择').fontSize(13).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.sort = 'created') }
          .width('100%').padding(18).backgroundColor(themeSurface(this.darkMode))
        Row() { Text('按相关性').fontColor(themePrimaryText(this.darkMode)).layoutWeight(1); Button(this.sort === 'sumup' ? '已选择' : '选择').fontSize(13).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.sort = 'sumup') }
          .width('100%').padding(18).backgroundColor(themeSurface(this.darkMode)).margin({ top: 1 })
        if (this.sort === 'created') {
          Row() { Text('时间顺序').fontColor(themePrimaryText(this.darkMode)).layoutWeight(1); Button(this.order === '0' ? '新→旧' : '旧→新').fontSize(13).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.order = this.order === '0' ? '1' : '0') }
            .width('100%').padding(18).backgroundColor(themeSurface(this.darkMode)).margin({ top: 1 })
        }
        Text('发帖日期范围（可选）').fontSize(17).fontWeight(FontWeight.Medium).fontColor(themePrimaryText(this.darkMode)).width('100%').margin({ top: 22, bottom: 14 })
        TextInput({ placeholder: '起始日期 YYYY-MM-DD', text: this.gte }).width('100%').height(46).fontColor(themePrimaryText(this.darkMode)).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode))
          .onChange((value: string) => this.gte = value)
        TextInput({ placeholder: '结束日期 YYYY-MM-DD', text: this.lte }).width('100%').height(46).fontColor(themePrimaryText(this.darkMode)).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode))
          .margin({ top: 1 }).onChange((value: string) => this.lte = value)
        Text('搜索服务').fontSize(17).fontWeight(FontWeight.Medium).fontColor(themePrimaryText(this.darkMode)).width('100%').margin({ top: 22, bottom: 14 })
        Row() { Text('Sov2ex').fontColor(themePrimaryText(this.darkMode)).layoutWeight(1); Button(this.source === 'sov2ex' ? '已选择' : '选择').fontSize(13).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.source = 'sov2ex') }
          .width('100%').padding(18).backgroundColor(themeSurface(this.darkMode))
        Row() { Text('Google').fontColor(themePrimaryText(this.darkMode)).layoutWeight(1); Button(this.source === 'google' ? '已选择' : '选择').fontSize(13).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.source = 'google') }
          .width('100%').padding(18).backgroundColor(themeSurface(this.darkMode)).margin({ top: 1 })
        }.width('100%').padding(18)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
