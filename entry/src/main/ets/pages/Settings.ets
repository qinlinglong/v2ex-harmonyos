import { router } from '@kit.ArkUI';

@Entry
@Component
struct Settings {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @State customColor: string = '#4F7CAC';
  private readonly colors: string[] = ['#4F7CAC', '#5B8C5A', '#C05A73', '#8B6FB0', '#D07A3A'];
  aboutToAppear(): void { this.customColor = this.themeColor; }
  build() {
    Column() {
      Row() { Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back()); Text('设置').fontSize(20).fontWeight(FontWeight.Bold) }
        .height(60).width('100%').backgroundColor(Color.White)
      Column() {
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
      }.width('100%').padding(20).backgroundColor(Color.White).margin({ top: 12 })
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
