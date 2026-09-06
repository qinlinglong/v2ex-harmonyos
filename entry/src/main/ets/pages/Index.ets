import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { V2exNode, V2exTopic } from '../model/V2exModels';

function relativeTime(unix: number): string {
  if (!unix) return '';
  const seconds: number = Math.max(1, Math.floor(Date.now() / 1000) - unix);
  if (seconds < 60) return `${seconds}秒前`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}分钟前`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}小时前`;
  return `${Math.floor(seconds / 86400)}天前`;
}

@Entry
@Component
struct Index {
  @State selectedTab: number = 0;
  @State loading: boolean = false;
  @State errorText: string = '';
  @State topics: V2exTopic[] = [];
  @State nodes: V2exNode[] = [];
  @State searchText: string = '';
  private readonly tabs: string[] = ['首页', '最新', '节点', '我的'];

  aboutToAppear(): void { this.loadTopics('latest'); }

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
    if (index === 0) this.loadTopics('hot');
    if (index === 1) this.loadTopics('latest');
    if (index === 2 && this.nodes.length === 0) this.loadNodes();
  }

  private visibleTopics(): V2exTopic[] {
    const query: string = this.searchText.trim().toLowerCase();
    if (query.length === 0) return this.topics;
    return this.topics.filter((topic: V2exTopic) =>
      topic.title.toLowerCase().includes(query) || (topic.content ?? '').toLowerCase().includes(query) ||
      (topic.member?.username ?? '').toLowerCase().includes(query) || (topic.node?.title ?? '').toLowerCase().includes(query));
  }

  private async loadNodes(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try { this.nodes = await V2exService.nodes(); }
    catch (_) { this.errorText = '节点加载失败，请稍后重试'; }
    finally { this.loading = false; }
  }

  @Builder
  topicCard(topic: V2exTopic) {
    ListItem() {
      Column() {
        Row() {
          Text(topic.title).fontSize(17).fontColor('#202124').fontWeight(FontWeight.Medium)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          Text(`${topic.replies}`).fontSize(13).fontColor('#5B6B7A').margin({ left: 12 })
        }.width('100%').alignItems(VerticalAlign.Top)
        Row() {
          Text(topic.node?.title ?? topic.node?.name ?? 'V2EX').fontSize(12).fontColor('#4F7CAC')
          Text(` · ${topic.member?.username ?? '匿名'} · ${relativeTime(topic.last_touched)}`)
            .fontSize(12).fontColor('#8A97A6').margin({ left: 4 })
        }.margin({ top: 10 })
      }.width('100%').padding({ left: 18, right: 18, top: 16, bottom: 16 }).backgroundColor(Color.White)
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: topic.id } }))
  }

  build() {
    Column() {
      Row() {
        Text('V2EX').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
        Text(this.loading ? '加载中…' : '刷新').fontSize(14).fontColor('#4F7CAC')
          .onClick(() => this.loadTopics(this.selectedTab === 0 ? 'hot' : 'latest'))
      }.width('100%').height(64).padding({ left: 20, right: 20 }).backgroundColor(Color.White)
      Row() {
        TextInput({ placeholder: '搜索主题、节点或用户', text: this.searchText })
          .layoutWeight(1).height(42).fontSize(14).backgroundColor('#F1F4F7')
          .onChange((value: string) => this.searchText = value)
        Text('⌕').fontSize(22).fontColor('#4F7CAC').width(44).textAlign(TextAlign.Center)
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 }).backgroundColor(Color.White)
      Row() {
        ForEach(this.tabs, (tab: string, index: number) => {
          Column() {
            Text(tab).fontSize(15).fontColor(this.selectedTab === index ? '#4F7CAC' : '#7B8794')
            Row().height(3).width(28).backgroundColor(this.selectedTab === index ? '#4F7CAC' : Color.Transparent)
              .borderRadius(2).margin({ top: 7 })
          }.layoutWeight(1).alignItems(HorizontalAlign.Center).onClick(() => this.selectTab(index))
        }, (tab: string) => tab)
      }.width('100%').height(52).backgroundColor(Color.White)
      if (this.loading && this.topics.length === 0) {
        LoadingProgress().width(28).height(28).color('#4F7CAC').margin({ top: 36 })
      } else if (this.errorText.length > 0 && this.topics.length === 0) {
        Column() { Text(this.errorText).fontSize(15).fontColor('#7B8794'); Text('点击重试').fontSize(14).fontColor('#4F7CAC').margin({ top: 14 }).onClick(() => this.loadTopics('latest')); }
          .margin({ top: 42 }).alignItems(HorizontalAlign.Center)
      } else if (this.selectedTab === 2) {
        Column() {
          Text('节点浏览').fontSize(20).fontWeight(FontWeight.Medium).margin({ top: 18, bottom: 12 })
          List({ space: 1 }) {
            ForEach(this.nodes, (node: V2exNode) => ListItem() {
              Row() { Text(node.title).fontSize(16).fontColor('#202124'); Blank(); Text(node.name).fontSize(13).fontColor('#8A97A6') }
                .width('100%').padding({ left: 20, right: 20, top: 15, bottom: 15 }).backgroundColor(Color.White)
            }, (node: V2exNode) => node.name)
          }.layoutWeight(1).width('100%')
        }.layoutWeight(1).width('100%')
      } else if (this.selectedTab === 3) {
        Column() {
          Text('我的 V2EX').fontSize(20).fontWeight(FontWeight.Medium)
          Text('登录后可查看个人主题、收藏与通知').fontSize(14).fontColor('#8A97A6').margin({ top: 12 })
          Button('打开登录页面').margin({ top: 22 }).onClick(() => router.pushUrl({ url: 'pages/Login' }))
          Button('发布主题').margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/WriteTopic' }))
          Button('通知').margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/Notifications' }))
          Button('我的主题').margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/MyTopics' }))
          Button('我的节点').margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/MyNodes' }))
          Button('我的收藏').margin({ top: 14 }).onClick(() => router.pushUrl({ url: 'pages/Favorites' }))
        }.margin({ top: 48 }).alignItems(HorizontalAlign.Center)
      } else {
        Refresh({ refreshing: this.loading }) {
          List({ space: 1 }) { ForEach(this.visibleTopics(), (topic: V2exTopic) => this.topicCard(topic), (topic: V2exTopic) => `${topic.id}`) }
            .layoutWeight(1).width('100%').divider({ strokeWidth: 1, color: '#EEF1F4' })
        }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => {
          if (state === RefreshStatus.Refresh) this.loadTopics(this.selectedTab === 0 ? 'hot' : 'latest');
        })
      }
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
