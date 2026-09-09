import { router } from '@kit.ArkUI';
import { V2exService } from '../service/V2exService';
import { themeAccentText, themeBackground, themeInputBackground, themeMutedText, themePrimaryText, themeSecondaryText, themeSurface, themeOnColor } from '../common/Theme';

@Entry
@Component
struct ImgurConfig {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exImgurClientId') clientId: string = '';
  @StorageLink('v2exImageBed') imageBed: string = 'imgur';
  @State input: string = '';
  @State status: string = '';

  aboutToAppear(): void { this.input = this.clientId; }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(themeAccentText(this.themeColor, this.darkMode)).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('图片上传').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
      }.height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      Scroll() {
        Column() {
          Text('选择默认图床，发帖时会自动使用当前图床上传图片。').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).width('100%').lineHeight(22)
          Row() {
            Button('Imgur').layoutWeight(1).backgroundColor(this.imageBed === 'imgur' ? this.themeColor : themeInputBackground(this.darkMode)).fontColor(this.imageBed === 'imgur' ? themeOnColor(this.themeColor) : themePrimaryText(this.darkMode)).onClick(() => this.imageBed = 'imgur')
            Button('Bilibili').layoutWeight(1).margin({ left: 10 }).backgroundColor(this.imageBed === 'bilibili' ? this.themeColor : themeInputBackground(this.darkMode)).fontColor(this.imageBed === 'bilibili' ? themeOnColor(this.themeColor) : themePrimaryText(this.darkMode)).onClick(() => this.imageBed = 'bilibili')
          }.width('100%').margin({ top: 18 })
          if (this.imageBed === 'imgur') {
            Text('Imgur 使用 Client ID 上传，密钥只保存在本机。').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).width('100%').margin({ top: 18 })
            TextInput({ placeholder: 'Imgur Client ID', text: this.input }).width('100%').height(50).fontSize(15).fontColor(themePrimaryText(this.darkMode)).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode)).margin({ top: 12 })
              .onChange((value: string) => this.input = value)
            Button('保存 Imgur 配置').width('100%').margin({ top: 16 }).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => { this.clientId = this.input.trim(); this.status = this.clientId.length > 0 ? 'Imgur 配置已保存' : '请输入 Client ID'; })
          } else {
            Text('Bilibili 图床需要先登录 Bilibili，登录状态通过系统 Cookie 保存。').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).width('100%').lineHeight(22).margin({ top: 18 })
            Button(V2exService.biliLoggedIn() ? '已登录，重新登录' : '登录 Bilibili 图床').width('100%').margin({ top: 16 }).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => router.pushUrl({ url: 'pages/BilibiliLogin' }))
          }
          if (this.status.length > 0) Text(this.status).fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode)).margin({ top: 14 })
          Text('上传图片后会自动插入 Markdown：![图片](图片地址)').fontSize(13).fontColor(themeMutedText(this.darkMode)).width('100%').margin({ top: 28 })
        }.width('100%').padding(20)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
