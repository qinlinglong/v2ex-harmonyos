import { router } from '@kit.ArkUI';

@Entry
@Component
struct CustomizeTheme {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @State customColor: string = '#4F7CAC';
  private readonly colors: string[] = ['#4F7CAC', '#FB7299', '#00AEEC', '#51A775', '#8B6FB0', '#D07A3A'];

  aboutToAppear(): void { this.customColor = this.themeColor; }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('主题设置').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
      }.height(60).width('100%').backgroundColor(Color.White)
      Scroll() {
        Column() {
          Text('选择主题色').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#202124').width('100%').margin({ bottom: 18 })
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.colors, (color: string) => Row() {
              Column().width(42).height(42).borderRadius(21).backgroundColor(color)
              Text(color).fontSize(12).fontColor('#66727F').margin({ left: 8 })
            }.width('50%').height(58).onClick(() => this.themeColor = color), (color: string) => color)
          }.width('100%')
          Text('自定义颜色').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#202124').width('100%').margin({ top: 22, bottom: 12 })
          Row() {
            TextInput({ placeholder: '#RRGGBB', text: this.customColor }).layoutWeight(1).height(46).fontColor('#202124').placeholderColor('#8A97A6').backgroundColor('#F1F4F7')
              .onChange((value: string) => this.customColor = value)
            Button('应用').margin({ left: 10 }).onClick(() => {
              if (/^#[0-9A-Fa-f]{6}$/.test(this.customColor.trim())) this.themeColor = this.customColor.trim();
            })
          }.width('100%')
          Text('主题设置会保存到本机，并应用到首页、详情、节点、个人中心和设置页面。')
            .fontSize(13).fontColor('#8A97A6').lineHeight(21).width('100%').margin({ top: 18 })
        }.width('100%').padding(20)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
