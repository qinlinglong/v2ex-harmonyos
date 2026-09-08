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
  @State members: string[] = [];
  @State selectedMember: string = '';

  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.status = '';
    this.page = 1;
    this.selectedMember = '';
    try {
      this.topics = await V2exService.followingTopics(1);
      this.collectMembers();
      if (this.topics.length === 0) this.status = '暂无关注动态或尚未登录';
    } catch (_) { this.status = '请先登录 V2EX'; }
    finally { this.loading = false; }
  }

  private collectMembers(): void {
    const unique: string[] = [];
    this.topics.forEach((topic: V2exTopic) => {
      const username: string = topic.member?.username ?? '';
      if (username.length > 0 && unique.indexOf(username) < 0) unique.push(username);
    });
    this.members = unique;
  }

  private async selectMember(username: string): Promise<void> {
    if (this.selectedMember === username) return;
    this.selectedMember = username;
    this.loading = true;
    this.status = '';
    try {
      this.topics = username.length === 0
        ? await V2exService.followingTopics(1)
        : await V2exService.memberTopics(username);
      if (username.length === 0) this.collectMembers();
      if (this.topics.length === 0) this.status = 'TA 最近没有发表主题';
    } catch (_) {
      this.status = username.length === 0 ? '请先登录 V2EX' : '主题加载失败';
    } finally { this.loading = false; }
  }

  private async reloadCurrent(): Promise<void> {
    if (this.selectedMember.length === 0) await this.load();
    else await this.selectMember(this.selectedMember);
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
      Row() {
          Stack() {
            Text((topic.member?.username ?? '?').substring(0, 1).toUpperCase()).fontSize(12).fontColor(Color.White)
              .width(26).height(26).textAlign(TextAlign.Center).backgroundColor('#B7C4D2').borderRadius(13)
            if (topic.member?.avatar_large) Image(topic.member.avatar_large).width(26).height(26).borderRadius(13).objectFit(ImageFit.Cover)
          }.onClick(() => { if (topic.member?.username) router.pushUrl({ url: 'pages/Profile', params: { username: topic.member.username } }); })
            .hitTestBehavior(HitTestMode.Block)
        Column() {
          Text(topic.member?.username ?? '匿名').fontSize(12).fontColor('#8A97A6')
          Text(topic.title).fontSize(16).fontColor('#202124').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
          Text(`${topic.replies} 回复`).fontSize(12).fontColor('#8A97A6').margin({ top: 5 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 10 })
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 }).backgroundColor(Color.White)
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: topic.id } }))
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor('#4F7CAC').width(46).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('特别关注').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
      }.height(64).width('100%').padding({ right: 8 }).backgroundColor(Color.White)
      Scroll() {
        Row({ space: 8 }) {
          Text('全部').fontSize(14).fontColor(this.selectedMember.length === 0 ? '#FFFFFF' : '#4F7CAC')
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .backgroundColor(this.selectedMember.length === 0 ? '#4F7CAC' : '#EAF1F8').borderRadius(14)
            .onClick(() => this.selectMember(''))
          ForEach(this.members, (username: string) => {
            Text(username).fontSize(14).fontColor(this.selectedMember === username ? '#FFFFFF' : '#4F7CAC')
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .backgroundColor(this.selectedMember === username ? '#4F7CAC' : '#EAF1F8').borderRadius(14)
              .onClick(() => this.selectMember(username))
          }, (username: string) => username)
        }.height(42).alignItems(VerticalAlign.Center)
      }.width('100%').height(50).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).padding({ left: 16 })
        .backgroundColor(Color.White)
      if (this.loading) LoadingProgress().width(30).height(30).color('#4F7CAC').margin({ top: 40 })
      else if (this.status.length > 0) Column() { Text(this.status).fontSize(15).fontColor('#7B8794'); Button('打开登录').margin({ top: 16 }).onClick(() => router.pushUrl({ url: 'pages/Login' })) }.margin({ top: 42 }).alignItems(HorizontalAlign.Center)
      else Refresh({ refreshing: this.loading }) {
        List({ space: 1 }) {
          ForEach(this.topics, (topic: V2exTopic) => this.row(topic), (topic: V2exTopic) => `${topic.id}`)
          if (this.selectedMember.length === 0) {
            ListItem() { Button(this.loadingMore ? '加载中…' : '加载更多').fontSize(14).onClick(() => this.loadMore()) }
          }
        }.layoutWeight(1).width('100%')
      }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => { if (state === RefreshStatus.Refresh) this.reloadCurrent(); })
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
