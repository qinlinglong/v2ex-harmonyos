import { router } from '@kit.ArkUI';

@Entry
@Component
struct ConfigureDomain {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDomain') domain: string = 'https://www.v2ex.com';
  @State input: string = '';
  @State status: string = '';

  aboutToAppear(): void { this.input = this.domain; }

  private save(): void {
    const value: string = this.input.trim().replace(/\/$/, '');
    if (!/^https?:\/\/[^\s/]+(?:\/[^\s]*)?$/i.test(value)) { this.status = '请输入完整的 http(s) 地址'; return; }
    this.domain = value;
    this.status = '域名已保存，重新加载页面后生效';
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('域名配置').fontSize(20).fontWeight(FontWeight.Bold)
      }.height(60).width('100%').backgroundColor(Color.White)
      Column() {
        Text('默认使用 https://www.v2ex.com。自建镜像或代理可在这里配置。').fontSize(14).fontColor('#7B8794').lineHeight(22).width('100%')
        TextInput({ placeholder: 'https://www.v2ex.com', text: this.input }).width('100%').height(50).fontSize(15).margin({ top: 18 })
          .onChange((value: string) => this.input = value)
        Button('保存').width('100%').margin({ top: 16 }).onClick(() => this.save())
        if (this.status.length > 0) Text(this.status).fontSize(13).fontColor(this.themeColor).margin({ top: 14 })
      }.width('100%').padding(20).backgroundColor(Color.White).margin({ top: 12 })
      Blank()
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
