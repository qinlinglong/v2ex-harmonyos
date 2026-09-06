import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct Settings {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exParseContent') parseContent: boolean = true;
  @StorageLink('v2exBuiltinBrowser') builtinBrowser: boolean = true;
  @StorageLink('v2exAutoCheckin') autoCheckin: boolean = true;
  @StorageLink('v2exRecentTopicIds') recentJson: string = '[]';
  @State customColor: string = '#4F7CAC';
  @State status: string = '';
  private readonly colors: string[] = ['#4F7CAC', '#5B8C5A', '#C05A73', '#8B6FB0', '#D07A3A'];
  aboutToAppear(): void { this.customColor = this.themeColor; }
  build() {
    Column() {
      Row() { Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back()); Text('设置').fontSize(20).fontWeight(FontWeight.Bold) }
        .height(60).width('100%').backgroundColor(Color.White)
      Scroll() {
        Column() {
        Row() { Text('内容解析').fontSize(16).layoutWeight(1); Button(this.parseContent ? '已开启' : '已关闭').fontSize(13).onClick(() => this.parseContent = !this.parseContent) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 12 })
        Row() { Text('内置浏览器').fontSize(16).layoutWeight(1); Button(this.builtinBrowser ? '已开启' : '已关闭').fontSize(13).onClick(() => this.builtinBrowser = !this.builtinBrowser) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
        Row() { Text('自动签到').fontSize(16).layoutWeight(1); Button(this.autoCheckin ? '已开启' : '已关闭').fontSize(13).onClick(() => this.autoCheckin = !this.autoCheckin) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
        Text('主题颜色').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#202124').width('100%')
        Row() {
          ForEach(this.colors, (color: string) => Circle({ width: 42, height: 42 }).backgroundColor(color)
            .margin({ right: 14 }).border({ width: this.themeColor === color ? 3 : 0, color: Color.White })
            .onClick(() => this.themeColor = color), (color: string) => color)
        }.margin({ top: 18 })
        Text('主题会保存在本机，下次启动继续使用。').fontSize(13).fontColor('#8A97A6').margin({ top: 18 })
        Row() {
          TextInput({ placeholder: '#RRGGBB', text: this.customColor }).layoutWeight(1).height(44)
            .onChange((value: string) => this.customColor = value)
          Button('应用').margin({ left: 10 }).onClick(() => {
            const value: string = this.customColor.trim();
            if (/^#[0-9A-Fa-f]{6}$/.test(value)) this.themeColor = value;
          })
        }.width('100%').margin({ top: 18 })
        Row() { Text('主题设置').fontSize(16).layoutWeight(1); Text('颜色与深色模式').fontSize(14).fontColor(this.themeColor) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 12 })
          .onClick(() => router.pushUrl({ url: 'pages/CustomizeTheme' }))
        Row() { Text('Markdown 帮助').fontSize(16).layoutWeight(1); Text('编辑格式').fontSize(14).fontColor(this.themeColor) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
          .onClick(() => router.pushUrl({ url: 'pages/GitHubMD' }))
        Row() { Text('节点搜索').fontSize(16).layoutWeight(1); Text('查找节点').fontSize(14).fontColor(this.themeColor) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
          .onClick(() => router.pushUrl({ url: 'pages/SearchNode' }))
        Row() { Text('节点导航').fontSize(16).layoutWeight(1); Text('分类浏览全部节点').fontSize(14).fontColor(this.themeColor) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
          .onClick(() => router.pushUrl({ url: 'pages/NavNodes' }))
        Row() { Text('搜索选项').fontSize(16).layoutWeight(1); Text('默认搜索类型').fontSize(14).fontColor(this.themeColor) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
          .onClick(() => router.pushUrl({ url: 'pages/SearchOptions' }))
        Row() { Text('回复排序').fontSize(16).layoutWeight(1); Text('详情页回复顺序').fontSize(14).fontColor(this.themeColor) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
          .onClick(() => router.pushUrl({ url: 'pages/SortTabs' }))
        Row() { Text('清除最近浏览').fontSize(16).layoutWeight(1); Button('清除').fontSize(13).onClick(() => { this.recentJson = '[]'; this.status = '最近浏览已清除'; }) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 12 })
        Row() { Text('问题反馈').fontSize(16).layoutWeight(1); Text('GitHub').fontSize(14).fontColor(this.themeColor) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
          .onClick(() => router.pushUrl({ url: 'pages/WebViewPage', params: { title: '问题反馈', url: 'https://github.com/liaoliao666/v2ex/issues' } }))
        Row() { Text('社区排行').fontSize(16).layoutWeight(1); Text('查看').fontSize(14).fontColor(this.themeColor) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
          .onClick(() => router.pushUrl({ url: 'pages/Rank' }))
        Row() { Text('主题屏蔽').fontSize(16).layoutWeight(1); Text('管理').fontSize(14).fontColor(this.themeColor) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
          .onClick(() => router.pushUrl({ url: 'pages/TopicBlockSettings' }))
        Row() { Text('屏蔽列表').fontSize(16).layoutWeight(1); Text('用户与忽略主题').fontSize(14).fontColor(this.themeColor) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
          .onClick(() => router.pushUrl({ url: 'pages/BlackList' }))
        Row() { Text('图片上传').fontSize(16).layoutWeight(1); Text('Imgur').fontSize(14).fontColor(this.themeColor) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
          .onClick(() => router.pushUrl({ url: 'pages/ImgurConfig' }))
        Row() { Text('域名配置').fontSize(16).layoutWeight(1); Text('V2EX').fontSize(14).fontColor(this.themeColor) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 1 })
          .onClick(() => router.pushUrl({ url: 'pages/ConfigureDomain' }))
        Row() { Text('退出登录').fontSize(16).layoutWeight(1); Button('退出').fontSize(13).onClick(() => { try { webview.WebCookieManager.clearAllCookiesSync(); this.status = '已退出登录'; } catch (_) { this.status = '退出失败'; } }) }
          .width('100%').padding(18).backgroundColor(Color.White).margin({ top: 12 })
        if (this.status.length > 0) Text(this.status).fontSize(13).fontColor(this.themeColor).margin({ top: 16 })
        }.width('100%').padding(20).backgroundColor('#F5F7FA')
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
