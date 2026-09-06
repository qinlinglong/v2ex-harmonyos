import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { V2exMember, V2exNode, V2exTopic } from '../model/V2exModels';

function relativeTime(unix: number): string {
  if (!unix) return '';
  const seconds: number = Math.max(1, Math.floor(Date.now() / 1000) - unix);
  if (seconds < 60) return `${seconds}秒前`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}分钟前`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}小时前`;
  return `${Math.floor(seconds / 86400)}天前`;
}

interface HomeTabItem {
  title: string;
  key: string;
  type: string;
}

const DEFAULT_HOME_TABS: HomeTabItem[] = [
  { title: '最近', key: 'latest', type: 'latest' },
  { title: '最热', key: 'hot', type: 'hot' },
  { title: '节点', key: 'nodes', type: 'nodes' },
  { title: '我的', key: 'mine', type: 'mine' },
  { title: 'XNA', key: 'xna', type: 'xna' }
];

@Entry
@Component
struct Index {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exCachedMember') cachedMemberJson: string = '';
  @StorageLink('v2exAutoCheckin') autoCheckin: boolean = true;
  @StorageLink('v2exLastCheckinDate') lastCheckinDate: string = '';
  @StorageLink('v2exHomeTabs') homeTabsJson: string = JSON.stringify(DEFAULT_HOME_TABS);
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

  aboutToAppear(): void {
    this.readHomeTabs();
    try {
      if (this.cachedMemberJson.trim().length > 0) this.currentMember = JSON.parse(this.cachedMemberJson) as V2exMember;
    } catch (_) { this.currentMember = undefined; }
    this.selectTab(0);
  }

