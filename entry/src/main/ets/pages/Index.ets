import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { V2exMember, V2exNode, V2exTopic } from '../model/V2exModels';
import { applyThemeSystemBars, themeAccentText, themeMutedText, themeOnColor, themeSecondaryText } from '../common/Theme';

function relativeTime(unix: number): string {
  if (!unix) return '';
  const seconds: number = Math.max(1, Math.floor(Date.now() / 1000) - unix);
  if (seconds < 60) return `${seconds}秒前`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}分钟前`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}小时前`;
  return `${Math.floor(seconds / 86400)}天前`;
}

function localizedTopicTime(label: string | undefined, unix: number): string {
  if (!label || label.trim().length === 0) return relativeTime(unix);
  const value: string = label.trim();
  const minutes: RegExpMatchArray | null = value.match(/(\d+)\s*(?:mins?|minutes?|分钟)/i);
  if (minutes) return `${minutes[1]}分钟前`;
  const hours: RegExpMatchArray | null = value.match(/(\d+)\s*(?:hours?|小时)/i);
  if (hours) return `${hours[1]}小时前`;
  const days: RegExpMatchArray | null = value.match(/(\d+)\s*(?:days?|天)/i);
  if (days) return `${days[1]}天前`;
  if (/just now|刚刚/i.test(value)) return '刚刚';
  return relativeTime(unix);
}

interface HomeTabItem {
  title: string;
  key: string;
  type: string;
}

const DEFAULT_HOME_TABS: HomeTabItem[] = [
  { title: '最近', key: 'latest', type: 'latest' },
  { title: '最热', key: 'hot', type: 'hot' },
  { title: '技术', key: 'tech', type: 'tab' },
  { title: '创意', key: 'creative', type: 'tab' },
  { title: '好玩', key: 'play', type: 'tab' },
  { title: 'Apple', key: 'apple', type: 'tab' },
  { title: '酷工作', key: 'jobs', type: 'tab' },
  { title: '交易', key: 'deals', type: 'tab' },
  { title: '城市', key: 'city', type: 'tab' },
  { title: '问与答', key: 'qna', type: 'tab' },
  { title: '全部', key: 'all', type: 'tab' },
  { title: 'R2', key: 'r2', type: 'tab' },
  { title: 'VXNA', key: 'xna', type: 'xna' },
  { title: '节点', key: 'nodes', type: 'nodes' },
  { title: '关注', key: 'members', type: 'members' },
  { title: '刚更新', key: 'changes', type: 'tab' }
];

@Entry
@Component
struct Index {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exSafeAreaTop') safeAreaTop: number = 0;
  @StorageLink('v2exSafeAreaBottom') safeAreaBottom: number = 0;
  @StorageLink('v2exCachedMember') cachedMemberJson: string = '';
  @StorageLink('v2exAutoCheckin') autoCheckin: boolean = true;
  @StorageLink('v2exLastCheckinDate') lastCheckinDate: string = '';
  @StorageLink('v2exHomeTabs') homeTabsJson: string = JSON.stringify(DEFAULT_HOME_TABS);
  @StorageLink('v2exVisitedXna') visitedXnaJson: string = '[]';
  @State selectedTab: number = 0;
  @State loading: boolean = false;
  @State errorText: string = '';
  @State topics: V2exTopic[] = [];
  @State nodes: V2exNode[] = [];
  @State xnaTopics: V2exTopic[] = [];
  @State currentMember: V2exMember | undefined = undefined;
  @State memberLoading: boolean = false;
  @State drawerOpen: boolean = false;
  @State searchText: string = '';
  @State nodeQuery: string = '';
  @State tabs: HomeTabItem[] = DEFAULT_HOME_TABS.slice();
  @State topicPage: number = 1;
  @State loadingMoreTopics: boolean = false;
  @State noMoreTopics: boolean = false;

