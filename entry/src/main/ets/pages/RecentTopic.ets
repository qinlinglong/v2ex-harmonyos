import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { V2exTopic } from '../model/V2exModels';

@Entry
@Component
struct RecentTopic {
  @StorageLink('v2exRecentTopicIds') recentJson: string = '[]';
  @State topics: V2exTopic[] = [];
  @State loading: boolean = true;
  @State status: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    this.status = '';
    this.topics = [];
    try {
      const ids: number[] = JSON.parse(this.recentJson) as number[];
      for (const id of ids) {
        try { this.topics.push(await V2exService.topic(id)); } catch (_) { /* topic may be removed */ }
      }
      if (this.topics.length === 0) this.status = '暂无浏览记录';
    } catch (_) { this.status = '浏览记录读取失败'; }
    finally { this.loading = false; }
  }

  @Builder
  row(topic: V2exTopic) {
    ListItem() {
      Column() {
        Text(topic.title).fontSize(16).fontColor('#202124').maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${topic.node?.title ?? 'V2EX'} · ${topic.replies} 回复`).fontSize(12).fontColor('#8A97A6').margin({ top: 7 })
      }.width('100%').padding({ left: 18, right: 18, top: 15, bottom: 15 }).backgroundColor(Color.White)
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: topic.id } }))
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor('#4F7CAC').width(46).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('最近浏览').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
        Text('↻').fontSize(24).fontColor('#4F7CAC').width(46).textAlign(TextAlign.Center).onClick(() => this.load())
      }.height(64).width('100%').padding({ right: 8 }).backgroundColor(Color.White)
      if (this.loading) LoadingProgress().width(30).height(30).color('#4F7CAC').margin({ top: 40 })
      else if (this.status.length > 0) Text(this.status).fontSize(15).fontColor('#7B8794').margin({ top: 42 })
      else {
        List({ space: 1 }) { ForEach(this.topics, (topic: V2exTopic) => this.row(topic), (topic: V2exTopic) => `${topic.id}`) }
          .layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
