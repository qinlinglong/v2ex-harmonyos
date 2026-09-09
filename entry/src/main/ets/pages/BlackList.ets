import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { themeAccentText, themeBackground, themeMutedText, themePrimaryText, themeSecondaryText, themeSurface } from '../common/Theme';

@Entry
@Component
struct BlackList {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exBlockedUsers') blockedUsersJson: string = '[]';
  @StorageLink('v2exIgnoredTopicIds') ignoredTopicsJson: string = '[]';
  @State tab: number = 0;
  @State users: string[] = [];
  @State topics: number[] = [];
  @State status: string = '';

  aboutToAppear(): void { this.read(); }

  private read(): void {
    try { this.users = JSON.parse(this.blockedUsersJson) as string[]; } catch (_) { this.users = []; }
    try { this.topics = JSON.parse(this.ignoredTopicsJson) as number[]; } catch (_) { this.topics = []; }
  }

  private async clearUsers(): Promise<void> {
    this.status = '清理中…';
    try {
      const ok: boolean = await V2exService.resetBlocked();
      if (!ok) { this.status = '清理失败，请先登录'; return; }
      this.users = []; this.blockedUsersJson = '[]'; this.status = '已清空屏蔽用户';
    } catch (_) { this.status = '清理失败，请稍后重试'; }
  }
  private async clearTopics(): Promise<void> {
    this.status = '清理中…';
    try {
      const ok: boolean = await V2exService.resetIgnoredTopics();
      if (!ok) { this.status = '清理失败，请先登录'; return; }
      this.topics = []; this.ignoredTopicsJson = '[]'; this.status = '已清空忽略主题';
    } catch (_) { this.status = '清理失败，请稍后重试'; }
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(themeAccentText(this.themeColor, this.darkMode)).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('屏蔽列表').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
        Blank()
        Image($r('app.media.ic_delete')).width(22).height(22).fillColor(themeAccentText(this.themeColor, this.darkMode)).margin({ right: 8 })
          .onClick(() => this.tab === 0 ? this.clearUsers() : this.clearTopics())
      }.height(60).width('100%').padding({ right: 18 }).backgroundColor(themeSurface(this.darkMode))
      Row() {
        Text('屏蔽用户').fontSize(15).fontColor(this.tab === 0 ? themeAccentText(this.themeColor, this.darkMode) : themeSecondaryText(this.darkMode)).layoutWeight(1).textAlign(TextAlign.Center)
          .onClick(() => this.tab = 0)
        Text('忽略主题').fontSize(15).fontColor(this.tab === 1 ? themeAccentText(this.themeColor, this.darkMode) : themeSecondaryText(this.darkMode)).layoutWeight(1).textAlign(TextAlign.Center)
          .onClick(() => this.tab = 1)
      }.height(50).width('100%').backgroundColor(themeSurface(this.darkMode))
      if (this.tab === 0) {
        if (this.users.length === 0) Text('暂无屏蔽用户').fontSize(15).fontColor(themeMutedText(this.darkMode)).margin({ top: 42 })
        else List({ space: 1 }) { ForEach(this.users, (username: string) => ListItem() {
          Row() { Text(username).fontSize(16).layoutWeight(1); Text('查看资料').fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode)) }
            .width('100%').padding(16).backgroundColor(themeSurface(this.darkMode))
        }.onClick(() => router.pushUrl({ url: 'pages/Profile', params: { username } })), (username: string) => username) }.layoutWeight(1).width('100%')
      } else {
        if (this.topics.length === 0) Text('暂无忽略主题').fontSize(15).fontColor(themeMutedText(this.darkMode)).margin({ top: 42 })
        else List({ space: 1 }) { ForEach(this.topics, (id: number) => ListItem() {
          Row() { Text(`主题 #${id}`).fontSize(16).layoutWeight(1); Text('查看').fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode)) }
            .width('100%').padding(16).backgroundColor(themeSurface(this.darkMode))
        }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id } })), (id: number) => `${id}`) }.layoutWeight(1).width('100%')
      }
      if (this.status.length > 0) Text(this.status).fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode)).margin({ bottom: 12 })
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
