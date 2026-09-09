import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { V2exTopic } from '../model/V2exModels';
import { themeBackground, themeMutedText, themePrimaryText, themeSecondaryText, themeSurface, themeOnColor } from '../common/Theme';

@Entry
@Component
struct Favorites {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exFavoritesCache') cacheJson: string = '[]';
  @State topics: V2exTopic[] = [];
  @State loading: boolean = true;
  @State status: string = '';
  @State page: number = 1;
  @State loadingMore: boolean = false;
  @State noMore: boolean = false;
  @State loadMoreStatus: string = '';

  aboutToAppear(): void {
    this.restoreCache();
    this.load();
  }

  private restoreCache(): void {
    try {
      const cached: V2exTopic[] = JSON.parse(this.cacheJson) as V2exTopic[];
      if (Array.isArray(cached) && cached.length > 0) {
        this.topics = cached;
        this.loading = false;
      }
    } catch (_) { /* corrupt cache is ignored */ }
  }

  private async load(): Promise<void> {
    const hasCached: boolean = this.topics.length > 0;
    this.loading = !hasCached;
    this.status = '';
    this.page = 1;
    this.noMore = false;
    this.loadMoreStatus = '';
    try {
      const fresh: V2exTopic[] = await V2exService.myFavorites(1);
      this.topics = fresh;
      this.cacheJson = JSON.stringify(fresh);
      if (this.topics.length === 0) this.status = '暂无收藏或尚未登录';
    } catch (_) {
      if (!hasCached) this.status = '请先登录 V2EX';
    }
    finally { this.loading = false; }
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore || this.noMore) return;
    this.loadingMore = true;
    try {
      const next: V2exTopic[] = await V2exService.myFavorites(this.page + 1);
      const unique: V2exTopic[] = next.filter((topic: V2exTopic) => this.topics.findIndex((item: V2exTopic) => item.id === topic.id) < 0);
      if (unique.length === 0) { this.noMore = true; this.loadMoreStatus = '没有更多收藏'; }
      else {
        this.topics = this.topics.concat(unique);
        this.cacheJson = JSON.stringify(this.topics);
        this.page += 1;
        this.loadMoreStatus = '';
      }
    } catch (_) { this.loadMoreStatus = '加载更多失败'; }
    finally { this.loadingMore = false; }
  }

  @Builder
  row(topic: V2exTopic) {
    ListItem() {
      Row() {
          Stack() {
            Text((topic.member?.username ?? '?').substring(0, 1).toUpperCase()).fontSize(12).fontColor(Color.White)
              .width(26).height(26).textAlign(TextAlign.Center).backgroundColor(this.darkMode ? '#435466' : '#B7C4D2').borderRadius(13)
            if (topic.member?.avatar_large) Image(topic.member.avatar_large).width(26).height(26).borderRadius(13).objectFit(ImageFit.Cover)
          }.onClick(() => { if (topic.member?.username) router.pushUrl({ url: 'pages/Profile', params: { username: topic.member.username } }); })
            .hitTestBehavior(HitTestMode.Block)
        Column() {
            Text(topic.member?.username ?? '匿名').fontSize(12).fontColor(themeMutedText(this.darkMode))
          Text(topic.title).fontSize(16).fontColor(themePrimaryText(this.darkMode)).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
          Text(`${topic.node?.title ?? 'V2EX'} · ${topic.replies} 回复`).fontSize(12).fontColor(themeMutedText(this.darkMode)).margin({ top: 5 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 10 })
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 }).backgroundColor(themeSurface(this.darkMode))
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: topic.id } }))
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(46).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('主题收藏').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
        Blank()
      }.height(64).width('100%').padding({ right: 8 }).backgroundColor(themeSurface(this.darkMode))
      if (this.loading) LoadingProgress().width(30).height(30).color(this.themeColor).margin({ top: 40 })
      else if (this.status.length > 0 && this.topics.length === 0) Column() {
        Text(this.status).fontSize(15).fontColor(themeSecondaryText(this.darkMode))
        Button('打开登录').margin({ top: 16 }).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => router.pushUrl({ url: 'pages/Login' }))
      }.margin({ top: 42 }).alignItems(HorizontalAlign.Center)
      else {
        Refresh({ refreshing: this.loading }) {
          List({ space: 1 }) {
            ForEach(this.topics, (topic: V2exTopic) => this.row(topic), (topic: V2exTopic) => `${topic.id}`)
            ListItem() {
              if (this.loadMoreStatus.length > 0) Text(this.loadMoreStatus).fontSize(13).fontColor(themeMutedText(this.darkMode))
              if (!this.noMore) Button(this.loadingMore ? '加载中…' : '加载更多').fontSize(14).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.loadMore())
            }
          }.onReachEnd(() => this.loadMore())
            .layoutWeight(1).width('100%')
        }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => { if (state === RefreshStatus.Refresh) this.load(); })
      }
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
