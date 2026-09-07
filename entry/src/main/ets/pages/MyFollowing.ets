import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { V2exTopic } from '../model/V2exModels';

@Entry
@Component
struct MyFollowing {
  @State topics: V2exTopic[] = [];
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State page: number = 1;
  @State status: string = '';

  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.status = '';
    this.page = 1;
    try {
      this.topics = await V2exService.followingTopics(1);
      if (this.topics.length === 0) this.status = '暂无关注动态或尚未登录';
    } catch (_) { this.status = '请先登录 V2EX'; }
    finally { this.loading = false; }
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore) return;
    this.loadingMore = true;
    try {
      const next: V2exTopic[] = await V2exService.followingTopics(this.page + 1);
      if (next.length === 0) this.status = '没有更多动态';
      else { this.topics = this.topics.concat(next.filter((topic: V2exTopic) => this.topics.findIndex((item: V2exTopic) => item.id === topic.id) < 0)); this.page += 1; }
    } catch (_) { this.status = '加载更多失败'; }
    finally { this.loadingMore = false; }
  }

  @Builder
  row(topic: V2exTopic) {
    ListItem() {
      Column() {
        Text(topic.title).fontSize(16).fontColor('#202124').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${topic.member?.username ?? '匿名'} · ${topic.replies} 回复`).fontSize(12).fontColor('#8A97A6').margin({ top: 7 })
      }.width('100%').padding({ left: 18, right: 18, top: 15, bottom: 15 }).backgroundColor(Color.White)
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: topic.id } }))
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor('#4F7CAC').width(46).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('我的关注').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
      }.height(64).width('100%').padding({ right: 8 }).backgroundColor(Color.White)
      if (this.loading) LoadingProgress().width(30).height(30).color('#4F7CAC').margin({ top: 40 })
      else if (this.status.length > 0) Column() { Text(this.status).fontSize(15).fontColor('#7B8794'); Button('打开登录').margin({ top: 16 }).onClick(() => router.pushUrl({ url: 'pages/Login' })) }.margin({ top: 42 }).alignItems(HorizontalAlign.Center)
      else Refresh({ refreshing: this.loading }) {
        List({ space: 1 }) {
          ForEach(this.topics, (topic: V2exTopic) => this.row(topic), (topic: V2exTopic) => `${topic.id}`)
          ListItem() { Button(this.loadingMore ? '加载中…' : '加载更多').fontSize(14).onClick(() => this.loadMore()) }
        }.layoutWeight(1).width('100%')
      }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => { if (state === RefreshStatus.Refresh) this.load(); })
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
