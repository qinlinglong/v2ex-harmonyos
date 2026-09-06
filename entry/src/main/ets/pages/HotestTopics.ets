import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { V2exTopic } from '../model/V2exModels';

@Entry
@Component
struct HotestTopics {
  @State topics: V2exTopic[] = [];
  @State loading: boolean = true;
  @State status: string = '';
  private date: string = new Date().toISOString().substring(0, 10);

  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.status = '';
    try {
      this.topics = await V2exService.hotestTopics(this.date);
      if (this.topics.length === 0) this.status = '今天暂无热议数据';
    } catch (_) { this.status = '热议加载失败'; }
    finally { this.loading = false; }
  }

  @Builder
  row(topic: V2exTopic, index: number) {
    ListItem() {
      Row() {
        Text(`${index + 1}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#D07A3A').width(40).textAlign(TextAlign.Center)
        Column() {
          Text(topic.title).fontSize(16).fontColor('#202124').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${topic.member?.username ?? '匿名'} · ${topic.node?.title ?? 'V2EX'} · ${topic.replies} 回复`).fontSize(12).fontColor('#8A97A6').margin({ top: 7 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').padding({ left: 12, right: 18, top: 15, bottom: 15 }).backgroundColor(Color.White)
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: topic.id } }))
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor('#4F7CAC').width(46).textAlign(TextAlign.Center).onClick(() => router.back())
        Column() { Text('历史最热').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124'); Text(this.date).fontSize(12).fontColor('#8A97A6').margin({ top: 2 }) }.alignItems(HorizontalAlign.Start)
        Blank()
        Text('↻').fontSize(24).fontColor('#4F7CAC').width(46).textAlign(TextAlign.Center).onClick(() => this.load())
      }.height(64).width('100%').padding({ right: 8 }).backgroundColor(Color.White)
      if (this.loading) LoadingProgress().width(30).height(30).color('#4F7CAC').margin({ top: 40 })
      else if (this.status.length > 0) Text(this.status).fontSize(15).fontColor('#7B8794').margin({ top: 42 })
      else List({ space: 1 }) { ForEach(this.topics, (topic: V2exTopic, index: number) => this.row(topic, index), (topic: V2exTopic) => `${topic.id}`) }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