  onPageShow(): void {
    this.readHomeTabs();
    if (this.cachedMemberJson.trim().length === 0) {
      this.currentMember = undefined;
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

  private isTopicTab(): boolean {
    const type: string = this.activeTab().type;
    return type === 'latest' || type === 'hot' || type === 'node';
  }

  private async loadTopics(kind: 'latest' | 'hot'): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    this.errorText = '';
    try { this.topics = await V2exService.topics(kind); }
    catch (_) { this.errorText = '暂时无法连接 V2EX，请稍后重试'; }
    finally { this.loading = false; }
  }

  private selectTab(index: number): void {
    this.selectedTab = index;
    const tab: HomeTabItem = this.activeTab();
    if (tab.type === 'latest') this.loadTopics('latest');
    else if (tab.type === 'hot') this.loadTopics('hot');
    else if (tab.type === 'nodes' && this.nodes.length === 0) this.loadNodes();
    else if (tab.type === 'mine' && !this.currentMember && !this.memberLoading) this.loadCurrentMember();
    else if (tab.type === 'xna' && this.xnaTopics.length === 0) this.loadXna();
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
    catch (_) { this.errorText = 'XNA 加载失败，请稍后重试'; }
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
              .width(30).height(30).textAlign(TextAlign.Center).backgroundColor('#B7C4D2').borderRadius(15)
            if (topic.member?.avatar_large) {
              Image(topic.member.avatar_large).width(30).height(30).borderRadius(15).objectFit(ImageFit.Cover)
            }
          }
          Text(topic.member?.username ?? '匿名').fontSize(12).fontColor('#8A97A6').margin({ left: 8 })
            .onClick(() => { if (topic.member?.username) router.pushUrl({ url: 'pages/Profile', params: { username: topic.member.username } }); })
          Blank()
          Text(topic.node?.title ?? topic.node?.name ?? 'V2EX').fontSize(12).fontColor(this.themeColor)
        }.width('100%').margin({ bottom: 10 })
        Row() {
          Text(topic.title).fontSize(17).fontColor('#202124').fontWeight(FontWeight.Medium)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          Text(`${topic.replies}`).fontSize(13).fontColor('#5B6B7A').margin({ left: 12 })
        }.width('100%').alignItems(VerticalAlign.Top)
        Text(`${relativeTime(topic.last_touched)} · ${topic.replies} 回复`).fontSize(12).fontColor('#8A97A6').margin({ top: 8 })
      }.width('100%').padding({ left: 18, right: 18, top: 16, bottom: 16 }).backgroundColor(Color.White)
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: topic.id } }))
  }

  build() {
    Stack() {
      Column() {
      Row() {
        Text('☰').fontSize(22).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center)
          .onClick(() => this.drawerOpen = true)
        Text('V2EX').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
        Text('✉').fontSize(22).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center)
          .onClick(() => router.pushUrl({ url: 'pages/Notifications' }))
        Text('✎').fontSize(23).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center)
          .onClick(() => router.pushUrl({ url: 'pages/WriteTopic' }))
        Text(this.loading ? '…' : '↻').fontSize(24).fontColor(this.themeColor)
          .width(42).textAlign(TextAlign.Center)
          .onClick(() => {
            const tab: HomeTabItem = this.activeTab();
            if (tab.type === 'hot') this.loadTopics('hot');
            else if (tab.type === 'latest') this.loadTopics('latest');
            else if (tab.type === 'node') this.loadTopicsForNode(tab.key);
            else if (tab.type === 'nodes') this.loadNodes();
            else if (tab.type === 'xna') this.loadXna();
            else if (tab.type === 'mine') this.loadCurrentMember();
          })
      }.width('100%').height(64).padding({ left: 20, right: 20 }).backgroundColor(Color.White)
      Row() {
        TextInput({ placeholder: '搜索主题、节点或用户', text: this.searchText })
          .layoutWeight(1).height(42).fontSize(14).fontColor('#30343B').placeholderColor('#8A97A6').backgroundColor('#F1F4F7')
          .onChange((value: string) => this.searchText = value)
          .onSubmit(() => this.searchRemote())
        Text('⌕').fontSize(22).fontColor(this.themeColor).width(44).textAlign(TextAlign.Center)
          .onClick(() => router.pushUrl({ url: 'pages/Search', params: { query: this.searchText } }))
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 }).backgroundColor(Color.White)
      Row() {
        ForEach(this.tabs, (tab: HomeTabItem, index: number) => {
          Column() {
            Text(tab.title).fontSize(15).fontColor(this.selectedTab === index ? this.themeColor : '#7B8794')
            Row().height(3).width(28).backgroundColor(this.selectedTab === index ? this.themeColor : Color.Transparent)
              .borderRadius(2).margin({ top: 7 })
          }.layoutWeight(1).alignItems(HorizontalAlign.Center).onClick(() => this.selectTab(index))
        }, (tab: HomeTabItem) => tab.key)
      }.width('100%').height(52).backgroundColor(Color.White)
      if (this.isTopicTab() && this.loading && this.topics.length === 0) {
        LoadingProgress().width(28).height(28).color('#4F7CAC').margin({ top: 36 })
      } else if (this.isTopicTab() && this.errorText.length > 0 && this.topics.length === 0) {
        Column() { Text(this.errorText).fontSize(15).fontColor('#7B8794'); Text('点击重试').fontSize(14).fontColor('#4F7CAC').margin({ top: 14 }).onClick(() => {
          const tab: HomeTabItem = this.activeTab();
          if (tab.type === 'hot') this.loadTopics('hot');
          else if (tab.type === 'node') this.loadTopicsForNode(tab.key);
          else this.loadTopics('latest');
        }); }
          .margin({ top: 42 }).alignItems(HorizontalAlign.Center)
      } else if (this.activeTab().type === 'nodes') {
        Column() {
          Text('节点浏览').fontSize(20).fontWeight(FontWeight.Medium).margin({ top: 18, bottom: 12 })
          TextInput({ placeholder: '搜索节点', text: this.nodeQuery }).width('92%').height(44).fontSize(14)
            .onChange((value: string) => this.nodeQuery = value).margin({ bottom: 10 })
          List({ space: 1 }) {
            ForEach(this.visibleNodes(), (node: V2exNode) => ListItem() {
              Row() { Text(node.title).fontSize(16).fontColor('#202124'); Blank(); Text(node.name).fontSize(13).fontColor('#8A97A6') }
                .width('100%').padding({ left: 20, right: 20, top: 15, bottom: 15 }).backgroundColor(Color.White)
                .onClick(() => router.pushUrl({ url: 'pages/NodeTopics', params: { name: node.name, title: node.title } }))
            }, (node: V2exNode) => node.name)
          }.layoutWeight(1).width('100%')
        }.layoutWeight(1).width('100%')
      } else if (this.activeTab().type === 'mine') {
        Scroll() {
          Column() {
          if (this.memberLoading) LoadingProgress().width(28).height(28).color(this.themeColor).margin({ top: 32 })
          if (this.currentMember) {
            Row() {
              Stack() {
                Text(this.currentMember.username.substring(0, 1).toUpperCase()).fontSize(18).fontColor(Color.White)
                  .width(54).height(54).textAlign(TextAlign.Center).backgroundColor('#B7C4D2').borderRadius(27)
                if (this.currentMember.avatar_large) Image(this.currentMember.avatar_large).width(54).height(54).borderRadius(27).objectFit(ImageFit.Cover)
              }
              Column() { Text(this.currentMember.username).fontSize(20).fontWeight(FontWeight.Medium); Text('已登录').fontSize(13).fontColor('#8A97A6').margin({ top: 5 }) }
                .alignItems(HorizontalAlign.Start).margin({ left: 14 })
            }.margin({ top: 36 })
          } else {
            Text('我的 V2EX').fontSize(20).fontWeight(FontWeight.Medium)
            Text('登录后可查看个人主题、收藏与通知').fontSize(14).fontColor('#8A97A6').margin({ top: 12 })
          }
          Button(this.currentMember ? '个人资料' : '打开登录页面').backgroundColor(this.themeColor).fontColor(Color.White).margin({ top: 22 }).onClick(() => {
            if (this.currentMember) router.pushUrl({ url: 'pages/Profile', params: { username: this.currentMember.username } });
            else router.pushUrl({ url: 'pages/Login' });
          })
          Button('发布主题').backgroundColor(this.themeColor).fontColor(Color.White).margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/WriteTopic' }))
          Button('通知').backgroundColor(this.themeColor).fontColor(Color.White).margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/Notifications' }))
          Button('我的主题').backgroundColor(this.themeColor).fontColor(Color.White).margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/MyTopics' }))
          Button('我的节点').backgroundColor(this.themeColor).fontColor(Color.White).margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/MyNodes' }))
          Button('节点导航').backgroundColor(this.themeColor).fontColor(Color.White).margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/NavNodes' }))
          Button('我的关注').backgroundColor(this.themeColor).fontColor(Color.White).margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/MyFollowing' }))
          Button('最近浏览').backgroundColor(this.themeColor).fontColor(Color.White).margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/RecentTopic' }))
          Button('历史热议').backgroundColor(this.themeColor).fontColor(Color.White).margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/HotestTopics' }))
          Button('设置').backgroundColor(this.themeColor).fontColor(Color.White).margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/Settings' }))
          Button('屏蔽列表').backgroundColor(this.themeColor).fontColor(Color.White).margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/BlackList' }))
          }.margin({ top: 48, bottom: 32 }).alignItems(HorizontalAlign.Center)
        }.layoutWeight(1).width('100%')
      } else if (this.activeTab().type === 'xna') {
        if (this.xnaTopics.length === 0 && !this.loading) {
          Text('暂无 XNA 内容').fontSize(15).fontColor('#7B8794').margin({ top: 48 })
        } else {
          Refresh({ refreshing: this.loading }) {
            List({ space: 1 }) { ForEach(this.xnaTopics, (topic: V2exTopic) => this.topicCard(topic), (topic: V2exTopic) => `${topic.id}`) }
              .layoutWeight(1).width('100%').divider({ strokeWidth: 1, color: '#EEF1F4' })
          }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => { if (state === RefreshStatus.Refresh) this.loadXna(); })
        }
      } else {
        Refresh({ refreshing: this.loading }) {
          List({ space: 1 }) { ForEach(this.visibleTopics(), (topic: V2exTopic) => this.topicCard(topic), (topic: V2exTopic) => `${topic.id}`) }
            .layoutWeight(1).width('100%').divider({ strokeWidth: 1, color: '#EEF1F4' })
        }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => {
          if (state === RefreshStatus.Refresh) {
            const tab: HomeTabItem = this.activeTab();
            if (tab.type === 'hot') this.loadTopics('hot');
            else if (tab.type === 'node') this.loadTopicsForNode(tab.key);
            else this.loadTopics('latest');
          }
        })
      }
      }.width('100%').height('100%').backgroundColor('#F5F7FA')
      .parallelGesture(PanGesture({ direction: PanDirection.Horizontal, distance: 40 })
        .onActionEnd((event: GestureEvent) => { if (event.offsetX > 80) this.shiftTab(-1); else if (event.offsetX < -80) this.shiftTab(1); }))
      if (this.drawerOpen) {
        Row() {
          Column() {
            Row() { Text('V2EX').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.themeColor); Blank(); Text('×').fontSize(28).fontColor(this.themeColor).onClick(() => this.drawerOpen = false) }
              .width('100%').height(64).padding({ left: 20, right: 20 }).backgroundColor(Color.White)
            if (this.currentMember) {
              Row() {
                Stack() {
                  Text(this.currentMember.username.substring(0, 1).toUpperCase()).fontSize(16).fontColor(Color.White)
                    .width(42).height(42).textAlign(TextAlign.Center).backgroundColor('#B7C4D2').borderRadius(21)
                  if (this.currentMember.avatar_large) Image(this.currentMember.avatar_large).width(42).height(42).borderRadius(21).objectFit(ImageFit.Cover)
                }
                Text(this.currentMember.username).fontSize(16).fontColor('#202124').margin({ left: 12 })
              }.width('100%').padding(18).backgroundColor(Color.White)
            } else {
              Text('登录 V2EX').fontSize(16).fontColor(this.themeColor).width('100%').padding(18).backgroundColor(Color.White)
                .onClick(() => { this.drawerOpen = false; router.pushUrl({ url: 'pages/Login' }); })
            }
            Column() {
              this.drawerItem('个人资料', 'Profile')
              this.drawerItem('通知', 'Notifications')
              this.drawerItem('我的主题', 'MyTopics')
              this.drawerItem('我的收藏', 'Favorites')
              this.drawerItem('节点导航', 'NavNodes')
              this.drawerItem('首页板块', 'HomeTabs')
              this.drawerItem('设置', 'Settings')
            }.width('100%')
            Blank()
          }.width('80%').height('100%').backgroundColor('#F5F7FA')
          Blank().layoutWeight(1).height('100%').backgroundColor('#00000055').onClick(() => this.drawerOpen = false)
        }.width('100%').height('100%')
      }
    }.width('100%').height('100%')
  }

  @Builder
  drawerItem(label: string, page: string) {
    Row() {
      Text(label).fontSize(16).fontColor('#202124').layoutWeight(1)
      Text('›').fontSize(22).fontColor('#9AA0A6')
    }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 16 }).backgroundColor(Color.White).margin({ top: 1 })
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
