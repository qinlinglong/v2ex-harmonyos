import { router } from '@kit.ArkUI';
import { V2exMember } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';
import { themeAccentText, themeBackground, themeMutedText, themePrimaryText, themeSecondaryText, themeSurface } from '../common/Theme';

@Entry
@Component
struct Rank {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @State members: V2exMember[] = [];
  @State loading: boolean = true;
  @State status: string = '';
  @State mode: number = 0;

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    this.status = '';
    try {
      this.members = await V2exService.topMembers(this.mode === 0 ? 'rich' : 'player');
      if (this.members.length === 0) this.status = '暂时没有排行数据';
    } catch (_) { this.status = '排行加载失败，请稍后重试'; }
    finally { this.loading = false; }
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(themeAccentText(this.themeColor, this.darkMode)).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('社区排行').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
        Blank()
      }.height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      Row() {
        Text('财富排行').fontSize(15).fontColor(this.mode === 0 ? themeAccentText(this.themeColor, this.darkMode) : themeSecondaryText(this.darkMode))
          .layoutWeight(1).textAlign(TextAlign.Center).onClick(() => { if (this.mode !== 0) { this.mode = 0; this.load(); } })
        Text('消费排行').fontSize(15).fontColor(this.mode === 1 ? themeAccentText(this.themeColor, this.darkMode) : themeSecondaryText(this.darkMode))
          .layoutWeight(1).textAlign(TextAlign.Center).onClick(() => { if (this.mode !== 1) { this.mode = 1; this.load(); } })
      }.height(48).width('100%').backgroundColor(themeSurface(this.darkMode))
      if (this.loading) {
        LoadingProgress().width(30).height(30).color(themeAccentText(this.themeColor, this.darkMode)).margin({ top: 40 })
      } else if (this.status.length > 0) {
        Text(this.status).fontSize(15).fontColor(themeSecondaryText(this.darkMode)).margin({ top: 48 })
      } else {
        List({ space: 1 }) {
          ForEach(this.members, (member: V2exMember, index: number) => ListItem() {
            Row() {
              Text(`${index + 1}`).fontSize(16).fontColor(themeAccentText(this.themeColor, this.darkMode)).width(44).textAlign(TextAlign.Center)
              Stack() {
                Text(member.username.substring(0, 1).toUpperCase()).fontSize(13).fontColor(Color.White)
                  .width(34).height(34).textAlign(TextAlign.Center).backgroundColor(this.darkMode ? '#435466' : '#B7C4D2').borderRadius(17)
                if (member.avatar_large) Image(member.avatar_large).width(34).height(34).borderRadius(17).objectFit(ImageFit.Cover)
              }
              Text(member.username).fontSize(16).fontColor(themePrimaryText(this.darkMode)).margin({ left: 12 })
              Blank()
            }.width('100%').padding({ top: 14, bottom: 14, right: 18 }).backgroundColor(themeSurface(this.darkMode))
              .onClick(() => router.pushUrl({ url: 'pages/Profile', params: { username: member.username } }))
          }, (member: V2exMember) => member.username)
        }.layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
