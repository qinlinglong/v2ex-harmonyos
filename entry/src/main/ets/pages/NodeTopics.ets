import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { V2exTopic } from '../model/V2exModels';
import { themeAccentText, themeMutedText, themeSecondaryText, themeOnColor } from '../common/Theme';

function age(unix: number): string {
  if (!unix) return '';
  const seconds: number = Math.max(1, Math.floor(Date.now() / 1000) - unix);
  if (seconds < 3600) return `${Math.floor(seconds / 60)}分钟前`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}小时前`;
  return `${Math.floor(seconds / 86400)}天前`;
}

@Entry
@Component
struct NodeTopics {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exNodeTopicsCache') cacheJson: string = '{}';
  @State name: string = '';
  @State title: string = '';
  @State topics: V2exTopic[] = [];
  @State loading: boolean = true;
  @State status: string = '';
  @State page: number = 1;
  @State loadingMore: boolean = false;
  @State noMore: boolean = false;
  @State loadMoreStatus: string = '';
  @State nodeFavorited: boolean = false;
  @State actionStatus: string = '';
  private surface(): string { return this.darkMode ? '#18202A' : '#FFFFFF'; }
  private pageBackground(): string { return this.darkMode ? '#0F141A' : '#F5F7FA'; }
  private primaryText(): string { return this.darkMode ? '#F2F5F8' : '#202124'; }

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    this.name = String(params?.['name'] ?? '');
    this.title = String(params?.['title'] ?? this.name);
    this.restoreCache();
    this.load();
  }

  private restoreCache(): void {
    if (this.name.length === 0) return;
    try {
      const cache: Record<string, V2exTopic[]> = JSON.parse(this.cacheJson) as Record<string, V2exTopic[]>;
      const cached: V2exTopic[] | undefined = cache[this.name];
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
      const results: [V2exTopic[], boolean] = await Promise.all([
        V2exService.topicsForNode(this.name), V2exService.nodeFavorited(this.name)
      ]);
      this.topics = results[0];
      this.nodeFavorited = results[1];
      try {
        const cache: Record<string, V2exTopic[]> = JSON.parse(this.cacheJson) as Record<string, V2exTopic[]>;
        cache[this.name] = this.topics;
        this.cacheJson = JSON.stringify(cache);
      } catch (_) { /* cache failures do not affect the page */ }
      if (this.topics.length === 0) this.status = '该节点暂无主题';
    } catch (_) {
      if (!hasCached) this.status = '节点主题加载失败';
    } finally {
      this.loading = false;
    }
  }

  private async loadMore(): Promise<void> {
    if (this.loading || this.loadingMore || this.noMore) return;
    this.loadingMore = true;
    try {
      const next: V2exTopic[] = await V2exService.topicsForNodePage(this.name, this.page + 1);
      const unique: V2exTopic[] = next.filter((topic: V2exTopic) => this.topics.findIndex((item: V2exTopic) => item.id === topic.id) < 0);
      if (unique.length === 0) {
        this.noMore = true;
        this.loadMoreStatus = '没有更多主题';
      } else {
        this.topics = this.topics.concat(unique);
        try {
          const cache: Record<string, V2exTopic[]> = JSON.parse(this.cacheJson) as Record<string, V2exTopic[]>;
          cache[this.name] = this.topics;
          this.cacheJson = JSON.stringify(cache);
        } catch (_) { /* cache failures do not affect the page */ }
        this.page += 1;
        this.loadMoreStatus = '';
      }
    } catch (_) { this.loadMoreStatus = '加载更多失败'; }
    finally { this.loadingMore = false; }
  }

  private async toggleFavorite(): Promise<void> {
    try {
      const ok: boolean = await V2exService.nodeAction(this.name, this.nodeFavorited ? 'unfavorite' : 'favorite');
      this.actionStatus = ok ? (this.nodeFavorited ? '已取消收藏' : '已收藏') : '请先登录';
      if (ok) this.nodeFavorited = !this.nodeFavorited;
    } catch (_) { this.actionStatus = '操作失败，请稍后重试'; }
  }

  @Builder
  topicRow(topic: V2exTopic) {
    ListItem() {
      Row() {
          Stack() {
            Text((topic.member?.username ?? '?').substring(0, 1).toUpperCase())
              .fontSize(12).fontColor(Color.White).width(26).height(26).textAlign(TextAlign.Center)
              .backgroundColor(this.darkMode ? '#435466' : '#B7C4D2').borderRadius(13)
          if (topic.member?.avatar_large) Image(topic.member.avatar_large).width(26).height(26)
            .borderRadius(13).objectFit(ImageFit.Cover)
          }.onClick(() => { if (topic.member?.username) router.pushUrl({ url: 'pages/Profile', params: { username: topic.member.username } }); })
            .hitTestBehavior(HitTestMode.Block)
        Column() {
          Text(topic.member?.username ?? '匿名').fontSize(12).fontColor(themeMutedText(this.darkMode))
          Text(topic.title).fontSize(16).fontColor(this.primaryText()).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 3 })
          Text(`${age(topic.last_touched)} · ${topic.replies} 回复`)
            .fontSize(12).fontColor(themeMutedText(this.darkMode)).margin({ top: 5 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 10 })
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor(this.surface())
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: topic.id } }))
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(themeAccentText(this.themeColor, this.darkMode)).width(46).textAlign(TextAlign.Center)
          .onClick(() => router.back())
        Column() {
          Text(titleOrName(this.title, this.name)).fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.primaryText())
          Text(this.name).fontSize(12).fontColor(themeMutedText(this.darkMode)).margin({ top: 2 })
        }.alignItems(HorizontalAlign.Start)
        Blank()
        Text(this.nodeFavorited ? '★' : '☆').fontSize(24).fontColor(themeAccentText(this.themeColor, this.darkMode)).width(46).textAlign(TextAlign.Center).onClick(() => this.toggleFavorite())
      }.height(64).width('100%').padding({ right: 8 }).backgroundColor(this.surface())
      if (this.actionStatus.length > 0) Text(this.actionStatus).fontSize(12).fontColor(themeAccentText(this.themeColor, this.darkMode)).margin({ top: 8 })
      if (this.loading) {
        LoadingProgress().width(30).height(30).color(themeAccentText(this.themeColor, this.darkMode)).margin({ top: 36 })
      } else if (this.status.length > 0 && this.topics.length === 0) {
        Column() {
          Text(this.status).fontSize(15).fontColor(themeSecondaryText(this.darkMode))
          Text('点击重试').fontSize(14).fontColor(themeAccentText(this.themeColor, this.darkMode)).margin({ top: 12 }).onClick(() => this.load())
        }.margin({ top: 42 }).alignItems(HorizontalAlign.Center)
      } else {
        Refresh({ refreshing: this.loading }) {
          List({ space: 1 }) {
            ForEach(this.topics, (topic: V2exTopic) => this.topicRow(topic), (topic: V2exTopic) => `${topic.id}`)
            ListItem() {
              if (this.loadMoreStatus.length > 0) Text(this.loadMoreStatus).fontSize(13).fontColor(themeMutedText(this.darkMode))
              if (!this.noMore) Button(this.loadingMore ? '加载中…' : '加载更多').fontSize(14).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.loadMore())
            }.width('100%').padding(18).align(Alignment.Center)
            }.layoutWeight(1).width('100%').onReachEnd(() => this.loadMore())
              .onScrollIndex((_start: number, end: number) => { if (end >= this.topics.length - 2) this.loadMore(); })
        }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => {
          if (state === RefreshStatus.Refresh) this.load();
        })
      }
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(this.pageBackground())
  }
}

function titleOrName(title: string, name: string): string {
  return title.length > 0 ? title : (name.length > 0 ? name : '节点主题');
}
