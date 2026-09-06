import { router } from '@kit.ArkUI';
import { V2exReply } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';

@Entry
@Component
struct RelatedReplies {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @State replies: V2exReply[] = [];
  @State loading: boolean = true;
  @State relatedOnly: boolean = true;
  private topicId: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    this.topicId = Number(params?.['id'] ?? 0);
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    try { this.replies = await V2exService.replies(this.topicId); } finally { this.loading = false; }
  }

  private visibleReplies(): V2exReply[] {
    if (!this.relatedOnly) return this.replies;
    return this.replies.filter((reply: V2exReply) => reply.content.indexOf('@') >= 0 || reply.content.indexOf('回复') >= 0);
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('关联回复').fontSize(20).fontWeight(FontWeight.Bold)
        Blank()
        Text('↻').fontSize(24).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => this.load())
      }.height(60).width('100%').backgroundColor(Color.White)
      Row() {
        Text(this.relatedOnly ? '仅显示可能相关的回复' : '显示全部回复').fontSize(14).fontColor('#7B8794').layoutWeight(1)
        Button(this.relatedOnly ? '查看全部' : '仅看相关').fontSize(13).onClick(() => this.relatedOnly = !this.relatedOnly)
      }.width('100%').padding(16).backgroundColor(Color.White).margin({ top: 1 })
      if (this.loading) LoadingProgress().width(30).height(30).color(this.themeColor).margin({ top: 40 })
      else if (this.visibleReplies().length === 0) Text('没有检测到关联回复').fontSize(15).fontColor('#7B8794').margin({ top: 48 })
      else List({ space: 1 }) {
        ForEach(this.visibleReplies(), (reply: V2exReply, index: number) => ListItem() {
          Column() {
            Row() { Text(`${index + 1}. ${reply.member?.username ?? '匿名'}`).fontSize(14).fontColor(this.themeColor); Blank(); Text(`${reply.thanks ?? 0} 感谢`).fontSize(12).fontColor('#9AA0A6') }
            Text(reply.content).fontSize(15).fontColor('#30343B').lineHeight(23).margin({ top: 8 })
          }.width('100%').padding(16).backgroundColor(Color.White)
        }, (reply: V2exReply) => `${reply.id}`)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
