interface TopicPreview {
  title: string;
  node: string;
  author: string;
  replies: number;
}

@Entry
@Component
struct Index {
  @State selectedTab: number = 0;
  @State refreshing: boolean = false;
  private readonly tabs: string[] = ['首页', '最新', '节点', '我的'];
  private readonly topics: TopicPreview[] = [
    { title: 'V2EX 鸿蒙客户端开发讨论', node: '程序员', author: 'v2ex', replies: 18 },
    { title: '最近大家都在使用什么效率工具？', node: '问与答', author: 'miao', replies: 36 },
    { title: 'HarmonyOS NEXT 真机体验分享', node: '分享发现', author: 'north', replies: 12 },
    { title: '周末有什么值得推荐的电影？', node: '电影', author: 'sora', replies: 24 }
  ];

  private refresh(): void {
    if (this.refreshing) return;
    this.refreshing = true;
    setTimeout(() => { this.refreshing = false; }, 600);
  }

  build() {
    Column() {
      Row() {
        Text('V2EX').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
        Text(this.refreshing ? '更新中…' : '刷新').fontSize(14).fontColor('#4F7CAC')
          .onClick(() => this.refresh())
      }.width('100%').height(64).padding({ left: 20, right: 20 }).backgroundColor(Color.White)

      Row() {
        ForEach(this.tabs, (tab: string, index: number) => {
          Column() {
            Text(tab).fontSize(15).fontColor(this.selectedTab === index ? '#4F7CAC' : '#7B8794')
            Row().height(3).width(28).backgroundColor(this.selectedTab === index ? '#4F7CAC' : Color.Transparent)
              .borderRadius(2).margin({ top: 7 })
          }.layoutWeight(1).alignItems(HorizontalAlign.Center).onClick(() => this.selectedTab = index)
        }, (tab: string) => tab)
      }.width('100%').height(52).backgroundColor(Color.White)

      if (this.refreshing) {
        LoadingProgress().width(22).height(22).color('#4F7CAC').margin({ top: 18, bottom: 8 })
      }

      List({ space: 1 }) {
        ForEach(this.topics, (topic: TopicPreview) => {
          ListItem() {
            Column() {
              Row() {
                Text(topic.title).fontSize(17).fontColor('#202124').fontWeight(FontWeight.Medium).layoutWeight(1)
                Text(`${topic.replies}`).fontSize(13).fontColor('#9AA0A6')
              }.width('100%')
              Row() {
                Text(topic.node).fontSize(12).fontColor('#4F7CAC')
                Text(` · ${topic.author} · 刚刚`).fontSize(12).fontColor('#9AA0A6')
              }.margin({ top: 9 })
            }.width('100%').padding(18).backgroundColor(Color.White)
          }
        }, (topic: TopicPreview) => topic.title)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
