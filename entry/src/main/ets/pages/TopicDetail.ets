import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { V2exReply, V2exTopic } from '../model/V2exModels';

@Entry
@Component
struct TopicDetail {
  @State topic: V2exTopic | undefined = undefined;
  @State replies: V2exReply[] = [];
  @State loading: boolean = true;
  @State errorText: string = '';
  @State replyText: string = '';
  @State replyStatus: string = '';
  @State replying: boolean = false;
  @State favorited: boolean = false;
  @State thanked: boolean = false;
  @State actionStatus: string = '';
  private topicId: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    this.topicId = Number(params?.['id'] ?? 0);
    this.load();
  }

  private async load(): Promise<void> {
    try {
      this.topic = await V2exService.topic(this.topicId);
      this.replies = await V2exService.replies(this.topicId);
    } catch (_) { this.errorText = '主题加载失败，请稍后重试'; }
    finally { this.loading = false; }
  }

  private async submitReply(): Promise<void> {
    if (this.replyText.trim().length === 0 || this.replying) return;
    this.replying = true; this.replyStatus = '发送中…';
    try {
      const ok: boolean = await V2exService.reply(this.topicId, this.replyText.trim());
      if (ok) { this.replyText = ''; this.replyStatus = '回复成功'; await this.load(); }
      else this.replyStatus = '回复失败，请先登录';
    } catch (_) { this.replyStatus = '回复失败，请先登录'; }
    finally { this.replying = false; }
  }

  private async action(kind: 'favorite' | 'thank' | 'up'): Promise<void> {
    this.actionStatus = '处理中…';
    const action = kind === 'favorite' ? (this.favorited ? 'unfavorite' : 'favorite') : kind;
    try {
      const ok: boolean = await V2exService.topicAction(this.topicId, action);
      if (ok) {
        if (kind === 'favorite') this.favorited = !this.favorited;
        if (kind === 'thank') this.thanked = true;
        this.actionStatus = kind === 'favorite' ? (this.favorited ? '已收藏' : '已取消收藏') : '已完成';
      } else this.actionStatus = '请先登录';
    } catch (_) { this.actionStatus = '操作失败'; }
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor('#4F7CAC').width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text(this.topic?.title ?? '主题详情').fontSize(19).fontWeight(FontWeight.Bold).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        Text('↻').fontSize(24).fontColor('#4F7CAC').width(42).textAlign(TextAlign.Center)
          .onClick(() => { this.loading = true; this.load(); })
      }.height(60).width('100%').padding({ right: 8 }).backgroundColor(Color.White)
      if (this.loading) {
        LoadingProgress().width(30).height(30).color('#4F7CAC').margin({ top: 32 })
      } else if (this.errorText.length > 0) {
        Text(this.errorText).fontSize(15).fontColor('#7B8794').margin({ top: 40 })
      } else if (this.topic) {
        Scroll() {
          Column() {
            Column() {
              Text(this.topic.title).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#202124')
              Text(`${this.topic.node?.title ?? 'V2EX'} · ${this.topic.member?.username ?? '匿名'} · ${this.topic.replies} 条回复`)
                .fontSize(13).fontColor('#7B8794').margin({ top: 10 })
              Row() {
                Button(this.favorited ? '★ 已收藏' : '☆ 收藏').layoutWeight(1).onClick(() => this.action('favorite'))
                Button(this.thanked ? '♥ 已感谢' : '♥ 感谢').layoutWeight(1).margin({ left: 8 }).onClick(() => this.action('thank'))
                Button('▲ 赞').layoutWeight(1).margin({ left: 8 }).onClick(() => this.action('up'))
              }.width('100%').margin({ top: 16 })
              if (this.actionStatus.length > 0) Text(this.actionStatus).fontSize(12).fontColor('#4F7CAC').margin({ top: 8 })
              Text(this.topic.content || '（无正文）').fontSize(16).fontColor('#30343B').lineHeight(26)
                .margin({ top: 20 }).textAlign(TextAlign.Start)
            }.width('100%').padding(20).backgroundColor(Color.White)
            Text(`回复（${this.replies.length}）`).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#202124')
              .width('100%').padding({ left: 18, top: 20, bottom: 12 })
            ForEach(this.replies, (reply: V2exReply, index: number) => {
              Column() {
                Row() {
                  Text(`${index + 1}. ${reply.member?.username ?? '匿名'}`).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#4F7CAC')
                  Blank()
                  Text(new Date(reply.created * 1000).toLocaleDateString()).fontSize(12).fontColor('#9AA0A6')
                }
                Text(reply.content).fontSize(15).fontColor('#30343B').lineHeight(23).margin({ top: 8 })
              }.width('100%').padding(16).backgroundColor(Color.White).margin({ bottom: 1 })
            }, (reply: V2exReply) => `${reply.id}`)
            Column() {
              TextArea({ placeholder: '写下你的回复…', text: this.replyText }).width('100%').height(120).fontSize(15)
                .onChange((value: string) => this.replyText = value)
              Row() {
                if (this.replyStatus.length > 0) Text(this.replyStatus).fontSize(13).fontColor('#4F7CAC')
                Blank()
                Button(this.replying ? '发送中' : '回复').onClick(() => this.submitReply())
              }.width('100%').margin({ top: 10 })
            }.width('100%').padding(16).backgroundColor(Color.White).margin({ top: 10, bottom: 20 })
          }.width('100%')
        }.layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