  aboutToAppear(): void {
    applyThemeSystemBars(this.darkMode);
    this.readHomeTabs();
    try {
      if (this.cachedMemberJson.trim().length > 0) this.currentMember = JSON.parse(this.cachedMemberJson) as V2exMember;
    } catch (_) { this.currentMember = undefined; }
    this.selectTab(0);
  }

  onPageShow(): void {
    applyThemeSystemBars(this.darkMode);
    // A page opened from the drawer can be popped without recreating Index.
    // Always restore the home screen with the drawer closed.
    this.drawerOpen = false;
    this.readHomeTabs();
    if (this.cachedMemberJson.trim().length === 0) {
      this.currentMember = undefined;
      if (!this.memberLoading) this.loadCurrentMember();
      return;
    }
    try {
      this.currentMember = JSON.parse(this.cachedMemberJson) as V2exMember;
    } catch (_) { this.currentMember = undefined; }
  }

  private readHomeTabs(): void {
    try {
      const parsed: HomeTabItem[] = JSON.parse(this.homeTabsJson) as HomeTabItem[];
      const valid: HomeTabItem[] = parsed.filter((item: HomeTabItem) => item && item.key && item.title);
      this.tabs = valid.length > 0 ? valid : DEFAULT_HOME_TABS.slice();
      if (this.selectedTab >= this.tabs.length) this.selectedTab = 0;
    } catch (_) { this.tabs = DEFAULT_HOME_TABS.slice(); this.selectedTab = 0; }
  }

  private activeTab(): HomeTabItem {
    return this.tabs[this.selectedTab] ?? DEFAULT_HOME_TABS[0];
  }

  private surface(): string { return this.darkMode ? '#18202A' : '#FFFFFF'; }
  private pageBackground(): string { return this.darkMode ? '#0F141A' : '#F5F7FA'; }
  private primaryText(): string { return this.darkMode ? '#F2F5F8' : '#202124'; }

  private isTopicTab(): boolean {
    const type: string = this.activeTab().type;
    return type === 'latest' || type === 'hot' || type === 'tab' || type === 'node' || type === 'members';
  }

