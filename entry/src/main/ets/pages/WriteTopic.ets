import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { V2exMember, V2exNode, V2exTopic } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';
import { themeAccentText, themeBackground, themeBodyText, themeInputBackground, themeMutedText, themeOnColor, themePrimaryText, themeSurface } from '../common/Theme';

interface PreviewPart { kind: string; value: string; label?: string; }

function previewParts(markdown: string, syntax: string = 'markdown'): PreviewPart[] {
  const parts: PreviewPart[] = [];
  const pattern: RegExp = syntax === 'default'
    ? /((?:https?:\/\/|\/)[^\s<>()]+\.(?:png|jpe?g|gif|webp)(?:\?[^\s<>()]*)?)|!\[[^\]]*\]\(\s*((?:https?:\/\/|\/)[^)\s]+)\s*\)|\[([^\]]+)\]\(\s*((?:https?:\/\/|\/)[^)\s]+)\s*\)/gi
    : /!\[[^\]]*\]\(\s*((?:https?:\/\/|\/)[^)\s]+)\s*\)|\[([^\]]+)\]\(\s*((?:https?:\/\/|\/)[^)\s]+)\s*\)/gi;
  let cursor: number = 0;
  let match: RegExpExecArray | null = pattern.exec(markdown);
  while (match !== null) {
    const before: string = markdown.substring(cursor, match.index).trim();
    if (before.length > 0) parts.push({ kind: 'text', value: before });
    if (syntax === 'default' && (match[1] || match[2])) parts.push({ kind: 'image', value: match[1] ?? match[2] });
    else if (syntax === 'markdown' && match[1]) parts.push({ kind: 'image', value: match[1] });
    else parts.push({ kind: 'link', value: syntax === 'default' ? match[1] ?? match[4] : match[3], label: syntax === 'default' ? match[1] ?? match[3] : match[2] });
    cursor = match.index + match[0].length;
    match = pattern.exec(markdown);
  }
  const tail: string = markdown.substring(cursor).trim();
  if (tail.length > 0) parts.push({ kind: 'text', value: tail });
  if (parts.length === 0 && markdown.trim().length > 0) parts.push({ kind: 'text', value: markdown.trim() });
  return parts;
}

