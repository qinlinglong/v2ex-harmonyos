import { router } from '@kit.ArkUI';
import { V2exNotification } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';

@Entry
@Component
struct Notifications {
  @State items: V2exNotification[] = [];
  @State loading: boolean = true;
  @State status: string = '';
  @State deletingId: number = 0;
  @State loadingMore: boolean = false;
  @State page: number = 1;

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    this.status = '';
    this.page = 1;
    try {
      this.items = await V2exService.notifications(1);
      if (this.items.length === 0) this.status = '暂无通知或尚未登录';
    } catch (_) { this.status = '请先登录 V2EX'; }
    finally { this.loading = false; }
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore) return;
    this.loadingMore = true;
    try {
      const next: V2exNotification[] = await V2exService.notifications(this.page + 1);
      if (next.length === 0) this.status = '没有更多通知';
      else { this.items = this.items.concat(next.filter((item: V2exNotification) => this.items.findIndex((old: V2exNotification) => old.id === item.id) < 0)); this.page += 1; }
    } catch (_) { this.status = '加载更多失败'; }
    finally { this.loadingMore = false; }
  }

  private async remove(item: V2exNotification): Promise<void> {
    this.deletingId = item.id;
    const ok: boolean = await V2exService.notificationAction(item.id, 'delete');
    if (ok) this.items = this.items.filter((value: V2exNotification) => value.id !== item.id);
    else this.status = '删除失败，请先登录';
    this.deletingId = 0;
  }

  @Builder
  row(item: V2exNotification) {
    ListItem() {
      Row() {
        Stack() {
          Text(item.username.substring(0, 1).toUpperCase()).fontSize(13).fontColor(Color.White)
            .width(40).height(40).textAlign(TextAlign.Center).backgroundColor('#B7C4D2').borderRadius(20)
          if (item.avatar) Image(item.avatar).width(40).height(40).borderRadius(20).objectFit(ImageFit.Cover)
        }
        Column() {
          Text(item.username).fontSize(14).fontColor('#4F7CAC')
          Row() {
            Text(item.topicTitle).fontSize(15).fontColor('#202124').maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            Text(this.deletingId === item.id ? '删除中' : '删除').fontSize(12).fontColor('#C05A73')
              .margin({ left: 10 }).onClick(() => this.remove(item))
          }.width('100%').margin({ top: 6 })
        }.alignItems(HorizontalAlign.Start).margin({ left: 12 }).layoutWeight(1)
      }.width('100%').padding({ left: 18, right: 18, top: 15, bottom: 15 }).backgroundColor(Color.White)
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: item.topicId } }))
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor('#4F7CAC').width(46).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('通知').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
      }.height(64).width('100%').padding({ right: 8 }).backgroundColor(Color.White)
      if (this.loading) LoadingProgress().width(30).height(30).color('#4F7CAC').margin({ top: 40 })
      else if (this.status.length > 0) Column() {
        Text(this.status).fontSize(15).fontColor('#7B8794')
        Button('打开登录').margin({ top: 16 }).onClick(() => router.pushUrl({ url: 'pages/Login' }))
      }.margin({ top: 42 }).alignItems(HorizontalAlign.Center)
      else {
        Refresh({ refreshing: this.loading }) {
          List({ space: 1 }) {
            ForEach(this.items, (item: V2exNotification) => this.row(item), (item: V2exNotification) => `${item.id}`)
            ListItem() { Button(this.loadingMore ? '加载中…' : '加载更多').fontSize(14).onClick(() => this.loadMore()) }
          }
            .layoutWeight(1).width('100%')
        }.layoutWeight(1).width('100%').onStateChange((state: RefreshStatus) => { if (state === RefreshStatus.Refresh) this.load(); })
      }
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
