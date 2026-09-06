import { router } from '@kit.ArkUI';
import { V2exMember } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';

@Entry
@Component
struct Rank {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @State members: V2exMember[] = [];
  @State loading: boolean = true;
  @State status: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    this.status = '';
    try {
      this.members = await V2exService.topMembers();
      if (this.members.length === 0) this.status = '暂时没有排行数据';
    } catch (_) { this.status = '排行加载失败，请稍后重试'; }
    finally { this.loading = false; }
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('社区排行').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
        Text('↻').fontSize(24).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => this.load())
      }.height(60).width('100%').backgroundColor(Color.White)
      if (this.loading) {
        LoadingProgress().width(30).height(30).color(this.themeColor).margin({ top: 40 })
      } else if (this.status.length > 0) {
        Text(this.status).fontSize(15).fontColor('#7B8794').margin({ top: 48 })
      } else {
        List({ space: 1 }) {
          ForEach(this.members, (member: V2exMember, index: number) => ListItem() {
            Row() {
              Text(`${index + 1}`).fontSize(16).fontColor(this.themeColor).width(44).textAlign(TextAlign.Center)
              Stack() {
                Text(member.username.substring(0, 1).toUpperCase()).fontSize(13).fontColor(Color.White)
                  .width(34).height(34).textAlign(TextAlign.Center).backgroundColor('#B7C4D2').borderRadius(17)
                if (member.avatar_large) Image(member.avatar_large).width(34).height(34).borderRadius(17).objectFit(ImageFit.Cover)
              }
              Text(member.username).fontSize(16).fontColor('#202124').margin({ left: 12 })
              Blank()
            }.width('100%').padding({ top: 14, bottom: 14, right: 18 }).backgroundColor(Color.White)
              .onClick(() => router.pushUrl({ url: 'pages/Profile', params: { username: member.username } }))
          }, (member: V2exMember) => member.username)
        }.layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
