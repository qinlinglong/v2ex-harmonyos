import { router } from '@kit.ArkUI';
import { V2exReply } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';
import { themeBackground, themeBodyText, themeInputBackground, themeMutedText, themePrimaryText, themeSurface } from '../common/Theme';

@Entry
@Component
struct SearchReplyMember {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exReplyMention') mention: string = '';
  @State topicId: number = 0;
  @State query: string = '';
  @State replies: V2exReply[] = [];
  @State selected: number[] = [];
  @State loading: boolean = true;
  @State status: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    this.topicId = Number(params?.['topicId'] ?? 0);
    this.load();
  }

  private async load(): Promise<void> {
    try { this.replies = await V2exService.replies(this.topicId); }
    catch (_) { this.status = '回复加载失败'; }
    finally { this.loading = false; }
  }

  private visibleReplies(): V2exReply[] {
    const query: string = this.query.trim().toLowerCase();
    if (!query) return this.replies;
    return this.replies.filter((reply: V2exReply) => `${reply.member?.username ?? ''} ${reply.content}`.toLowerCase().includes(query));
  }

  private replyFloor(reply: V2exReply): number {
    if (reply.no !== undefined && reply.no > 0) return reply.no;
    const sourceIndex: number = this.replies.findIndex((item: V2exReply) => item.id === reply.id);
    return sourceIndex >= 0 ? sourceIndex + 1 : 0;
  }

  private confirm(): void {
    const names: string[] = this.replies.filter((reply: V2exReply) => this.selected.indexOf(reply.id) >= 0)
      .map((reply: V2exReply) => `@${reply.member?.username ?? ''}`).filter((name: string) => name.length > 1);
    this.mention = Array.from(new Set(names)).join(' ');
    router.back();
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('选择回复对象').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode)).layoutWeight(1)
        Text('确定').fontSize(15).fontColor(this.themeColor).onClick(() => this.confirm())
      }.height(60).width('100%').padding({ right: 18 }).backgroundColor(themeSurface(this.darkMode))
      TextInput({ placeholder: '搜索用户名或回复内容', text: this.query }).width('100%').height(48).margin({ top: 1 }).padding(14).fontColor(themePrimaryText(this.darkMode)).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode))
        .onChange((value: string) => this.query = value).backgroundColor(themeSurface(this.darkMode))
      if (this.loading) LoadingProgress().width(30).height(30).color(this.themeColor).margin({ top: 40 })
      else if (this.status.length > 0 || this.visibleReplies().length === 0) Text(this.status || '暂无搜索结果').fontSize(15).fontColor(themeMutedText(this.darkMode)).margin({ top: 42 })
      else List({ space: 1 }) {
        ForEach(this.visibleReplies(), (reply: V2exReply) => ListItem() {
          Row() {
            Text(this.selected.indexOf(reply.id) >= 0 ? '✓' : '○').fontSize(24).fontColor(this.themeColor).width(36)
            Column() {
              Text(`${reply.member?.username ?? '匿名'}  #${this.replyFloor(reply)}`).fontSize(14).fontColor(this.themeColor)
              Text(reply.content).fontSize(14).fontColor(themeBodyText(this.darkMode)).maxLines(3).margin({ top: 5 })
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%').padding(16).backgroundColor(themeSurface(this.darkMode))
        }.onClick(() => {
          this.selected = this.selected.indexOf(reply.id) >= 0 ? this.selected.filter((id: number) => id !== reply.id) : this.selected.concat([reply.id]);
        }), (reply: V2exReply) => `${reply.id}`)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
