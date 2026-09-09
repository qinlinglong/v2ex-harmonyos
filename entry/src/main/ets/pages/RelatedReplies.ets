import { router } from '@kit.ArkUI';
import { V2exReply } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';
import { themeBackground, themeBodyText, themeMutedText, themePrimaryText, themeSecondaryText, themeSurface } from '../common/Theme';

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
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @State replies: V2exReply[] = [];
  @State loading: boolean = true;
  @State relatedOnly: boolean = true;
  @State selectedReference: string = '';
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

  private replyFloor(reply: V2exReply, renderedIndex: number): number {
    if (reply.no !== undefined && reply.no > 0) return reply.no;
    const sourceIndex: number = this.replies.findIndex((item: V2exReply) => item.id === reply.id);
    return sourceIndex >= 0 ? sourceIndex + 1 : renderedIndex + 1;
  }

  private anchorReply(): V2exReply | undefined {
    return this.replies.find((item: V2exReply) => item.id === this.anchorReplyId) ?? this.replies[0];
  }

  private referenceNames(): string[] {
    const anchor: V2exReply | undefined = this.anchorReply();
    if (anchor === undefined) return [];
    const names: string[] = [];
    const seen: Set<string> = new Set<string>();
    replyReferences(anchor.content).forEach((item: ReplyReference) => {
      const key: string = item.username.toLowerCase();
      if (seen.has(key)) return;
      seen.add(key);
      names.push(item.username);
    });
    return names;
  }

  private relatedByReference(content: string, replyUserName: string, replyAtName: string, byNo: Map<number, V2exReply>): boolean {
    const references: ReplyReference[] = replyReferences(content);
    const explicit: ReplyReference[] = references.filter((item: ReplyReference) => item.replyNo !== undefined);
    const exact: ReplyReference[] = explicit.filter((item: ReplyReference) => {
      const target: V2exReply | undefined = byNo.get(item.replyNo as number);
      return target?.member?.username?.toLowerCase() === item.username.toLowerCase();
    });
    if (exact.length > 0) {
      return exact.some((item: ReplyReference) => {
        const target: V2exReply | undefined = byNo.get(item.replyNo as number);
        const targetName: string = target?.member?.username?.toLowerCase() ?? '';
        return targetName === replyUserName.toLowerCase() || targetName === replyAtName.toLowerCase();
      });
    }
    const names: Set<string> = new Set<string>(references.map((item: ReplyReference) => item.username.toLowerCase()));
    return names.size === 0 || names.has(replyUserName.toLowerCase()) || names.has(replyAtName.toLowerCase());
  }

  private visibleReplies(): V2exReply[] {
    if (!this.relatedOnly) return this.replies;
    if (this.replies.length === 0) return [];
    const anchor: V2exReply = this.anchorReply() as V2exReply;
    const anchorName: string = anchor.member?.username?.toLowerCase() ?? '';
    const names: string[] = this.referenceNames();
    const atName: string = (this.selectedReference.length > 0 ? this.selectedReference : names[0] ?? '').toLowerCase();
    if (anchorName.length === 0 || atName.length === 0) return [anchor];
    const byNo: Map<number, V2exReply> = new Map<number, V2exReply>();
    this.replies.forEach((item: V2exReply, index: number) => byNo.set(item.no ?? index + 1, item));
    return this.replies.filter((reply: V2exReply) => {
      const author: string = reply.member?.username?.toLowerCase() ?? '';
      if (author !== anchorName && author !== atName) return false;
      return reply.id === anchor.id || this.relatedByReference(reply.content, anchorName, atName, byNo);
    });
  }

  private replyTo(reply: V2exReply): void {
    const username: string = reply.member?.username ?? '';
    if (username.length === 0) return;
    const floor: number = this.replyFloor(reply, this.visibleReplies().findIndex((item: V2exReply) => item.id === reply.id));
    AppStorage.set<string>('v2exReplyMention', `@${username}${floor > 0 ? ` #${floor}` : ''}`);
    router.back();
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('评论回复').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
        Blank()
      }.height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      Row() {
        Text(this.relatedOnly ? '智能模式' : '显示全部回复').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).layoutWeight(1)
        Button(this.relatedOnly ? '查看全部' : '智能模式').fontSize(13).backgroundColor(this.themeColor).fontColor(Color.White).onClick(() => this.relatedOnly = !this.relatedOnly)
      }.width('100%').padding(16).backgroundColor(themeSurface(this.darkMode)).margin({ top: 1 })
      if (this.referenceNames().length > 1) {
        Scroll() {
          Row({ space: 18 }) {
            ForEach(this.referenceNames(), (name: string) => {
              Text(`@${name}`).fontSize(14).fontColor(this.selectedReference.toLowerCase() === name.toLowerCase() || (this.selectedReference.length === 0 && name === this.referenceNames()[0]) ? this.themeColor : themeSecondaryText(this.darkMode))
                .onClick(() => this.selectedReference = name)
            }, (name: string) => `reference-${name}`)
          }.padding({ left: 16, right: 16, top: 10, bottom: 10 })
        }.scrollable(ScrollDirection.Horizontal).width('100%').backgroundColor(themeSurface(this.darkMode))
      }
      if (this.loading) LoadingProgress().width(30).height(30).color(this.themeColor).margin({ top: 40 })
      else if (this.visibleReplies().length === 0) Text('没有检测到关联回复').fontSize(15).fontColor(themeSecondaryText(this.darkMode)).margin({ top: 48 })
      else List({ space: 1 }) {
        ForEach(this.visibleReplies(), (reply: V2exReply, index: number) => ListItem() {
          Column() {
            Row() {
              Text(reply.member?.username ?? '匿名').fontSize(14).fontColor(this.themeColor)
              Blank()
              Text(`#${this.replyFloor(reply, index)}`).fontSize(12).fontColor(themeMutedText(this.darkMode)).margin({ right: 12 })
              if (reply.createdLabel && reply.createdLabel.length > 0) Text(reply.createdLabel).fontSize(12).fontColor(themeMutedText(this.darkMode))
              if ((reply.thanks ?? 0) > 0) Text(`${reply.thanks} 感谢`).fontSize(12).fontColor(themeMutedText(this.darkMode)).margin({ left: 8 })
            }.width('100%')
            Text(reply.content).fontSize(15).fontColor(themeBodyText(this.darkMode)).lineHeight(23).margin({ top: 8 })
            Text('回复').fontSize(13).fontColor(this.themeColor).margin({ top: 10 }).onClick(() => this.replyTo(reply))
          }.width('100%').padding(16).backgroundColor(themeSurface(this.darkMode))
        }, (reply: V2exReply) => `${reply.id}`)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
