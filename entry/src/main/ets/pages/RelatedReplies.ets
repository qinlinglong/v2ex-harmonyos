import { router } from '@kit.ArkUI';
import { V2exReply } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';

interface ReplyReference {
  username: string;
  replyNo?: number;
}

function replyReferences(value: string): ReplyReference[] {
  const references: ReplyReference[] = [];
  const seen: Set<string> = new Set<string>();
  const add = (username: string, noText: string | undefined): void => {
    const name: string = username.trim();
    if (name.length === 0) return;
    const replyNo: number | undefined = noText ? Number(noText) : undefined;
    const key: string = `${name.toLowerCase()}:${replyNo ?? ''}`;
    if (seen.has(key)) return;
    seen.add(key);
    references.push({ username: name, replyNo });
  };
  const htmlPattern: RegExp = /@<a\s+href=["']\/member\/([^"']+)["'][^>]*>[\s\S]*?<\/a>\s*(?:#(\d+))?/gi;
  let match: RegExpExecArray | null = htmlPattern.exec(value);
  while (match !== null) {
    add(match[1], match[2]);
    match = htmlPattern.exec(value);
  }
  const plain: string = value.replace(/<[^>]*>/g, ' ');
  const textPattern: RegExp = /@([A-Za-z0-9_\-\u4e00-\u9fff]+)\s*(?:#(\d+))?/g;
  match = textPattern.exec(plain);
  while (match !== null) {
    add(match[1], match[2]);
    match = textPattern.exec(plain);
  }
  return references;
}

@Entry
@Component
struct RelatedReplies {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @State replies: V2exReply[] = [];
  @State loading: boolean = true;
  @State relatedOnly: boolean = true;
  private topicId: number = 0;
  private anchorReplyId: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    this.topicId = Number(params?.['topicId'] ?? params?.['id'] ?? 0);
    this.anchorReplyId = Number(params?.['replyId'] ?? 0);
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    try { this.replies = await V2exService.replies(this.topicId); } finally { this.loading = false; }
  }

  private visibleReplies(): V2exReply[] {
    if (!this.relatedOnly) return this.replies;
    if (this.replies.length === 0) return [];
    const anchor: V2exReply = this.replies.find((item: V2exReply) => item.id === this.anchorReplyId) ?? this.replies[0];
    const references: ReplyReference[] = replyReferences(anchor.content);
    const anchorName: string = anchor.member?.username?.toLowerCase() ?? '';
    const names: Set<string> = new Set<string>(references.map((item: ReplyReference) => item.username.toLowerCase()));
    if (anchorName.length === 0 || names.size === 0) return [anchor];
    const participants: Set<string> = new Set<string>([anchorName]);
    names.forEach((name: string) => participants.add(name));
    const byNo: Map<number, V2exReply> = new Map<number, V2exReply>();
    this.replies.forEach((item: V2exReply, index: number) => byNo.set(item.no ?? index + 1, item));
    return this.replies.filter((reply: V2exReply) => {
      const author: string = reply.member?.username?.toLowerCase() ?? '';
      if (reply.id === anchor.id || !participants.has(author)) return reply.id === anchor.id;
      const replyRefs: ReplyReference[] = replyReferences(reply.content);
      const explicit: ReplyReference[] = replyRefs.filter((item: ReplyReference) => item.replyNo !== undefined);
      if (explicit.length > 0) {
        const exact: ReplyReference[] = explicit.filter((item: ReplyReference) => {
          const target: V2exReply | undefined = byNo.get(item.replyNo as number);
          return target?.member?.username?.toLowerCase() === item.username.toLowerCase();
        });
        if (exact.length > 0) return exact.some((item: ReplyReference) => participants.has(byNo.get(item.replyNo as number)?.member?.username?.toLowerCase() ?? ''));
      }
      const mentioned: Set<string> = new Set<string>(replyRefs.map((item: ReplyReference) => item.username.toLowerCase()));
      return mentioned.size === 0 || mentioned.has(anchorName) || mentioned.has(author);
    });
  }

  private replyTo(reply: V2exReply): void {
    const username: string = reply.member?.username ?? '';
    if (username.length === 0) return;
    const floor: number = reply.no ?? 0;
    AppStorage.set<string>('v2exReplyMention', `@${username}${floor > 0 ? ` #${floor}` : ''}`);
    router.back();
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('评论回复').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
      }.height(60).width('100%').backgroundColor(Color.White)
      Row() {
        Text(this.relatedOnly ? '仅显示当前回复关联的评论' : '显示全部回复').fontSize(14).fontColor('#7B8794').layoutWeight(1)
        Button(this.relatedOnly ? '查看全部' : '仅看相关').fontSize(13).onClick(() => this.relatedOnly = !this.relatedOnly)
      }.width('100%').padding(16).backgroundColor(Color.White).margin({ top: 1 })
      if (this.loading) LoadingProgress().width(30).height(30).color(this.themeColor).margin({ top: 40 })
      else if (this.visibleReplies().length === 0) Text('没有检测到关联回复').fontSize(15).fontColor('#7B8794').margin({ top: 48 })
      else List({ space: 1 }) {
        ForEach(this.visibleReplies(), (reply: V2exReply, index: number) => ListItem() {
          Column() {
            Row() {
              Text(reply.member?.username ?? '匿名').fontSize(14).fontColor(this.themeColor)
              Blank()
              Text(`#${reply.no ?? index + 1}`).fontSize(12).fontColor('#9AA0A6').margin({ right: 12 })
              if (reply.createdLabel && reply.createdLabel.length > 0) Text(reply.createdLabel).fontSize(12).fontColor('#9AA0A6')
              if ((reply.thanks ?? 0) > 0) Text(`${reply.thanks} 感谢`).fontSize(12).fontColor('#9AA0A6').margin({ left: 8 })
            }.width('100%')
            Text(reply.content).fontSize(15).fontColor('#30343B').lineHeight(23).margin({ top: 8 })
            Text('回复').fontSize(13).fontColor(this.themeColor).margin({ top: 10 }).onClick(() => this.replyTo(reply))
          }.width('100%').padding(16).backgroundColor(Color.White)
        }, (reply: V2exReply) => `${reply.id}`)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
