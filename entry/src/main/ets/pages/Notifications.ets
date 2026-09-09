import { router } from '@kit.ArkUI';
import { V2exNotification } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';
import { themeBackground, themePrimaryText, themeSurface } from '../common/Theme';

@Entry
@Component
struct Notifications {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exNotificationsCache') cacheJson: string = '[]';
  @State items: V2exNotification[] = [];
  @State loading: boolean = true;
  @State status: string = '';
  @State deletingId: number = 0;
  @State loadingMore: boolean = false;
  @State page: number = 1;
  @State noMore: boolean = false;
  @State loadMoreStatus: string = '';

  aboutToAppear(): void {
    this.restoreCache();
    this.load();
  }

  private restoreCache(): void {
    try {
      const cached: V2exNotification[] = JSON.parse(this.cacheJson) as V2exNotification[];
      if (Array.isArray(cached) && cached.length > 0) {
        this.items = cached;
        this.loading = false;
      }
    } catch (_) { /* corrupt cache is ignored */ }
  }

  private async load(): Promise<void> {
    const hasCached: boolean = this.items.length > 0;
    this.loading = !hasCached;
    this.status = '';
    this.page = 1;
    this.noMore = false;
    this.loadMoreStatus = '';
    try {
      const fresh: V2exNotification[] = await V2exService.notifications(1);
      this.items = fresh;
      this.cacheJson = JSON.stringify(fresh);
      if (this.items.length === 0) this.status = '暂无通知或尚未登录';
    } catch (_) {
      if (!hasCached) this.status = '请先登录 V2EX';
    }
    finally { this.loading = false; }
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore || this.noMore) return;
    this.loadingMore = true;
    try {
      const next: V2exNotification[] = await V2exService.notifications(this.page + 1);
      const unique: V2exNotification[] = next.filter((item: V2exNotification) => this.items.findIndex((old: V2exNotification) => old.id === item.id) < 0);
      if (unique.length === 0) { this.noMore = true; this.loadMoreStatus = '没有更多通知'; }
      else {
        this.items = this.items.concat(unique);
        this.cacheJson = JSON.stringify(this.items);
        this.page += 1;
        this.loadMoreStatus = '';
      }
    } catch (_) { this.loadMoreStatus = '加载更多失败'; }
    finally { this.loadingMore = false; }
  }

  private async remove(item: V2exNotification): Promise<void> {
    this.deletingId = item.id;
    const ok: boolean = await V2exService.notificationAction(item.id, 'delete');
    if (ok) {
      this.items = this.items.filter((value: V2exNotification) => value.id !== item.id);
      this.cacheJson = JSON.stringify(this.items);
    }
    else this.status = '删除失败，请先登录';
    this.deletingId = 0;
  }

  @Builder
  row(item: V2exNotification) {
    ListItem() {
      Row() {
        Stack() {
          Text(item.username.substring(0, 1).toUpperCase()).fontSize(13).fontColor(Color.White)
            .width(40).height(40).textAlign(TextAlign.Center).backgroundColor('#B7C4D2').borderRadius(20)
          if (item.avatar) Image(item.avatar).width(40).height(40).borderRadius(20).objectFit(ImageFit.Cover)
        }
        Column() {
            Text(item.username).fontSize(14).fontColor(this.themeColor)
          Row() {
            Text(item.topicTitle).fontSize(15).fontColor(themePrimaryText(this.darkMode)).maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            Image($r('app.media.ic_delete')).width(18).height(18).fillColor('#C05A73').margin({ left: 10 })
              .onClick(() => this.remove(item)).hitTestBehavior(HitTestMode.Block)
          }.width('100%').margin({ top: 6 })
        }.alignItems(HorizontalAlign.Start).margin({ left: 12 }).layoutWeight(1)
      }.width('100%').padding({ left: 18, right: 18, top: 15, bottom: 15 }).backgroundColor(themeSurface(this.darkMode))
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: item.topicId } }))
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(46).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('未读提醒').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
        Blank()
      }.height(64).width('100%').padding({ right: 8 }).backgroundColor(themeSurface(this.darkMode))
      if (this.loading) LoadingProgress().width(30).height(30).color(this.themeColor).margin({ top: 40 })
      else if (this.status.length > 0 && this.items.length === 0) Column() {
        Text(this.status).fontSize(15).fontColor('#7B8794')
        Button('打开登录').margin({ top: 16 }).backgroundColor(this.themeColor).fontColor(Color.White).onClick(() => router.pushUrl({ url: 'pages/Login' }))
      }.margin({ top: 42 }).alignItems(HorizontalAlign.Center)
      else {
        Refresh({ refreshing: this.loading }) {
          List({ space: 1 }) {
            ForEach(this.items, (item: V2exNotification) => this.row(item), (item: V2exNotification) => `${item.id}`)
            ListItem() {
              if (this.loadMoreStatus.length > 0) Text(this.loadMoreStatus).fontSize(13).fontColor('#8A97A6')
              if (!this.noMore) Button(this.loadingMore ? '加载中…' : '加载更多').fontSize(14).backgroundColor(this.themeColor).fontColor(Color.White).onClick(() => this.loadMore())
            }
          }.onReachEnd(() => this.loadMore())
            .layoutWeight(1).width('100%')
        }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => { if (state === RefreshStatus.Refresh) this.load(); })
      }
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