  private async loadTopics(kind: 'latest' | 'hot'): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    this.errorText = '';
    this.topicPage = 1;
    this.noMoreTopics = false;
    try { this.topics = await V2exService.topics(kind, 1); }
    catch (_) { this.errorText = '暂时无法连接 V2EX，请稍后重试'; }
    finally { this.loading = false; }
  }

  private selectTab(index: number): void {
    this.selectedTab = index;
    this.topicPage = 1;
    this.noMoreTopics = false;
    const tab: HomeTabItem = this.activeTab();
    if (tab.type === 'latest') this.loadTopics('latest');
    else if (tab.type === 'hot') this.loadTopics('hot');
    else if (tab.type === 'nodes' && this.nodes.length === 0) this.loadNodes();
    else if (tab.type === 'xna' && this.xnaTopics.length === 0) this.loadXna();
    else if (tab.type === 'tab') this.loadTopicsForTab(tab.key, 1);
    else if (tab.type === 'members') this.loadTopicsForTab(tab.key, 1);
    else if (tab.type === 'node') this.loadTopicsForNode(tab.key);
  }

  private shiftTab(delta: number): void {
    const next: number = Math.max(0, Math.min(this.tabs.length - 1, this.selectedTab + delta));
    if (next !== this.selectedTab) this.selectTab(next);
  }

  private async loadTopicsForNode(name: string): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    this.errorText = '';
    try { this.topics = await V2exService.topicsForNode(name); }
    catch (_) { this.errorText = '节点内容加载失败，请稍后重试'; }
    finally { this.loading = false; }
  }

  private async loadTopicsForTab(name: string, page: number = 1): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    this.errorText = '';
    try { this.topics = await V2exService.topicsForTab(name, page); this.topicPage = page; }
    catch (_) { this.errorText = '板块内容加载失败，请稍后重试'; }
    finally { this.loading = false; }
  }

  private async loadMoreHomeTopics(): Promise<void> {
    if (this.loading || this.loadingMoreTopics || this.noMoreTopics || !this.isTopicTab()) return;
    const tab: HomeTabItem = this.activeTab();
    if (tab.type === 'nodes' || tab.type === 'xna') return;
    this.loadingMoreTopics = true;
    try {
      const nextPage: number = this.topicPage + 1;
      let next: V2exTopic[] = [];
      if (tab.type === 'hot') next = await V2exService.topics('hot', nextPage);
      else if (tab.type === 'latest') next = await V2exService.topics('latest', nextPage);
      else next = await V2exService.topicsForTab(tab.key, nextPage);
      const unique: V2exTopic[] = next.filter((item: V2exTopic) => this.topics.findIndex((old: V2exTopic) => old.id === item.id) < 0);
      if (unique.length === 0) this.noMoreTopics = true;
      else { this.topics = this.topics.concat(unique); this.topicPage = nextPage; }
    } catch (_) { /* retain the current page on transient failures */ }
    finally { this.loadingMoreTopics = false; }
  }

  private visibleTopics(): V2exTopic[] {
    const query: string = this.searchText.trim().toLowerCase();
    let blocked: string[] = [];
    try { blocked = JSON.parse(AppStorage.get<string>('v2exBlockedKeywords') ?? '[]') as string[]; } catch (_) { blocked = []; }
    return this.topics.filter((topic: V2exTopic) => {
      const text: string = `${topic.title} ${topic.content ?? ''}`.toLowerCase();
      if (blocked.some((value: string) => value.length > 0 && text.includes(value.toLowerCase()))) return false;
      if (query.length === 0) return true;
      return topic.title.toLowerCase().includes(query) || (topic.content ?? '').toLowerCase().includes(query) ||
        (topic.member?.username ?? '').toLowerCase().includes(query) || (topic.node?.title ?? '').toLowerCase().includes(query);
    });
  }

  private async loadNodes(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try { this.nodes = await V2exService.nodes(); }
    catch (_) { this.errorText = '节点加载失败，请稍后重试'; }
    finally { this.loading = false; }
  }

  private async loadXna(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try { this.xnaTopics = await V2exService.xnaTopics(); }
    catch (_) { this.errorText = 'VXNA 加载失败，请稍后重试'; }
    finally { this.loading = false; }
  }

  private async loadCurrentMember(): Promise<void> {
    this.memberLoading = true;
    try {
      const member: V2exMember | undefined = await V2exService.currentMember();
      this.currentMember = member;
      this.cachedMemberJson = member ? JSON.stringify(member) : '';
      if (member) this.maybeCheckin();
    }
    catch (_) {
      // Keep a cached profile visible during a transient network failure. A
      // successful authenticated check above is the only event that clears it.
    }
    finally { this.memberLoading = false; }
  }

  private async maybeCheckin(): Promise<void> {
    const today: string = new Date().toISOString().substring(0, 10);
    if (!this.autoCheckin || this.lastCheckinDate === today) return;
    try {
      const ok: boolean = await V2exService.checkin();
      if (ok) this.lastCheckinDate = today;
    } catch (_) { /* automatic check-in must not block the home screen */ }
  }

  private visibleNodes(): V2exNode[] {
    const query: string = this.nodeQuery.trim().toLowerCase();
    if (query.length === 0) return this.nodes;
    return this.nodes.filter((node: V2exNode) => node.title.toLowerCase().includes(query) || node.name.toLowerCase().includes(query));
  }

  private async searchRemote(): Promise<void> {
    const query: string = this.searchText.trim();
    if (query.length === 0) return;
    this.loading = true;
    this.errorText = '';
    try {
      this.topics = await V2exService.searchTopics(query);
      if (this.topics.length === 0) this.errorText = '没有找到匹配主题';
    } catch (_) {
      this.errorText = '搜索失败，请稍后重试';
    } finally {
      this.loading = false;
    }
  }

  @Builder
  topicCard(topic: V2exTopic) {
    ListItem() {
      Column() {
        Row() {
          Stack() {
            Text((topic.member?.username ?? '?').substring(0, 1).toUpperCase()).fontSize(13).fontColor(Color.White)
              .width(26).height(26).textAlign(TextAlign.Center).backgroundColor(this.darkMode ? '#435466' : '#B7C4D2').borderRadius(13)
            if (topic.member?.avatar_large) {
              Image(topic.member.avatar_large).width(26).height(26).borderRadius(13).objectFit(ImageFit.Cover)
            }
          }.onClick(() => { if (topic.member?.username) router.pushUrl({ url: 'pages/Profile', params: { username: topic.member.username } }); })
            .hitTestBehavior(HitTestMode.Block)
          Column() {
            Text(topic.member?.username ?? '匿名').fontSize(12).fontColor(themeMutedText(this.darkMode))
              .onClick(() => { if (topic.member?.username) router.pushUrl({ url: 'pages/Profile', params: { username: topic.member.username } }); })
              .hitTestBehavior(HitTestMode.Block)
            Text(`${localizedTopicTime(topic.lastTouchedLabel, topic.last_touched)} · ${topic.replies} 回复`).fontSize(11).fontColor(themeMutedText(this.darkMode)).margin({ top: 3 })
          }.alignItems(HorizontalAlign.Start).margin({ left: 8 })
          Blank()
          Text(topic.node?.title ?? topic.node?.name ?? 'V2EX').fontSize(12).fontColor(themeAccentText(this.themeColor, this.darkMode))
        }.width('100%').margin({ bottom: 8 })
        Row() {
          Text(topic.title).fontSize(16).fontColor(this.primaryText()).fontWeight(FontWeight.Medium)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        }.width('100%').alignItems(VerticalAlign.Top)
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 12, bottom: 12 }).backgroundColor(this.surface())
    }.onClick(() => {
      if (topic.url && !/\/t\/\d+/i.test(topic.url)) {
        router.pushUrl({ url: 'pages/WebViewPage', params: { title: topic.title, url: topic.url } });
      } else {
        router.pushUrl({ url: 'pages/TopicDetail', params: { id: topic.id } });
      }
    })
  }

  private visitedXna(): string[] {
    try { return JSON.parse(this.visitedXnaJson) as string[]; } catch (_) { return []; }
  }

  private openXna(topic: V2exTopic): void {
    const url: string = topic.url ?? '';
    const visited: string[] = this.visitedXna().filter((item: string) => item !== url);
    this.visitedXnaJson = JSON.stringify([url].concat(visited).slice(0, 100));
    router.pushUrl({ url: 'pages/WebViewPage', params: { title: topic.title, url } });
  }

  @Builder
  xnaCard(topic: V2exTopic) {
    ListItem() {
      Row() {
        Stack() {
          Text((topic.member?.username ?? '?').substring(0, 1).toUpperCase()).fontSize(12).fontColor(Color.White)
            .width(26).height(26).textAlign(TextAlign.Center).backgroundColor(this.darkMode ? '#435466' : '#B7C4D2').borderRadius(13)
          if (topic.member?.avatar_large) Image(topic.member.avatar_large).width(26).height(26).borderRadius(13).objectFit(ImageFit.Cover)
        }.onClick(() => { if (topic.member?.username) router.pushUrl({ url: 'pages/Profile', params: { username: topic.member.username } }); })
          .hitTestBehavior(HitTestMode.Block)
        Column() {
          Row() {
            Text(topic.member?.username ?? '匿名').fontSize(13).fontColor(this.visitedXna().indexOf(topic.url ?? '') >= 0 ? themeSecondaryText(this.darkMode) : this.primaryText())
            if (topic.node?.title) {
              Text(topic.node.title).fontSize(11).fontColor(themeAccentText(this.themeColor, this.darkMode))
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .backgroundColor(this.darkMode ? '#26313D' : '#EEF3F8').borderRadius(8).margin({ left: 8 })
            }
          }.width('100%')
          Text(topic.title).fontSize(15).fontColor(this.visitedXna().indexOf(topic.url ?? '') >= 0 ? themeSecondaryText(this.darkMode) : this.primaryText())
            .fontWeight(FontWeight.Medium).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 3 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 10 })
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 }).backgroundColor(this.surface())
    }.onClick(() => this.openXna(topic))
  }

  build() {
    Stack() {
      Column() {
      Row() {
        Button() {
          Image($r('app.media.ic_menu')).width(24).height(24).fillColor(themeAccentText(this.themeColor, this.darkMode))
        }.width(56).height(64).backgroundColor(Color.Transparent).onClick(() => this.drawerOpen = true)
        Text('V2EX').fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.primaryText())
        Blank()
        Stack() {
          Image($r('app.media.ic_nodes')).width(25).height(25).fillColor(themeAccentText(this.themeColor, this.darkMode))
        }.width(56).height(64).align(Alignment.Center).onClick(() => router.pushUrl({ url: 'pages/NavNodes' }))
        Stack() {
          Image($r('app.media.ic_mail')).width(24).height(24).fillColor(themeAccentText(this.themeColor, this.darkMode))
        }.width(56).height(64).onClick(() => router.pushUrl({ url: 'pages/Notifications' }))
        Stack() {
          Image($r('app.media.ic_edit')).width(24).height(24).fillColor(themeAccentText(this.themeColor, this.darkMode))
        }.width(56).height(64).onClick(() => router.pushUrl({ url: 'pages/WriteTopic' }))
      }.width('100%').height(64).padding({ left: 20, right: 20 }).backgroundColor(this.surface())
      Row() {
        TextInput({ placeholder: '搜索主题、节点或用户', text: this.searchText })
          .layoutWeight(1).height(42).fontSize(14).fontColor(this.primaryText()).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(this.darkMode ? '#26313D' : '#F1F4F7')
          .onChange((value: string) => this.searchText = value)
          .onSubmit(() => this.searchRemote())
        Stack() {
          Image($r('app.media.ic_search')).width(24).height(24).fillColor(themeAccentText(this.themeColor, this.darkMode))
        }.width(48).height(42).onClick(() => router.pushUrl({ url: 'pages/Search', params: { query: this.searchText } }))
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 }).backgroundColor(this.surface())
      Row() {
        Scroll() {
          Row() {
            ForEach(this.tabs, (tab: HomeTabItem, index: number) => {
              Column() {
                Text(tab.title).fontSize(15).fontColor(this.selectedTab === index ? themeAccentText(this.themeColor, this.darkMode) : themeSecondaryText(this.darkMode))
                  .maxLines(1)
                Row().height(3).width(28).backgroundColor(this.selectedTab === index ? this.themeColor : Color.Transparent)
                  .borderRadius(2).margin({ top: 7 })
              }.alignItems(HorizontalAlign.Center).padding({ left: 11, right: 11, top: 10, bottom: 0 })
                .onClick(() => this.selectTab(index))
            }, (tab: HomeTabItem) => tab.key)
          }.alignItems(VerticalAlign.Bottom)
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).layoutWeight(1).height('100%')
          .align(Alignment.Start)
        Stack() {
          Image($r('app.media.ic_menu')).width(18).height(18).fillColor(themeAccentText(this.themeColor, this.darkMode))
        }.width(48).height('100%').backgroundColor(this.surface()).onClick(() => router.pushUrl({ url: 'pages/HomeTabs' }))
      }.width('100%').height(52).backgroundColor(this.surface())
      if (this.isTopicTab() && this.loading && this.topics.length === 0) {
        LoadingProgress().width(28).height(28).color(themeAccentText(this.themeColor, this.darkMode)).margin({ top: 36 })
      } else if (this.isTopicTab() && this.errorText.length > 0 && this.topics.length === 0) {
        Column() { Text(this.errorText).fontSize(15).fontColor(themeSecondaryText(this.darkMode)); Text('点击重试').fontSize(14).fontColor(themeAccentText(this.themeColor, this.darkMode)).margin({ top: 14 }).onClick(() => {
          const tab: HomeTabItem = this.activeTab();
          if (tab.type === 'hot') this.loadTopics('hot');
          else if (tab.type === 'tab') this.loadTopicsForTab(tab.key);
          else if (tab.type === 'members') this.loadTopicsForTab(tab.key);
          else if (tab.type === 'node') this.loadTopicsForNode(tab.key);
          else this.loadTopics('latest');
        }); }
          .margin({ top: 42 }).alignItems(HorizontalAlign.Center)
      } else if (this.activeTab().type === 'nodes') {
        Column() {
          Text('节点浏览').fontSize(20).fontWeight(FontWeight.Medium).fontColor(this.primaryText()).margin({ top: 18, bottom: 12 })
          TextInput({ placeholder: '搜索节点', text: this.nodeQuery }).width('92%').height(44).fontSize(14).fontColor(this.primaryText()).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(this.darkMode ? '#26313D' : '#F1F4F7')
            .onChange((value: string) => this.nodeQuery = value).margin({ bottom: 10 })
          Refresh({ refreshing: this.loading }) {
            List({ space: 1 }) {
              ForEach(this.visibleNodes(), (node: V2exNode) => ListItem() {
                Row() { Text(node.title).fontSize(16).fontColor(this.primaryText()); Blank(); Text(node.name).fontSize(13).fontColor(themeMutedText(this.darkMode)) }
                  .width('100%').padding({ left: 20, right: 20, top: 15, bottom: 15 }).backgroundColor(this.surface())
                  .onClick(() => router.pushUrl({ url: 'pages/NodeTopics', params: { name: node.name, title: node.title } }))
              }, (node: V2exNode) => node.name)
            }.layoutWeight(1).width('100%')
          }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => { if (state === RefreshStatus.Refresh) this.loadNodes(); })
        }.layoutWeight(1).width('100%')
      } else if (this.activeTab().type === 'xna') {
        if (this.xnaTopics.length === 0 && !this.loading) {
          Text('暂无 VXNA 内容').fontSize(15).fontColor(themeSecondaryText(this.darkMode)).margin({ top: 48 })
        } else {
          Refresh({ refreshing: this.loading }) {
            List({ space: 1 }) { ForEach(this.xnaTopics, (topic: V2exTopic) => this.xnaCard(topic), (topic: V2exTopic) => `${topic.id}`) }
              .layoutWeight(1).width('100%').divider({ strokeWidth: 1, color: this.darkMode ? '#27313B' : '#EEF1F4' })
          }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => { if (state === RefreshStatus.Refresh) this.loadXna(); })
        }
      } else {
        Refresh({ refreshing: this.loading }) {
          List({ space: 1 }) { ForEach(this.visibleTopics(), (topic: V2exTopic) => this.topicCard(topic), (topic: V2exTopic) => `${topic.id}`) }
            .onReachEnd(() => this.loadMoreHomeTopics())
            .onScrollIndex((_start: number, end: number) => { if (end >= this.visibleTopics().length - 2) this.loadMoreHomeTopics(); })
            .layoutWeight(1).width('100%').divider({ strokeWidth: 1, color: this.darkMode ? '#27313B' : '#EEF1F4' })
        }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => {
          if (state === RefreshStatus.Refresh) {
            const tab: HomeTabItem = this.activeTab();
            if (tab.type === 'hot') this.loadTopics('hot');
            else if (tab.type === 'tab') this.loadTopicsForTab(tab.key);
            else if (tab.type === 'members') this.loadTopicsForTab(tab.key);
            else if (tab.type === 'node') this.loadTopicsForNode(tab.key);
            else this.loadTopics('latest');
          }
        })
      }
    }.width('100%').height('100%').padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom }).backgroundColor(this.pageBackground())
      if (this.drawerOpen) {
        Row() {
          Column() {
            if (this.currentMember) {
              Column() {
                Row() {
                  Stack() {
                    Text(this.currentMember.username.substring(0, 1).toUpperCase()).fontSize(14).fontColor(Color.White)
                      .width(40).height(40).textAlign(TextAlign.Center).backgroundColor(this.darkMode ? '#435466' : '#B7C4D2').borderRadius(20)
                    if (this.currentMember.avatar_large) Image(this.currentMember.avatar_large).width(40).height(40).borderRadius(20).objectFit(ImageFit.Cover)
                  }
                  Blank()
                  Text('个人主页 ›').fontSize(14).fontColor(themeSecondaryText(this.darkMode))
                }
                  .width('100%').onClick(() => {
                    this.drawerOpen = false;
                    router.pushUrl({ url: 'pages/Profile', params: { username: this.currentMember?.username ?? '' } });
                  })
                Text(this.currentMember.username).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.primaryText())
                  .margin({ top: 8 }).width('100%')
              }.width('100%').padding({ left: 20, right: 20, top: 32, bottom: 20 }).backgroundColor(this.surface())
            } else {
              Text('点我登录 ›').fontSize(20).fontWeight(FontWeight.Medium).fontColor(themeAccentText(this.themeColor, this.darkMode)).width('100%')
                .padding({ left: 20, right: 20, top: 24, bottom: 18 }).backgroundColor(this.surface())
                .onClick(() => { this.drawerOpen = false; router.pushUrl({ url: 'pages/Login' }); })
            }
            Column() {
              if (this.currentMember) {
                this.drawerItem('节点收藏', 'MyNodes')
                this.drawerItem('主题收藏', 'Favorites')
                this.drawerItem('特别关注', 'MyFollowing')
                this.drawerItem('未读提醒', 'Notifications')
              }
              this.drawerItem('历史最热', 'HotestTopics')
              this.drawerItem('最近浏览', 'RecentTopic')
              Row() {
                Text('夜间模式').fontSize(16).fontColor(this.primaryText()).layoutWeight(1)
                Button(this.darkMode ? '已开启' : '已关闭').fontSize(13).backgroundColor(this.themeColor)
                  .fontColor(themeOnColor(this.themeColor)).onClick(() => { this.darkMode = !this.darkMode; applyThemeSystemBars(this.darkMode); })
              }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 }).backgroundColor(this.surface()).margin({ top: 1 })
              this.drawerItem('更多选项', 'Settings')
            }.width('100%')
          }.width(300).height('100%').padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom }).backgroundColor(this.pageBackground())
          Blank().layoutWeight(1).height('100%').backgroundColor('#88000000').onClick(() => this.drawerOpen = false)
        }.width('100%').height('100%')
      }
    }.width('100%').height('100%')
      .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 48 })
        .onActionEnd((event: GestureEvent) => {
          if (this.drawerOpen || Math.abs(event.offsetX) < 80) return;
          this.shiftTab(event.offsetX < 0 ? 1 : -1);
        }))
  }

  @Builder
  drawerItem(label: string, page: string) {
    Row() {
      Text(label).fontSize(16).fontColor(this.primaryText()).layoutWeight(1)
      Text('›').fontSize(22).fontColor(themeMutedText(this.darkMode))
    }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 16 }).backgroundColor(this.surface()).margin({ top: 1 })
      .onClick(() => this.openDrawerPage(page))
  }

  private openDrawerPage(page: string): void {
    this.drawerOpen = false;
    if (page === 'Profile') {
      if (this.currentMember) router.pushUrl({ url: 'pages/Profile', params: { username: this.currentMember.username } });
      else router.pushUrl({ url: 'pages/Login' });
    } else {
      router.pushUrl({ url: `pages/${page}` });
    }
  }
}
