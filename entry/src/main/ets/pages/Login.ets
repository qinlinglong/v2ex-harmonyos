import { router } from '@kit.ArkUI';
import { V2exService, V2exSigninInfo } from '../service/V2exService';
import { themeAccentText, themeBackground, themeBodyText, themeInputBackground, themeMutedText, themePrimaryText, themeSecondaryText, themeSurface, themeOnColor } from '../common/Theme';
import { V2exMember } from '../model/V2exModels';

@Entry
@Component
struct Login {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exCachedMember') cachedMemberJson: string = '';
  @State username: string = '';
  @State password: string = '';
  @State code: string = '';
  @State twoFactorCode: string = '';
  @State twoFactorOnce: string = '';
  @State agreed: boolean = false;
  @State captchaUrl: string = '';
  @State status: string = '';
  @State loading: boolean = true;
  @State limited: boolean = false;
  @State submitting: boolean = false;
  @State captchaImage: string = '';
  @State h5FallbackOpened: boolean = false;
  private signinInfo: V2exSigninInfo | undefined = undefined;
  private signinInfoLoadedAt: number = 0;

  aboutToAppear(): void { this.loadSigninInfo(); }

  onPageShow(): void {
    if (this.h5FallbackOpened) {
      this.h5FallbackOpened = false;
      this.syncH5Member();
      return;
    }
    // V2EX's hidden once token is short-lived. Refresh the form when the
    // native page is shown again after being left open, matching the
    // reference client's staleTime: 0 sign-in query behavior.
    if (this.signinInfo !== undefined && (this.signinInfoLoadedAt === 0 || Date.now() - this.signinInfoLoadedAt > 60_000)) {
      this.loadSigninInfo();
    }
  }

  private async syncH5Member(): Promise<void> {
    try {
      const member: V2exMember | undefined = await V2exService.currentMember();
      if (!member) return;
      this.cachedMemberJson = JSON.stringify(member);
      this.status = '登录成功';
      setTimeout(() => router.back(), 250);
    } catch (_) { /* remain on the native login page when H5 is not signed in */ }
  }

  private openH5Signin(): void {
    this.h5FallbackOpened = true;
    router.pushUrl({ url: 'pages/WebViewPage', params: { title: '登录 V2EX', url: 'https://www.v2ex.com/signin' } });
  }

  private async loadSigninInfo(): Promise<void> {
    this.loading = true;
    // A challenge is single-use. Clear the previous answer whenever the
    // image is refreshed, including after a rejected submission, so a new
    // code can never be appended to the expired one.
    this.code = '';
    this.status = '正在获取验证码…';
    try {
      const info: V2exSigninInfo = await V2exService.signinInfo();
      this.signinInfo = info;
      this.signinInfoLoadedAt = Date.now();
      this.captchaUrl = info.captchaUrl;
      // Do not render the challenge URL before the native download finishes.
      // Rendering it here would make ArkUI issue a second GET while
      // signinCaptcha() is fetching the same URL, and some V2EX deployments
      // generate a new challenge for every request.
      this.captchaImage = '';
      this.limited = info.limited;
      this.status = info.limited ? '当前 IP 登录尝试次数过多，可能需要等待最多 1 天后重试' : '';
      if (!info.limited && info.captchaUrl.length > 0) {
        try { this.captchaImage = await V2exService.signinCaptcha(info.captchaUrl); }
        catch (_) {
          // ArkUI can load the challenge URL directly even on devices where
          // NetworkKit rejects the binary response. Keep the URL as a
          // session-paired fallback so native sign-in remains usable.
          this.captchaImage = info.captchaUrl;
          this.status = '验证码已就绪，请输入图片中的字符';
        }
      }
    } catch (error) {
      this.signinInfo = undefined;
      this.captchaUrl = '';
      this.captchaImage = '';
      this.status = error instanceof Error ? error.message : '获取验证码失败，请检查网络';
    } finally { this.loading = false; }
  }

  private async submitSignin(): Promise<void> {
    if (this.submitting || this.signinInfo === undefined) return;
    if (!this.agreed) { this.status = '请勾选同意《用户协议》和《隐私政策》后登录'; return; }
    if (this.username.trim().length === 0 || this.password.length === 0 || this.code.trim().length === 0) {
      this.status = '请完整填写用户名、密码和验证码';
      return;
    }
    this.submitting = true;
    this.status = '登录中…';
    try {
      const result = await V2exService.signin(this.signinInfo, this.username.trim(), this.password, this.code.trim());
      if (result.twoFactor) {
        this.twoFactorOnce = result.once;
        this.status = '请输入两步验证码';
        return;
      }
      if (!result.success) throw new Error('登录失败');
      if (result.member) this.cachedMemberJson = JSON.stringify(result.member);
      this.status = '登录成功';
      setTimeout(() => router.back(), 250);
    } catch (error) {
      const message: string = error instanceof Error ? error.message : '登录失败，请检查输入';
      await this.loadSigninInfo();
      this.status = message;
    } finally { this.submitting = false; }
  }

  private async submitTwoFactor(): Promise<void> {
    if (this.submitting || this.twoFactorOnce.length === 0 || this.twoFactorCode.trim().length === 0) return;
    this.submitting = true;
    this.status = '验证中…';
    try {
      const member: V2exMember | undefined = await V2exService.signinTwoFactor(this.twoFactorOnce, this.twoFactorCode.trim());
      if (!member) throw new Error('两步验证码错误或已过期');
      this.cachedMemberJson = JSON.stringify(member);
      this.status = '登录成功';
      setTimeout(() => router.back(), 250);
    } catch (error) {
      this.status = error instanceof Error ? error.message : '两步验证码错误';
    } finally { this.submitting = false; }
  }

