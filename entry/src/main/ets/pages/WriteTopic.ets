import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';

@Entry
@Component
struct WriteTopic {
  @State title: string = '';
  @State node: string = 'v2ex';
  @State content: string = '';
  @State status: string = '';
  @State submitting: boolean = false;

  private async submit(): Promise<void> {
    if (this.title.trim().length < 3 || this.content.trim().length < 3) { this.status = '标题和正文至少 3 个字符'; return; }
    this.submitting = true; this.status = '正在发布…';
    try {
      const ok: boolean = await V2exService.writeTopic(this.title.trim(), this.content.trim(), this.node.trim());
      this.status = ok ? '发布成功' : '发布失败，请先登录';
      if (ok) setTimeout(() => router.back(), 500);
    } catch (_) { this.status = '发布失败，请先登录'; }
    finally { this.submitting = false; }
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor('#4F7CAC').width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('发布主题').fontSize(20).fontWeight(FontWeight.Bold)
        Blank()
        Text(this.submitting ? '发布中' : '发布').fontSize(15).fontColor('#4F7CAC').onClick(() => this.submit())
      }.height(60).width('100%').padding({ right: 18 }).backgroundColor(Color.White)
      Scroll() {
        Column({ space: 14 }) {
          TextInput({ placeholder: '主题标题', text: this.title }).height(52).width('100%').fontSize(17)
            .onChange((value: string) => this.title = value)
          TextInput({ placeholder: '节点名称，例如 v2ex', text: this.node }).height(48).width('100%').fontSize(15)
            .onChange((value: string) => this.node = value)
          TextArea({ placeholder: '支持 Markdown 的主题正文', text: this.content }).width('100%').height(360).fontSize(16)
            .onChange((value: string) => this.content = value)
          if (this.status.length > 0) Text(this.status).fontSize(14).fontColor('#4F7CAC')
        }.width('100%').padding(18)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
