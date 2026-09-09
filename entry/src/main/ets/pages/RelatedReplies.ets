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
    if (this.replies.length === 0) return [];
    // The H5 client treats a reply thread as a conversation between the
    // author of the selected reply and the people explicitly mentioned in it.
    // The old native filter matched any '@' anywhere, which mixed unrelated
    // conversations together. With no explicit mention, keep the full list.
    const anchor: V2exReply = this.replies.find((item: V2exReply) => /@[A-Za-z0-9_\-\u4e00-\u9fff]+/.test(item.content)) ?? this.replies[0];
    const names: string[] = (anchor.content.match(/@([A-Za-z0-9_\-\u4e00-\u9fff]+)/g) ?? [])
      .map((value: string) => value.substring(1).toLowerCase());
    if (names.length === 0) return this.replies;
    const anchorName: string = anchor.member?.username?.toLowerCase() ?? '';
    return this.replies.filter((reply: V2exReply) => {
      const author: string = reply.member?.username?.toLowerCase() ?? '';
      if (reply.id === anchor.id || names.indexOf(author) >= 0 || author === anchorName) return true;
      const mentions: string[] = (reply.content.match(/@([A-Za-z0-9_\-\u4e00-\u9fff]+)/g) ?? [])
        .map((value: string) => value.substring(1).toLowerCase());
      return mentions.indexOf(anchorName) >= 0 || mentions.some((name: string) => names.indexOf(name) >= 0);
    });
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('关联回复').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
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
            Row() { Text(reply.member?.username ?? '匿名').fontSize(14).fontColor(this.themeColor); Blank(); Text(`#${reply.no ?? index + 1}`).fontSize(12).fontColor('#9AA0A6').margin({ right: 12 }); Text(`${reply.thanks ?? 0} 感谢`).fontSize(12).fontColor('#9AA0A6') }
            Text(reply.content).fontSize(15).fontColor('#30343B').lineHeight(23).margin({ top: 8 })
          }.width('100%').padding(16).backgroundColor(Color.White)
        }, (reply: V2exReply) => `${reply.id}`)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