  private agreementRow(): void { this.agreed = !this.agreed; }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(themeAccentText(this.themeColor, this.darkMode)).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text(this.twoFactorOnce.length > 0 ? '两步验证' : '登录 V2EX').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
        Blank()
      }.height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      if (this.twoFactorOnce.length > 0) {
        Scroll() {
          Column() {
            Text('你的 V2EX 账号已开启两步验证，请输入验证码继续。').fontSize(16).fontColor(themePrimaryText(this.darkMode)).width('100%').lineHeight(24)
            TextInput({ placeholder: '请输入两步验证码', text: this.twoFactorCode }).width('100%').height(52).margin({ top: 20 }).fontSize(16).fontColor(themePrimaryText(this.darkMode)).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode)).onChange((value: string) => this.twoFactorCode = value)
            Button(this.submitting ? '验证中…' : '继续登录').width('100%').height(48).margin({ top: 16 }).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.submitTwoFactor())
            Text('出于安全考虑，开启两步验证后需要定期输入验证码续期。').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).width('100%').lineHeight(22).margin({ top: 18 })
          }.width('82%').padding({ top: 28, bottom: 28 })
        }.layoutWeight(1).width('100%')
      } else {
        Scroll() {
          Column() {
            if (this.limited) {
              Text('登录受限').fontSize(28).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode)).width('100%')
              Text('由于当前 IP 在短时间内的登录尝试次数太多，暂时不能继续尝试，可能需要等待最多 1 天。').fontSize(15).fontColor(themeBodyText(this.darkMode)).width('100%').lineHeight(24).margin({ top: 10 })
              Button(this.loading ? '重试中…' : '重试').width('100%').height(48).margin({ top: 24 }).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.loadSigninInfo())
              Text('打开 H5 登录').fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode))
                .width('100%').textAlign(TextAlign.Center).margin({ top: 18 })
                .onClick(() => this.openH5Signin())
            } else {
              Text('登录 V2EX').fontSize(26).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode)).width('100%')
              Text('使用用户名或电子邮件地址登录。').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).width('100%').margin({ top: 6, bottom: 22 })
              Text('用户名').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).width('100%')
              TextInput({ placeholder: '用户名或电子邮件地址', text: this.username }).width('100%').height(52).margin({ top: 6 }).fontSize(16).fontColor(themePrimaryText(this.darkMode)).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode)).type(InputType.Email).onChange((value: string) => this.username = value)
              Text('密码').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).width('100%').margin({ top: 16 })
              TextInput({ placeholder: '请输入密码', text: this.password }).width('100%').height(52).margin({ top: 6 }).fontSize(16).fontColor(themePrimaryText(this.darkMode)).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode)).type(InputType.Password).showPasswordIcon(true).onChange((value: string) => this.password = value)
              Text('你是机器人吗？').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).width('100%').margin({ top: 16 })
              if (this.captchaUrl.length > 0) {
                Image(this.captchaImage).width('100%').aspectRatio(4).margin({ top: 6 }).borderRadius(8).objectFit(ImageFit.Fill).onClick(() => this.loadSigninInfo())
              } else {
                Text('点击刷新验证码').width('100%').aspectRatio(4).margin({ top: 6 }).textAlign(TextAlign.Center).fontColor(themeSecondaryText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode)).borderRadius(8).onClick(() => this.loadSigninInfo())
              }
              TextInput({ placeholder: '请输入上图中的验证码，点击图片可更换', text: this.code }).width('100%').height(52).margin({ top: 8 }).fontSize(16).fontColor(themePrimaryText(this.darkMode)).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode)).type(InputType.Email).onChange((value: string) => this.code = value)
              if (this.status.length > 0) Text(this.status).fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode)).width('100%').lineHeight(20).margin({ top: 12 })
              Button(this.submitting ? '登录中…' : '登录').width('100%').height(48).margin({ top: 16 }).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor))
                .enabled(!this.loading && !this.submitting && this.signinInfo !== undefined && !this.limited)
                .onClick(() => this.submitSignin())
              Row() {
                Text(this.agreed ? '☑' : '□').fontSize(21).fontColor(themeAccentText(this.themeColor, this.darkMode)).margin({ right: 8 })
                Text('我已阅读并同意').fontSize(13).fontColor(themeSecondaryText(this.darkMode))
                Text('《用户协议》').fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode)).onClick(() => router.pushUrl({ url: 'pages/WebViewPage', params: { url: 'https://www.v2ex.com/terms', title: '用户协议' } }))
                Text('和').fontSize(13).fontColor(themeSecondaryText(this.darkMode))
                Text('《隐私政策》').fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode)).onClick(() => router.pushUrl({ url: 'pages/WebViewPage', params: { url: 'https://www.v2ex.com/about', title: '隐私政策' } }))
              }.width('100%').margin({ top: 18 }).onClick(() => this.agreementRow())
              Text('无法完成原生登录？打开 H5 登录').fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode))
                .width('100%').textAlign(TextAlign.Center).margin({ top: 18 })
                .onClick(() => this.openH5Signin())
            }
          }.width('82%').padding({ top: 28, bottom: 32 })
        }.layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
