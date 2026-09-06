import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { V2exReply, V2exTopic } from '../model/V2exModels';

interface DetailPart { kind: string; value: string; }

function detailParts(markdown: string): DetailPart[] {
  const parts: DetailPart[] = [];
  const pattern: RegExp = /!\[[^\]]*\]\((https?:\/\/[^)\s]+)\)/gi;
  let cursor: number = 0;
  let match: RegExpExecArray | null = pattern.exec(markdown);
  while (match !== null) {
    const before: string = markdown.substring(cursor, match.index).trim();
    if (before.length > 0) parts.push({ kind: 'text', value: before });
    parts.push({ kind: 'image', value: match[1] });
    cursor = match.index + match[0].length;
    match = pattern.exec(markdown);
  }
  const tail: string = markdown.substring(cursor).trim();
  if (tail.length > 0) parts.push({ kind: 'text', value: tail });
  if (parts.length === 0 && markdown.trim().length > 0) parts.push({ kind: 'text', value: markdown.trim() });
  return parts;
}

@Entry
@Component
struct TopicDetail {
  @StorageLink('v2exRecentTopicIds') recentJson: string = '[]';
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
  @State thankedReplies: number[] = [];
  @State editingReplyId: number = 0;
  @State editingReplyText: string = '';
  @State editingReplyStatus: string = '';
  @State appendOpen: boolean = false;
  @State appendText: string = '';
  @State appendStatus: string = '';
  private topicId: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    this.topicId = Number(params?.['id'] ?? 0);
    this.rememberRecentTopic();
    this.load();
  }

  private rememberRecentTopic(): void {
    try {
      const ids: number[] = JSON.parse(this.recentJson) as number[];
      const next: number[] = [this.topicId].concat(ids.filter((id: number) => id !== this.topicId)).slice(0, 30);
      this.recentJson = JSON.stringify(next);
    } catch (_) { this.recentJson = JSON.stringify([this.topicId]); }
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

  private async thankReply(replyId: number): Promise<void> {
    if (this.thankedReplies.indexOf(replyId) >= 0) return;
    try {
      const ok: boolean = await V2exService.replyAction(this.topicId, replyId, 'thank');
      if (ok) this.thankedReplies = this.thankedReplies.concat([replyId]);
      else this.replyStatus = '请先登录';
    } catch (_) { this.replyStatus = '操作失败'; }
  }

  private beginEditReply(reply: V2exReply): void {
    this.editingReplyId = reply.id;
    this.editingReplyText = reply.content;
    this.editingReplyStatus = '';
  }

  private async saveReplyEdit(): Promise<void> {
    if (this.editingReplyId <= 0 || this.editingReplyText.trim().length === 0) return;
    this.editingReplyStatus = '保存中…';
    const id: number = this.editingReplyId;
    const content: string = this.editingReplyText.trim();
    try {
      const ok: boolean = await V2exService.editReply(id, content);
      if (!ok) { this.editingReplyStatus = '保存失败，请确认登录状态'; return; }
      this.replies = this.replies.map((item: V2exReply) => {
        if (item.id !== id) return item;
        return { id: item.id, content, created: item.created, member: item.member, thanks: item.thanks, thanked: item.thanked } as V2exReply;
      });
      this.editingReplyId = 0;
      this.editingReplyText = '';
      this.editingReplyStatus = '保存成功';
      this.replyStatus = '评论已更新';
    } catch (_) { this.editingReplyStatus = '保存失败，请稍后重试'; }
  }

  private async submitAppend(): Promise<void> {
    if (this.appendText.trim().length === 0) return;
    this.appendStatus = '保存中…';
    try {
      const ok: boolean = await V2exService.appendTopic(this.topicId, this.appendText.trim());
      if (!ok) { this.appendStatus = '保存失败，请确认登录状态'; return; }
      if (this.topic) this.topic = {
        id: this.topic.id, title: this.topic.title, content: `${this.topic.content}\n\n${this.appendText.trim()}`,
        replies: this.topic.replies, last_modified: this.topic.last_modified, last_touched: this.topic.last_touched,
        node: this.topic.node, member: this.topic.member, url: this.topic.url
      } as V2exTopic;
      this.appendText = '';
      this.appendStatus = '追加成功';
    } catch (_) { this.appendStatus = '保存失败，请稍后重试'; }
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
              Row() {
                Text(this.topic.node?.title ?? 'V2EX').fontSize(13).fontColor('#7B8794')
                Text(' · ').fontSize(13).fontColor('#7B8794')
                Text(this.topic.member?.username ?? '匿名').fontSize(13).fontColor('#4F7CAC')
                  .onClick(() => { if (this.topic?.member?.username) router.pushUrl({ url: 'pages/Profile', params: { username: this.topic.member.username } }); })
                Text(` · ${this.topic.replies} 条回复`).fontSize(13).fontColor('#7B8794')
              }.margin({ top: 10 })
              Row() {
                Button(this.favorited ? '★ 已收藏' : '☆ 收藏').layoutWeight(1).onClick(() => this.action('favorite'))
                Button(this.thanked ? '♥ 已感谢' : '♥ 感谢').layoutWeight(1).margin({ left: 8 }).onClick(() => this.action('thank'))
                Button('▲ 赞').layoutWeight(1).margin({ left: 8 }).onClick(() => this.action('up'))
              }.width('100%').margin({ top: 16 })
              Button('编辑主题').fontSize(13).fontColor('#4F7CAC').backgroundColor(Color.Transparent)
                .margin({ top: 4 }).onClick(() => router.pushUrl({ url: 'pages/WriteTopic', params: { topicId: this.topicId } }))
              Button(this.appendOpen ? '收起追加' : '追加内容').fontSize(13).fontColor('#4F7CAC').backgroundColor(Color.Transparent)
                .margin({ top: 4 }).onClick(() => this.appendOpen = !this.appendOpen)
              if (this.appendOpen) {
                TextArea({ placeholder: '追加内容', text: this.appendText }).width('100%').height(110).fontSize(15)
                  .onChange((value: string) => this.appendText = value)
                Row() {
                  if (this.appendStatus.length > 0) Text(this.appendStatus).fontSize(12).fontColor('#4F7CAC')
                  Blank()
                  Button('保存追加').fontSize(13).onClick(() => this.submitAppend())
                }.width('100%').margin({ top: 8 })
              }
              if (this.actionStatus.length > 0) Text(this.actionStatus).fontSize(12).fontColor('#4F7CAC').margin({ top: 8 })
              ForEach(detailParts(this.topic.content || '（无正文）'), (part: DetailPart) => {
                if (part.kind === 'image') {
                  Image(part.value).width('100%').constraintSize({ maxHeight: 520 }).objectFit(ImageFit.Contain)
                    .margin({ top: 14, bottom: 4 })
                } else {
                  Text(part.value).fontSize(16).fontColor('#30343B').lineHeight(26).margin({ top: 20 }).textAlign(TextAlign.Start)
                }
              }, (part: DetailPart, index: number) => `${part.kind}-${index}-${part.value.substring(0, 12)}`)
            }.width('100%').padding(20).backgroundColor(Color.White)
            Text(`回复（${this.replies.length}）`).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#202124')
              .width('100%').padding({ left: 18, top: 20, bottom: 12 })
            ForEach(this.replies, (reply: V2exReply, index: number) => {
              Column() {
                Row() {
                  Stack() {
                    Text((reply.member?.username ?? '?').substring(0, 1).toUpperCase()).fontSize(12).fontColor(Color.White)
                      .width(28).height(28).textAlign(TextAlign.Center).backgroundColor('#B7C4D2').borderRadius(14)
                    if (reply.member?.avatar_large) Image(reply.member.avatar_large).width(28).height(28).borderRadius(14).objectFit(ImageFit.Cover)
                  }.onClick(() => { if (reply.member?.username) router.pushUrl({ url: 'pages/Profile', params: { username: reply.member.username } }); })
                  Text(`${index + 1}. ${reply.member?.username ?? '匿名'}`).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#4F7CAC')
                    .onClick(() => {
                      if (reply.member?.username) this.replyText = `@${reply.member.username} `;
                    })
                  Blank()
                  Text(new Date(reply.created * 1000).toLocaleDateString()).fontSize(12).fontColor('#9AA0A6')
                }
                if (this.editingReplyId === reply.id) {
                  TextArea({ placeholder: '编辑回复', text: this.editingReplyText }).width('100%').height(130).fontSize(15)
                    .onChange((value: string) => this.editingReplyText = value)
                  Row() {
                    if (this.editingReplyStatus.length > 0) Text(this.editingReplyStatus).fontSize(12).fontColor('#4F7CAC')
                    Blank()
                    Text('取消').fontSize(13).fontColor('#7B8794').margin({ right: 16 }).onClick(() => this.editingReplyId = 0)
                    Button('保存').fontSize(13).onClick(() => this.saveReplyEdit())
                  }.width('100%').margin({ top: 8 })
                } else {
                  Text(reply.content).fontSize(15).fontColor('#30343B').lineHeight(23).margin({ top: 8 })
                  Row() {
                    Text(this.thankedReplies.indexOf(reply.id) >= 0 ? '♥ 已感谢' : '♡ 感谢')
                      .fontSize(13).fontColor('#4F7CAC').onClick(() => this.thankReply(reply.id))
                    Blank()
                    Text('编辑').fontSize(13).fontColor('#7B8794').onClick(() => this.beginEditReply(reply))
                  }.width('100%').margin({ top: 10 })
                }
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
