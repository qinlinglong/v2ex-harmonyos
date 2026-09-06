import { router } from '@kit.ArkUI';
import { V2exMember } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';

@Entry
@Component
struct SearchReplyMember {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @State query: string = '';
  @State members: V2exMember[] = [];
  @State status: string = '搜索用户名后选择回复对象';
  private async submit(): Promise<void> { if (!this.query.trim()) return; try { this.members = await V2exService.searchMembers(this.query.trim()); this.status = this.members.length === 0 ? '没有找到用户' : ''; } catch (_) { this.status = '搜索失败'; } }
  build() {
    Column() {
      Row() { Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back()); Text('选择回复对象').fontSize(20).fontWeight(FontWeight.Bold) }
        .height(60).width('100%').backgroundColor(Color.White)
      Row() { TextInput({ placeholder: '用户名', text: this.query }).layoutWeight(1).height(46).onChange((v: string) => this.query = v).onSubmit(() => this.submit()); Button('搜索').margin({ left: 10 }).onClick(() => this.submit()) }.width('100%').padding(16).backgroundColor(Color.White)
      if (this.status.length > 0) Text(this.status).fontSize(14).fontColor('#8A97A6').margin({ top: 32 })
      else List({ space: 1 }) { ForEach(this.members, (member: V2exMember) => ListItem() { Row() { Text(member.username).fontSize(16).layoutWeight(1); Text('选择').fontSize(13).fontColor(this.themeColor) }.width('100%').padding(16).backgroundColor(Color.White) }.onClick(() => router.pushUrl({ url: 'pages/Profile', params: { username: member.username } })), (member: V2exMember) => member.username) }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
