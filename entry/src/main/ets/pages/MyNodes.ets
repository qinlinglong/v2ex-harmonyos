import { router } from '@kit.ArkUI';
import { V2exNode } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';
import { themeBackground, themePrimaryText, themeSecondaryText, themeSurface } from '../common/Theme';

@Entry
@Component
struct MyNodes {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exMyNodesCache') cacheJson: string = '[]';
  @State nodes: V2exNode[] = [];
  @State loading: boolean = true;
  @State status: string = '';

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
      const fresh: V2exNode[] = await V2exService.myNodes();
      this.nodes = fresh;
      this.cacheJson = JSON.stringify(fresh);
      if (this.nodes.length === 0) this.status = '暂无已加入节点或尚未登录';
    } catch (_) {
      if (!hasCached) this.status = '请先登录 V2EX';
    }
    finally { this.loading = false; }
  }

  @Builder
  gridItem(node: V2exNode) {
    GridItem() {
      Column() {
        Stack() {
          Text(node.title.substring(0, 1)).fontSize(16).fontColor(Color.White).width(44).height(44)
            .textAlign(TextAlign.Center).backgroundColor(this.darkMode ? '#435466' : '#B7C4D2').borderRadius(22)
          if (node.avatar_large) Image(node.avatar_large).width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover)
        }
        Text(node.title).fontSize(13).fontColor(themePrimaryText(this.darkMode)).margin({ top: 6 }).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%').height(96).justifyContent(FlexAlign.Center)
        .onClick(() => router.pushUrl({ url: 'pages/NodeTopics', params: { name: node.name, title: node.title } }))
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(46).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('节点收藏').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
        Blank()
      }.height(64).width('100%').padding({ right: 8 }).backgroundColor(themeSurface(this.darkMode))
      if (this.loading) LoadingProgress().width(30).height(30).color(this.themeColor).margin({ top: 40 })
      else if (this.status.length > 0) Column() {
        Text(this.status).fontSize(15).fontColor(themeSecondaryText(this.darkMode))
        Button('打开登录').margin({ top: 16 }).backgroundColor(this.themeColor).fontColor(Color.White).onClick(() => router.pushUrl({ url: 'pages/Login' }))
      }.margin({ top: 42 }).alignItems(HorizontalAlign.Center)
      else {
        Refresh({ refreshing: this.loading }) {
          Grid() {
            ForEach(this.nodes, (node: V2exNode) => this.gridItem(node), (node: V2exNode) => node.name)
          }.columnsTemplate('1fr 1fr 1fr 1fr').columnsGap(8).rowsGap(8).width('100%').layoutWeight(1)
            .padding(12).scrollBar(BarState.Off)
        }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => { if (state === RefreshStatus.Refresh) this.load(); })
      }
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
