import { router } from '@kit.ArkUI';
import { V2exNode } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';

@Entry
@Component
struct NavNodes {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exNodesCache') cacheJson: string = '[]';
  @State nodes: V2exNode[] = [];
  @State query: string = '';
  @State loading: boolean = true;
  @State status: string = '';
  @State group: number = 0;
  private readonly groups: string[] = ['全部节点', '开发工具', '设计产品', '生活兴趣'];

  aboutToAppear(): void {
    this.restoreCache();
    this.load();
  }

  private restoreCache(): void {
    try {
      const cached: V2exNode[] = JSON.parse(this.cacheJson) as V2exNode[];
      if (Array.isArray(cached) && cached.length > 0) {
        this.nodes = cached;
        this.loading = false;
      }
    } catch (_) { /* corrupt cache is ignored */ }
  }

  private async load(): Promise<void> {
    const hasCached: boolean = this.nodes.length > 0;
    this.loading = !hasCached;
    this.status = '';
    try {
      const fresh: V2exNode[] = await V2exService.nodes();
      this.nodes = fresh;
      this.cacheJson = JSON.stringify(fresh);
      if (this.nodes.length === 0) this.status = '暂无节点';
    } catch (_) {
      if (!hasCached) this.status = '节点加载失败';
    }
    finally { this.loading = false; }
  }

  private visibleNodes(): V2exNode[] {
    const keyword: string = this.query.trim().toLowerCase();
    let result: V2exNode[] = this.nodes;
    if (this.group === 1) result = this.nodes.filter((node: V2exNode) => /dev|code|program|js|ios|android|python|go|java|rust|linux|hardware/i.test(`${node.name} ${node.title}`));
    if (this.group === 2) result = this.nodes.filter((node: V2exNode) => /design|product|ux|ui|creative|摄影|设计|产品/i.test(`${node.name} ${node.title}`));
    if (this.group === 3) result = this.nodes.filter((node: V2exNode) => /life|music|movie|travel|food|play|生活|音乐|电影|旅行/i.test(`${node.name} ${node.title}`));
    if (keyword.length > 0) result = result.filter((node: V2exNode) => `${node.name} ${node.title}`.toLowerCase().includes(keyword));
    return result;
  }

  @Builder
  nodeCard(node: V2exNode) {
    GridItem() {
      Column() {
        Stack() {
          Text(node.title.substring(0, 1)).fontSize(18).fontColor(Color.White)
            .width(48).height(48).textAlign(TextAlign.Center).backgroundColor(this.themeColor).borderRadius(24)
          if (node.avatar_large) Image(node.avatar_large).width(48).height(48).borderRadius(24).objectFit(ImageFit.Cover)
        }
        Text(node.title).fontSize(14).fontColor('#202124').maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 8 })
        Text(node.name).fontSize(11).fontColor('#8A97A6').maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 3 })
      }.width('100%').padding({ top: 12, bottom: 12 }).backgroundColor(Color.White)
    }.onClick(() => router.pushUrl({ url: 'pages/NodeTopics', params: { name: node.name, title: node.title } }))
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('节点导航').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
      }.height(60).width('100%').padding({ right: 10 }).backgroundColor(Color.White)
      TextInput({ placeholder: '搜索节点', text: this.query }).width('92%').height(44).fontSize(14).fontColor('#202124').placeholderColor('#8A97A6').backgroundColor('#F1F4F7')
        .margin({ top: 10, bottom: 8 }).onChange((value: string) => this.query = value)
      Scroll() {
        Row() {
          ForEach(this.groups, (item: string, index: number) => Text(item).fontSize(14)
            .fontColor(this.group === index ? this.themeColor : '#7B8794')
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor(this.group === index ? '#EAF1F8' : Color.Transparent)
            .borderRadius(16).margin({ right: 8 }).onClick(() => this.group = index), (item: string) => item)
        }.padding({ left: 18, right: 18 })
      }.scrollable(ScrollDirection.Horizontal).width('100%').height(42)
      if (this.loading) LoadingProgress().width(30).height(30).color(this.themeColor).margin({ top: 30 })
      else if (this.status.length > 0) Text(this.status).fontSize(15).fontColor('#7B8794').margin({ top: 36 })
      else Grid() {
        ForEach(this.visibleNodes(), (node: V2exNode) => this.nodeCard(node), (node: V2exNode) => node.name)
      }.columnsTemplate('1fr 1fr 1fr').rowsGap(1).columnsGap(1).layoutWeight(1).width('100%').padding(1)
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
