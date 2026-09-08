import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { V2exNode } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';

interface PreviewPart { kind: string; value: string; label?: string; }

function previewParts(markdown: string): PreviewPart[] {
  const parts: PreviewPart[] = [];
  const pattern: RegExp = /!\[[^\]]*\]\(\s*((?:https?:\/\/|\/)[^)\s]+)\s*\)|\[([^\]]+)\]\(\s*((?:https?:\/\/|\/)[^)\s]+)\s*\)/gi;
  let cursor: number = 0;
  let match: RegExpExecArray | null = pattern.exec(markdown);
  while (match !== null) {
    const before: string = markdown.substring(cursor, match.index).trim();
    if (before.length > 0) parts.push({ kind: 'text', value: before });
    if (match[1]) parts.push({ kind: 'image', value: match[1] });
    else parts.push({ kind: 'link', value: match[3], label: match[2] });
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
  @State title: string = '';
  @State node: string = 'v2ex';
  @State content: string = '';
  @State status: string = '';
  @State submitting: boolean = false;
  @State preview: boolean = false;
  @State nodes: V2exNode[] = [];
  @State editing: boolean = false;
  @StorageLink('v2exImgurClientId') imgurClientId: string = '';
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
      const topic = await V2exService.topic(this.topicId);
      this.title = topic.title;
      this.content = topic.content;
      this.node = topic.node?.name ?? this.node;
    } catch (_) { this.status = '编辑内容加载失败'; }
  }

  private async submit(): Promise<void> {
    if (this.title.trim().length < 3 || this.content.trim().length < 3) { this.status = '标题和正文至少 3 个字符'; return; }
    this.submitting = true; this.status = '正在发布…';
    try {
      const ok: boolean = this.editing
        ? await V2exService.editTopic(this.topicId, this.title.trim(), this.content.trim(), 'default', this.node.trim())
        : await V2exService.writeTopic(this.title.trim(), this.content.trim(), this.node.trim());
      this.status = ok ? (this.editing ? '保存成功' : '发布成功') : '操作失败，请先登录';
      if (ok) setTimeout(() => router.back(), 500);
    } catch (_) { this.status = '发布失败，请先登录'; }
    finally { this.submitting = false; }
  }

  private async insertImage(): Promise<void> {
    if (this.imgurClientId.trim().length === 0) { this.status = '请先在设置中配置 Imgur Client ID'; return; }
    try {
      const result = await new picker.PhotoViewPicker().select({ maxSelectNumber: 1 });
      if (!result.photoUris || result.photoUris.length === 0) return;
      this.status = '正在上传图片…';
      const link: string = await V2exService.uploadImage(result.photoUris[0], this.imgurClientId);
      this.content = `${this.content}${this.content.length > 0 && !this.content.endsWith('\n') ? '\n' : ''}![图片](${link})\n`;
      this.status = '图片已插入';
    } catch (_) { this.status = '图片上传失败，请检查配置和网络'; }
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
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text(this.editing ? '编辑主题' : '发布主题').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
        Image($r('app.media.ic_preview')).width(22).height(22).fillColor(this.themeColor).margin({ right: 16 })
          .onClick(() => this.preview = !this.preview)
        Image($r('app.media.ic_image')).width(22).height(22).fillColor(this.themeColor).margin({ right: 16 })
          .onClick(() => this.insertImage())
        Image($r('app.media.ic_send')).width(22).height(22).fillColor(this.submitting ? '#9AA0A6' : this.themeColor)
          .opacity(this.submitting ? 0.5 : 1).onClick(() => { if (!this.submitting) this.submit(); })
      }.height(60).width('100%').padding({ right: 18 }).backgroundColor(Color.White)
      Scroll() {
        Column({ space: 14 }) {
          if (!this.preview) {
            TextInput({ placeholder: '主题标题', text: this.title }).height(52).width('100%').fontSize(17).fontColor('#202124').placeholderColor('#8A97A6').backgroundColor('#F1F4F7')
              .onChange((value: string) => this.title = value)
            TextInput({ placeholder: '节点名称，例如 v2ex', text: this.node }).height(48).width('100%').fontSize(15).fontColor('#202124').placeholderColor('#8A97A6').backgroundColor('#F1F4F7')
              .onChange((value: string) => this.node = value)
            if (!this.editing && this.nodeSuggestions().length > 0) {
              Column() {
                Text('节点建议').fontSize(13).fontColor('#8A97A6').width('100%')
                Scroll() {
                  Row() {
                    ForEach(this.nodeSuggestions(), (item: V2exNode) => Text(`${item.title}  ${item.name}`).fontSize(13).fontColor(this.themeColor)
                      .padding({ left: 12, right: 12, top: 8, bottom: 8 }).backgroundColor(Color.White).borderRadius(16).margin({ right: 8 })
                      .onClick(() => this.node = item.name), (item: V2exNode) => item.name)
                  }
                }.scrollable(ScrollDirection.Horizontal).width('100%').height(42).margin({ top: 8 })
              }.width('100%')
            }
          }
          if (this.preview) {
            Column() {
              Text(this.title || '（无标题）').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#202124')
              ForEach(previewParts(this.content || '（无正文）'), (part: PreviewPart) => {
                if (part.kind === 'image') {
                  Image(this.contentUrl(part.value)).width('100%').constraintSize({ maxHeight: 520 })
                    .objectFit(ImageFit.Contain).margin({ top: 14, bottom: 4 })
                } else if (part.kind === 'link') {
                  Text(part.label ?? part.value).fontSize(16).fontColor(this.themeColor).lineHeight(26)
                    .decoration({ type: TextDecorationType.Underline, color: this.themeColor }).margin({ top: 20 })
                    .onClick(() => this.openPreviewLink(part.value))
                } else {
                  Text(previewText(part.value)).fontSize(16).fontColor('#30343B').lineHeight(26)
                    .margin({ top: 20 }).textAlign(TextAlign.Start)
                }
              }, (part: PreviewPart, index: number) => `preview-${part.kind}-${index}-${part.value.substring(0, 12)}`)
            }.width('100%').padding(18).backgroundColor(Color.White)
          } else {
            TextArea({ placeholder: '支持 Markdown 的主题正文', text: this.content }).width('100%').height(360).fontSize(16).fontColor('#202124')
              .onChange((value: string) => this.content = value)
          }
          if (this.status.length > 0) Text(this.status).fontSize(14).fontColor('#4F7CAC')
        }.width('100%').padding(18)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