function previewText(value: string): string {
  return value.replace(/^#{1,6}\s+/gm, '').replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/__([^_]+)__/g, '$1').replace(/\*([^*]+)\*/g, '$1')
    .replace(/_([^_]+)_/g, '$1').replace(/`([^`]+)`/g, '$1');
}

@Entry
@Component
struct WriteTopic {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @State title: string = '';
  @State node: string = 'v2ex';
  @State content: string = '';
  @State status: string = '';
  @State submitting: boolean = false;
  @State preview: boolean = false;
  @State nodes: V2exNode[] = [];
  @State editing: boolean = false;
  @State editAllowed: boolean = false;
  @State editPermissionChecked: boolean = false;
  @StorageLink('v2exTopicSyntax') syntax: string = 'default';
  @StorageLink('v2exImgurClientId') imgurClientId: string = '';
  @StorageLink('v2exImageBed') imageBed: string = 'bilibili';
  @StorageLink('v2exCachedMember') cachedMemberJson: string = '';
  private topicId: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    this.topicId = Number(params?.['topicId'] ?? 0);
    this.editing = this.topicId > 0;
    this.loadNodes();
    if (this.editing) this.loadDraft();
  }

  private async loadNodes(): Promise<void> {
    try { this.nodes = await V2exService.nodes(); } catch (_) { this.nodes = []; }
  }

  private nodeSuggestions(): V2exNode[] {
    const query: string = this.node.trim().toLowerCase();
    const filtered: V2exNode[] = query.length === 0 ? this.nodes : this.nodes.filter((item: V2exNode) => `${item.title} ${item.name}`.toLowerCase().includes(query));
    return filtered.slice(0, 8);
  }

  private async loadDraft(): Promise<void> {
    try {
      const topic: V2exTopic = await V2exService.topic(this.topicId);
      if (topic.editable !== true || !this.isSelf(topic.member?.username)) {
        this.status = '当前账号无权编辑此主题';
        return;
      }
      this.editAllowed = true;
      this.title = topic.title;
      this.content = topic.content;
      this.node = topic.node?.name ?? this.node;
    } catch (_) { this.status = '编辑内容加载失败'; }
    finally { this.editPermissionChecked = true; }
  }

  private isSelf(username: string | undefined): boolean {
    if (!username) return false;
    try {
      const member: V2exMember = JSON.parse(this.cachedMemberJson) as V2exMember;
      return member.username?.toLowerCase() === username.toLowerCase();
    } catch (_) { return false; }
  }

  private async submit(): Promise<void> {
    if (this.editing && (!this.editPermissionChecked || !this.editAllowed)) {
      this.status = '当前账号无权编辑此主题';
      return;
    }
    if (this.title.trim().length < 3 || this.content.trim().length < 3) { this.status = '标题和正文至少 3 个字符'; return; }
    this.submitting = true; this.status = '正在发布…';
    try {
      const ok: boolean = this.editing
        ? await V2exService.editTopic(this.topicId, this.title.trim(), this.content.trim(), this.syntax, this.node.trim())
        : await V2exService.writeTopic(this.title.trim(), this.content.trim(), this.node.trim(), this.syntax);
      this.status = ok ? (this.editing ? '保存成功' : '发布成功') : '操作失败，请先登录';
      if (ok) setTimeout(() => router.back(), 500);
    } catch (_) { this.status = '发布失败，请先登录'; }
    finally { this.submitting = false; }
  }

  private async insertImage(): Promise<void> {
    if (this.imageBed === 'imgur' && this.imgurClientId.trim().length === 0) { this.status = '请先在设置中配置 Imgur Client ID'; return; }
    if (this.imageBed === 'bilibili' && !V2exService.biliLoggedIn()) { this.status = '请先在设置中登录 Bilibili 图床'; return; }
    try {
      const result = await new picker.PhotoViewPicker().select({ maxSelectNumber: 1 });
      if (!result.photoUris || result.photoUris.length === 0) return;
      this.status = '正在上传图片…';
      const link: string = this.imageBed === 'bilibili'
        ? await V2exService.uploadBilibiliImage(result.photoUris[0])
        : await V2exService.uploadImage(result.photoUris[0], this.imgurClientId);
      this.content = `${this.content}${this.content.length > 0 && !this.content.endsWith('\n') ? '\n' : ''}![图片](${link})\n`;
      this.status = '图片已插入';
    } catch (_) { this.status = this.imageBed === 'bilibili' ? 'Bilibili 图片上传失败，请检查登录状态' : '图片上传失败，请检查配置和网络'; }
  }

  private contentUrl(url: string): string {
    if (!url.startsWith('/')) return url;
    const configured: string = AppStorage.get<string>('v2exDomain') ?? 'https://www.v2ex.com';
    return `${configured.replace(/\/$/, '')}${url}`;
  }

  private openPreviewLink(url: string): void {
    const configured: string = AppStorage.get<string>('v2exDomain') ?? 'https://www.v2ex.com';
    const absolute: string = url.startsWith('/') ? `${configured.replace(/\/$/, '')}${url}` : url;
    const topicMatch: RegExpMatchArray | null = absolute.match(/\/t\/(\d+)/);
    const isV2ex: boolean = absolute.indexOf(configured.replace(/\/$/, '')) === 0 || /https?:\/\/([^/]*\.)?v2ex\.com(?:\/|$)/i.test(absolute);
    if (isV2ex && topicMatch) {
      router.pushUrl({ url: 'pages/TopicDetail', params: { id: Number(topicMatch[1]) } });
      return;
    }
    const memberMatch: RegExpMatchArray | null = absolute.match(/\/member\/([^/?#]+)/);
    if (isV2ex && memberMatch) {
      router.pushUrl({ url: 'pages/Profile', params: { username: decodeURIComponent(memberMatch[1]) } });
      return;
    }
    router.pushUrl({ url: 'pages/WebViewPage', params: { title: '网页', url: absolute } });
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(themeAccentText(this.themeColor, this.darkMode)).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text(this.editing ? '编辑主题' : '发布主题').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
        Blank()
        Image($r('app.media.ic_preview')).width(22).height(22).fillColor(themeAccentText(this.themeColor, this.darkMode)).margin({ right: 16 })
          .onClick(() => this.preview = !this.preview)
        Image($r('app.media.ic_image')).width(22).height(22).fillColor(themeAccentText(this.themeColor, this.darkMode)).margin({ right: 16 })
          .onClick(() => this.insertImage())
        Image($r('app.media.ic_send')).width(22).height(22)
          .fillColor(this.submitting || (this.editing && !this.editAllowed) ? themeMutedText(this.darkMode) : themeAccentText(this.themeColor, this.darkMode))
          .opacity(this.submitting || (this.editing && !this.editAllowed) ? 0.5 : 1)
          .onClick(() => { if (!this.submitting) this.submit(); })
      }.height(60).width('100%').padding({ right: 18 }).backgroundColor(themeSurface(this.darkMode))
      Scroll() {
        Column({ space: 14 }) {
          if (!this.preview) {
            TextInput({ placeholder: '主题标题', text: this.title }).height(52).width('100%').fontSize(17).fontColor(themePrimaryText(this.darkMode)).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode))
              .onChange((value: string) => this.title = value)
            TextInput({ placeholder: '节点名称，例如 v2ex', text: this.node }).height(48).width('100%').fontSize(15).fontColor(themePrimaryText(this.darkMode)).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode))
              .onChange((value: string) => this.node = value)
            if (!this.editing && this.nodeSuggestions().length > 0) {
              Column() {
                Text('节点建议').fontSize(13).fontColor(themeMutedText(this.darkMode)).width('100%')
                Scroll() {
                  Row() {
                    ForEach(this.nodeSuggestions(), (item: V2exNode) => Text(`${item.title}  ${item.name}`).fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode))
                      .padding({ left: 12, right: 12, top: 8, bottom: 8 }).backgroundColor(themeSurface(this.darkMode)).borderRadius(16).margin({ right: 8 })
                      .onClick(() => this.node = item.name), (item: V2exNode) => item.name)
                  }
                }.scrollable(ScrollDirection.Horizontal).width('100%').height(42).margin({ top: 8 })
              }.width('100%')
            }
            Row() {
              Text('语法').fontSize(14).fontColor(themeMutedText(this.darkMode)).margin({ right: 12 })
              Button('V2EX 原生').fontSize(13).backgroundColor(this.syntax === 'default' ? this.themeColor : themeInputBackground(this.darkMode)).fontColor(this.syntax === 'default' ? themeOnColor(this.themeColor) : themePrimaryText(this.darkMode)).onClick(() => this.syntax = 'default')
              Button('Markdown').fontSize(13).margin({ left: 8 }).backgroundColor(this.syntax === 'markdown' ? this.themeColor : themeInputBackground(this.darkMode)).fontColor(this.syntax === 'markdown' ? themeOnColor(this.themeColor) : themePrimaryText(this.darkMode)).onClick(() => this.syntax = 'markdown')
            }.width('100%')
          }
          if (this.preview) {
            Column() {
              Text(this.title || '（无标题）').fontSize(22).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
              ForEach(previewParts(this.content || '（无正文）', this.syntax), (part: PreviewPart) => {
                if (part.kind === 'image') {
                  Image(this.contentUrl(part.value)).width('100%').constraintSize({ maxHeight: 520 })
                    .objectFit(ImageFit.Contain).margin({ top: 14, bottom: 4 })
                } else if (part.kind === 'link') {
                  Text(part.label ?? part.value).fontSize(16).fontColor(themeAccentText(this.themeColor, this.darkMode)).lineHeight(26)
                    .decoration({ type: TextDecorationType.Underline, color: themeAccentText(this.themeColor, this.darkMode) }).margin({ top: 20 })
                    .onClick(() => this.openPreviewLink(part.value))
                } else {
                  Text(this.syntax === 'markdown' ? previewText(part.value) : part.value).fontSize(16).fontColor(themeBodyText(this.darkMode)).lineHeight(26)
                    .margin({ top: 20 }).textAlign(TextAlign.Start)
                }
              }, (part: PreviewPart, index: number) => `preview-${part.kind}-${index}-${part.value.substring(0, 12)}`)
            }.width('100%').padding(18).backgroundColor(themeSurface(this.darkMode))
          } else {
            TextArea({ placeholder: this.syntax === 'markdown' ? '支持 Markdown 的主题正文' : '支持 V2EX 原生格式的主题正文', text: this.content }).width('100%').height(360).fontSize(16).fontColor(themePrimaryText(this.darkMode))
              .onChange((value: string) => this.content = value)
          }
          if (this.status.length > 0) Text(this.status).fontSize(14).fontColor(themeAccentText(this.themeColor, this.darkMode))
        }.width('100%').padding(18)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
