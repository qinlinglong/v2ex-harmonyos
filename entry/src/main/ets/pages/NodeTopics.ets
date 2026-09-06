import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { V2exTopic } from '../model/V2exModels';

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
  @State name: string = '';
  @State title: string = '';
  @State topics: V2exTopic[] = [];
  @State loading: boolean = true;
  @State status: string = '';
  @State page: number = 1;
  @State loadingMore: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    this.name = String(params?.['name'] ?? '');
    this.title = String(params?.['title'] ?? this.name);
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.status = '';
    this.page = 1;
    try {
      this.topics = await V2exService.topicsForNode(this.name);
      if (this.topics.length === 0) this.status = '该节点暂无主题';
    } catch (_) {
      this.status = '节点主题加载失败';
    } finally {
      this.loading = false;
    }
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore) return;
    this.loadingMore = true;
    try {
      const next: V2exTopic[] = await V2exService.topicsForNodePage(this.name, this.page + 1);
      if (next.length === 0) this.status = '没有更多主题';
      else { this.topics = this.topics.concat(next); this.page += 1; }
    } catch (_) { this.status = '加载更多失败'; }
    finally { this.loadingMore = false; }
  }

  @Builder
  topicRow(topic: V2exTopic) {
    ListItem() {
      Row() {
        Stack() {
          Text((topic.member?.username ?? '?').substring(0, 1).toUpperCase())
            .fontSize(13).fontColor(Color.White).width(36).height(36).textAlign(TextAlign.Center)
            .backgroundColor('#B7C4D2').borderRadius(18)
          if (topic.member?.avatar_large) Image(topic.member.avatar_large).width(36).height(36)
            .borderRadius(18).objectFit(ImageFit.Cover)
        }
        Column() {
          Text(topic.title).fontSize(16).fontColor('#202124').maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${topic.member?.username ?? '匿名'} · ${age(topic.last_touched)} · ${topic.replies} 回复`)
            .fontSize(12).fontColor('#8A97A6').margin({ top: 7 })
        }.layoutWeight(1).margin({ left: 12 })
      }.width('100%').padding({ left: 18, right: 18, top: 14, bottom: 14 })
        .backgroundColor(Color.White)
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: topic.id } }))
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor('#4F7CAC').width(46).textAlign(TextAlign.Center)
          .onClick(() => router.back())
        Column() {
          Text(titleOrName(this.title, this.name)).fontSize(19).fontWeight(FontWeight.Bold)
          Text(this.name).fontSize(12).fontColor('#8A97A6').margin({ top: 2 })
        }.alignItems(HorizontalAlign.Start)
        Blank()
        Text('↻').fontSize(24).fontColor('#4F7CAC').width(46).textAlign(TextAlign.Center)
          .onClick(() => this.load())
      }.height(64).width('100%').padding({ right: 8 }).backgroundColor(Color.White)
      if (this.loading) {
        LoadingProgress().width(30).height(30).color('#4F7CAC').margin({ top: 36 })
      } else if (this.status.length > 0) {
        Column() {
          Text(this.status).fontSize(15).fontColor('#7B8794')
          Text('点击重试').fontSize(14).fontColor('#4F7CAC').margin({ top: 12 }).onClick(() => this.load())
        }.margin({ top: 42 }).alignItems(HorizontalAlign.Center)
      } else {
        Refresh({ refreshing: this.loading }) {
          List({ space: 1 }) {
            ForEach(this.topics, (topic: V2exTopic) => this.topicRow(topic), (topic: V2exTopic) => `${topic.id}`)
            ListItem() {
              Button(this.loadingMore ? '加载中…' : '加载更多').fontSize(14).onClick(() => this.loadMore())
            }.width('100%').padding(18).align(Alignment.Center)
          }.layoutWeight(1).width('100%')
        }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => {
          if (state === RefreshStatus.Refresh) this.load();
        })
      }
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}

function titleOrName(title: string, name: string): string {
  return title.length > 0 ? title : (name.length > 0 ? name : '节点主题');
}
