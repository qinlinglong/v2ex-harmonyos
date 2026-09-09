import { router } from '@kit.ArkUI';
import { themeBackground, themeInputBackground, themePrimaryText, themeSurface } from '../common/Theme';

@Entry
@Component
struct ConfigureDomain {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
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
        Text('域名配置').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
      }.height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      Column() {
        Text('默认使用 https://www.v2ex.com。自建镜像或代理可在这里配置。').fontSize(14).fontColor('#7B8794').lineHeight(22).width('100%')
        TextInput({ placeholder: 'https://www.v2ex.com', text: this.input }).width('100%').height(50).fontSize(15).fontColor(themePrimaryText(this.darkMode)).placeholderColor('#8A97A6').backgroundColor(themeInputBackground(this.darkMode)).margin({ top: 18 })
          .onChange((value: string) => this.input = value)
        Button('保存').width('100%').margin({ top: 16 }).backgroundColor(this.themeColor).fontColor(Color.White).onClick(() => this.save())
        if (this.status.length > 0) Text(this.status).fontSize(13).fontColor(this.themeColor).margin({ top: 14 })
      }.width('100%').padding(20).backgroundColor(themeSurface(this.darkMode)).margin({ top: 12 })
      Blank()
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
