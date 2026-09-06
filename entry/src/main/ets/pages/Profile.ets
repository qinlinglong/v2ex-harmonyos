import { router } from '@kit.ArkUI';
import { V2exMember } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';

@Entry
@Component
struct Profile {
  @State member: V2exMember | undefined = undefined;
  @State username: string = '';
  @State status: string = '加载中…';
  @State followed: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    this.username = String(params?.['username'] ?? '');
    this.load();
  }

  private async load(): Promise<void> {
    try { this.member = await V2exService.member(this.username); this.status = ''; }
    catch (_) { this.status = '用户资料暂时不可用'; }
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor('#4F7CAC').width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text(this.username || '个人资料').fontSize(20).fontWeight(FontWeight.Bold)
      }.height(60).width('100%').backgroundColor(Color.White)
      if (this.member) {
        Column() {
          Text(this.member.username).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#202124')
          Text(this.member.tagline || 'V2EX 用户').fontSize(15).fontColor('#7B8794').margin({ top: 10 })
          Button(this.followed ? '已关注' : '关注').margin({ top: 22 }).onClick(async () => {
            const ok: boolean = await V2exService.memberAction(this.username, this.followed ? 'unfollow' : 'follow');
            if (ok) this.followed = !this.followed;
            else this.status = '请先登录';
          })
          Text('主题 · 回复 · 收藏').fontSize(14).fontColor('#4F7CAC').margin({ top: 26 })
        }.width('100%').padding({ top: 42, bottom: 42 }).backgroundColor(Color.White)
      } else {
        Text(this.status).fontSize(15).fontColor('#7B8794').margin({ top: 48 })
      }
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
