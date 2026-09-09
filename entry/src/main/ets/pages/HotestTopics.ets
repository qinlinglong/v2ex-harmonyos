import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { V2exTopic } from '../model/V2exModels';

function isoDay(offset: number): string {
  const value: Date = new Date(Date.now() + offset * 86400000);
  const month: string = `${value.getMonth() + 1}`.padStart(2, '0');
  const day: string = `${value.getDate()}`.padStart(2, '0');
  return `${value.getFullYear()}-${month}-${day}`;
}

@Entry
@Component
struct HotestTopics {
  @StorageLink('v2exHotestTopicsCache') cacheJson: string = '{}';
  @State topics: V2exTopic[] = [];
  @State loading: boolean = true;
  @State status: string = '';
  private date: string = isoDay(-1);

  aboutToAppear(): void {
    this.restoreCache();
    this.load();
  }

  private restoreCache(): void {
    try {
      const cache: Record<string, V2exTopic[]> = JSON.parse(this.cacheJson) as Record<string, V2exTopic[]>;
      const cached: V2exTopic[] | undefined = cache[this.date];
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
      const fresh: V2exTopic[] = await V2exService.hotestTopics(this.date);
      this.topics = fresh;
      try {
        const cache: Record<string, V2exTopic[]> = JSON.parse(this.cacheJson) as Record<string, V2exTopic[]>;
        cache[this.date] = fresh;
        this.cacheJson = JSON.stringify(cache);
      } catch (_) { /* cache failures do not affect the page */ }
      if (this.topics.length === 0) this.status = '今天暂无热议数据';
    } catch (_) {
      if (!hasCached) this.status = '热议加载失败';
    }
    finally { this.loading = false; }
  }

  private shiftDate(delta: number): void {
    if (this.loading) return;
    const currentOffset: number = Math.round((new Date(this.date).getTime() - Date.now()) / 86400000);
    const next: string = isoDay(currentOffset + delta);
    const today: string = isoDay(0);
    if (next >= today) return;
    this.date = next;
    this.topics = [];
    this.restoreCache();
    this.load();
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
        Column() {
          Text('历史最热').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text('‹').fontSize(26).fontColor(this.date <= isoDay(-30) ? '#B0B7BF' : '#4F7CAC').width(44).height(56).textAlign(TextAlign.Center)
          .onClick(() => this.shiftDate(-1))
        Text(this.date).fontSize(13).fontColor('#4F7CAC').height(56).textAlign(TextAlign.Center)
        Text('›').fontSize(26).fontColor(this.date >= isoDay(-1) ? '#B0B7BF' : '#4F7CAC').width(44).height(56).textAlign(TextAlign.Center)
          .onClick(() => this.shiftDate(1))
      }.height(64).width('100%').padding({ right: 8 }).backgroundColor(Color.White)
      if (this.loading) LoadingProgress().width(30).height(30).color('#4F7CAC').margin({ top: 40 })
      else if (this.status.length > 0) Text(this.status).fontSize(15).fontColor('#7B8794').margin({ top: 42 })
      else Refresh({ refreshing: this.loading }) {
        List({ space: 1 }) { ForEach(this.topics, (topic: V2exTopic, index: number) => this.row(topic, index), (topic: V2exTopic) => `${topic.id}`) }.layoutWeight(1).width('100%')
      }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => { if (state === RefreshStatus.Refresh) this.load(); })
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
