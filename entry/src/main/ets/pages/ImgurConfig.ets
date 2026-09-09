import { router } from '@kit.ArkUI';
import { themeBackground, themeInputBackground, themePrimaryText, themeSurface } from '../common/Theme';

@Entry
@Component
struct ImgurConfig {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exImgurClientId') clientId: string = '';
  @State input: string = '';
  @State status: string = '';

  aboutToAppear(): void { this.input = this.clientId; }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('图片上传').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
      }.height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      Scroll() {
        Column() {
          Text('图片上传使用 Imgur API。请先创建 Imgur 应用并填写 Client ID。').fontSize(14).fontColor('#7B8794').width('100%').lineHeight(22)
          TextInput({ placeholder: 'Imgur Client ID', text: this.input }).width('100%').height(50).fontSize(15).fontColor(themePrimaryText(this.darkMode)).placeholderColor('#8A97A6').backgroundColor(themeInputBackground(this.darkMode)).margin({ top: 18 })
            .onChange((value: string) => this.input = value)
          Button('保存配置').width('100%').margin({ top: 16 }).backgroundColor(this.themeColor).fontColor(Color.White).onClick(() => { this.clientId = this.input.trim(); this.status = this.clientId.length > 0 ? '配置已保存' : '请输入 Client ID'; })
          if (this.status.length > 0) Text(this.status).fontSize(13).fontColor(this.themeColor).margin({ top: 14 })
          Text('上传图片后会自动插入 Markdown：![图片](图片地址)').fontSize(13).fontColor('#8A97A6').width('100%').margin({ top: 28 })
        }.width('100%').padding(20)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
