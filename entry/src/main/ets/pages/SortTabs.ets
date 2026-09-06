import { router } from '@kit.ArkUI';

@Entry
@Component
struct SortTabs {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exTopicSort') sort: string = 'default';
  build() {
    Column() {
      Row() { Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back()); Text('回复排序').fontSize(20).fontWeight(FontWeight.Bold) }.height(60).width('100%').backgroundColor(Color.White)
      Column() {
        Row() { Text('默认排序').layoutWeight(1); Button(this.sort === 'default' ? '已选择' : '选择').fontSize(13).onClick(() => this.sort = 'default') }.width('100%').padding(18).backgroundColor(Color.White)
        Row() { Text('最新回复在前').layoutWeight(1); Button(this.sort === 'latest' ? '已选择' : '选择').fontSize(13).onClick(() => this.sort = 'latest') }.width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
      }.width('100%').padding(18)
      Blank()
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
