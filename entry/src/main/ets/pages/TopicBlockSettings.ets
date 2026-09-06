import { router } from '@kit.ArkUI';

@Entry
@Component
struct TopicBlockSettings {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exBlockedKeywords') blockedJson: string = '[]';
  @State keyword: string = '';
  @State keywords: string[] = [];
  @State status: string = '';

  aboutToAppear(): void {
    try { this.keywords = JSON.parse(this.blockedJson) as string[]; } catch (_) { this.keywords = []; }
  }

  private persist(): void { this.blockedJson = JSON.stringify(this.keywords); }

  private add(): void {
    const value: string = this.keyword.trim();
    if (value.length === 0 || this.keywords.indexOf(value) >= 0) return;
    this.keywords = this.keywords.concat([value]);
    this.keyword = '';
    this.persist();
    this.status = '屏蔽规则已保存';
  }

  private remove(value: string): void {
    this.keywords = this.keywords.filter((item: string) => item !== value);
    this.persist();
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('主题屏蔽').fontSize(20).fontWeight(FontWeight.Bold)
      }.height(60).width('100%').backgroundColor(Color.White)
      Scroll() {
        Column() {
          Text('屏蔽标题或正文中包含关键词的主题').fontSize(14).fontColor('#7B8794').width('100%').margin({ bottom: 14 })
          Row() {
            TextInput({ placeholder: '输入关键词', text: this.keyword }).layoutWeight(1).height(46).fontSize(15)
              .onChange((value: string) => this.keyword = value).onSubmit(() => this.add())
            Button('添加').fontSize(14).margin({ left: 10 }).onClick(() => this.add())
          }.width('100%')
          if (this.status.length > 0) Text(this.status).fontSize(13).fontColor(this.themeColor).margin({ top: 12 })
          ForEach(this.keywords, (value: string) => Row() {
            Text(value).fontSize(15).fontColor('#202124').layoutWeight(1)
            Text('删除').fontSize(13).fontColor('#C05A73').onClick(() => this.remove(value))
          }.width('100%').padding(16).backgroundColor(Color.White).margin({ top: 1 }), (value: string) => value)
          if (this.keywords.length === 0) Text('暂无屏蔽规则').fontSize(14).fontColor('#8A97A6').margin({ top: 36 })
        }.width('100%').padding(18)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
