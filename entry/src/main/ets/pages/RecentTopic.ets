import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { V2exTopic } from '../model/V2exModels';
import { themeBackground, themeInputBackground, themePrimaryText, themeSurface } from '../common/Theme';

@Entry
@Component
struct RecentTopic {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exRecentTopicIds') recentJson: string = '[]';
  @StorageLink('v2exRecentTopicsCache') cacheJson: string = '[]';
  @State topics: V2exTopic[] = [];
  @State loading: boolean = true;
  @State status: string = '';
  @State query: string = '';
  private loadedRecentJson: string = '';

  aboutToAppear(): void {
    this.restoreCache();
    this.loadedRecentJson = this.recentJson;
    this.load();
  }

  onPageShow(): void {
    // A topic detail updates recentJson. Refresh only when that list changed;
    // simply returning to this page should keep the cached list on screen.
    if (this.loadedRecentJson !== this.recentJson) this.load();
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
    try {
      const ids: number[] = JSON.parse(this.recentJson) as number[];
      const results: Array<V2exTopic | undefined> = await Promise.all(ids.map(async (id: number): Promise<V2exTopic | undefined> => {
        try { return await V2exService.topic(id); } catch (_) { return undefined; }
      }));
      const loaded: V2exTopic[] = [];
      results.forEach((topic: V2exTopic | undefined) => {
        if (topic) loaded.push(topic);
      });
      this.topics = loaded;
      this.loadedRecentJson = this.recentJson;
      this.cacheJson = JSON.stringify(loaded);
      if (this.topics.length === 0) this.status = '暂无浏览记录';
    } catch (_) {
      if (!hasCached) this.status = '浏览记录读取失败';
    }
    finally { this.loading = false; }
  }

  private clearAll(): void {
    this.recentJson = '[]';
    this.cacheJson = '[]';
    this.topics = [];
    this.query = '';
    this.status = '暂无浏览记录';
    this.loadedRecentJson = this.recentJson;
    this.loading = false;
  }

  private visibleTopics(): V2exTopic[] {
    const text: string = this.query.trim().toLowerCase();
    if (text.length === 0) return this.topics;
    return this.topics.filter((topic: V2exTopic) =>
      topic.title.toLowerCase().includes(text) || (topic.member?.username ?? '').toLowerCase().includes(text));
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
          Text(topic.member?.username ?? '匿名').fontSize(12).fontColor('#8A97A6')
          Text(topic.title).fontSize(16).fontColor(themePrimaryText(this.darkMode)).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
          Text(`${topic.node?.title ?? 'V2EX'} · ${topic.replies} 回复`).fontSize(12).fontColor('#8A97A6').margin({ top: 5 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 10 })
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 }).backgroundColor(themeSurface(this.darkMode))
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: topic.id } }))
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(46).textAlign(TextAlign.Center).onClick(() => router.back())
        TextInput({ placeholder: '搜索最近浏览主题', text: this.query }).layoutWeight(1).height(40).fontSize(14)
          .backgroundColor(themeInputBackground(this.darkMode)).borderRadius(8).padding({ left: 12, right: 12 }).margin({ right: 10 })
          .onChange((value: string) => this.query = value)
        Text('✕').fontSize(18).fontColor('#7B8794').width(42).height(40).textAlign(TextAlign.Center)
          .onClick(() => this.clearAll())
      }.height(64).width('100%').padding({ left: 16, right: 12 }).backgroundColor(themeSurface(this.darkMode))
      if (this.loading) LoadingProgress().width(30).height(30).color(this.themeColor).margin({ top: 40 })
      else if (this.status.length > 0) Text(this.status).fontSize(15).fontColor('#7B8794').margin({ top: 42 })
      else {
        Refresh({ refreshing: this.loading }) {
          List({ space: 1 }) { ForEach(this.visibleTopics(), (topic: V2exTopic) => this.row(topic), (topic: V2exTopic) => `${topic.id}`) }
            .layoutWeight(1).width('100%')
        }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => { if (state === RefreshStatus.Refresh) this.load(); })
      }
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
