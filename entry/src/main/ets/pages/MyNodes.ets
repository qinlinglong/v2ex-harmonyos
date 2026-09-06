import { router } from '@kit.ArkUI';
import { V2exNode } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';

@Entry
@Component
struct MyNodes {
  @State nodes: V2exNode[] = [];
  @State loading: boolean = true;
  @State status: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    this.status = '';
    try {
      this.nodes = await V2exService.myNodes();
      if (this.nodes.length === 0) this.status = '暂无已加入节点或尚未登录';
    } catch (_) { this.status = '请先登录 V2EX'; }
    finally { this.loading = false; }
  }

  @Builder
  row(node: V2exNode) {
    ListItem() {
      Row() {
        Stack() {
          Text(node.title.substring(0, 1)).fontSize(16).fontColor(Color.White).width(44).height(44)
            .textAlign(TextAlign.Center).backgroundColor('#B7C4D2').borderRadius(22)
          if (node.avatar_large) Image(node.avatar_large).width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover)
        }
        Column() {
          Text(node.title).fontSize(16).fontColor('#202124')
          Text(node.name).fontSize(12).fontColor('#8A97A6').margin({ top: 5 })
        }.alignItems(HorizontalAlign.Start).margin({ left: 12 })
        Blank()
        Text('›').fontSize(25).fontColor('#A0AAB5')
      }.width('100%').padding({ left: 18, right: 18, top: 13, bottom: 13 }).backgroundColor(Color.White)
    }.onClick(() => router.pushUrl({ url: 'pages/NodeTopics', params: { name: node.name, title: node.title } }))
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor('#4F7CAC').width(46).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('我的节点').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
        Text('↻').fontSize(24).fontColor('#4F7CAC').width(46).textAlign(TextAlign.Center).onClick(() => this.load())
      }.height(64).width('100%').padding({ right: 8 }).backgroundColor(Color.White)
      if (this.loading) LoadingProgress().width(30).height(30).color('#4F7CAC').margin({ top: 40 })
      else if (this.status.length > 0) Column() {
        Text(this.status).fontSize(15).fontColor('#7B8794')
        Button('打开登录').margin({ top: 16 }).onClick(() => router.pushUrl({ url: 'pages/Login' }))
      }.margin({ top: 42 }).alignItems(HorizontalAlign.Center)
      else {
        Refresh({ refreshing: this.loading }) {
          List({ space: 1 }) { ForEach(this.nodes, (node: V2exNode) => this.row(node), (node: V2exNode) => node.name) }
            .layoutWeight(1).width('100%')
        }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => { if (state === RefreshStatus.Refresh) this.load(); })
      }
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
