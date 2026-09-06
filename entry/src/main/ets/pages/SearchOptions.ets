import { router } from '@kit.ArkUI';

@Entry
@Component
struct SearchOptions {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exSearchMode') mode: string = 'topic';
  build() {
    Column() {
      Row() { Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back()); Text('搜索选项').fontSize(20).fontWeight(FontWeight.Bold) }
        .height(60).width('100%').backgroundColor(Color.White)
      Column() {
        Text('默认搜索类型').fontSize(17).fontWeight(FontWeight.Medium).width('100%').margin({ bottom: 14 })
        Row() { Text('主题和正文').layoutWeight(1); Button(this.mode === 'topic' ? '已选择' : '选择').fontSize(13).onClick(() => this.mode = 'topic') }.width('100%').padding(18).backgroundColor(Color.White)
        Row() { Text('用户').layoutWeight(1); Button(this.mode === 'member' ? '已选择' : '选择').fontSize(13).onClick(() => this.mode = 'member') }.width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
        Row() { Text('节点').layoutWeight(1); Button(this.mode === 'node' ? '已选择' : '选择').fontSize(13).onClick(() => this.mode = 'node') }.width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
      }.width('100%').padding(18)
      Blank()
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
