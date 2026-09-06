import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { V2exNode } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';

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

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text(this.editing ? '编辑主题' : '发布主题').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
        Text(this.preview ? '返回编辑' : '预览').fontSize(14).fontColor(this.themeColor).margin({ right: 16 })
          .onClick(() => this.preview = !this.preview)
        Text('图片').fontSize(14).fontColor(this.themeColor).margin({ right: 16 }).onClick(() => this.insertImage())
        Text(this.submitting ? '保存中' : (this.editing ? '保存' : '发布')).fontSize(15).fontColor(this.themeColor).onClick(() => this.submit())
      }.height(60).width('100%').padding({ right: 18 }).backgroundColor(Color.White)
      Scroll() {
        Column({ space: 14 }) {
          TextInput({ placeholder: '主题标题', text: this.title }).height(52).width('100%').fontSize(17).fontColor('#202124')
            .onChange((value: string) => this.title = value)
          TextInput({ placeholder: '节点名称，例如 v2ex', text: this.node }).height(48).width('100%').fontSize(15).fontColor('#202124')
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
          if (this.preview) {
            Column() {
              Text(this.title || '（无标题）').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#202124')
              Text(this.content || '（无正文）').fontSize(16).fontColor('#30343B').lineHeight(26).margin({ top: 20 })
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
