import { router } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { V2exService, V2exSigninInfo } from '../service/V2exService';
import { themeBackground, themeBodyText, themeInputBackground, themeMutedText, themePrimaryText, themeSecondaryText, themeSurface } from '../common/Theme';
import { V2exMember } from '../model/V2exModels';

@Entry
@Component
struct Login {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exDomain') domain: string = 'https://www.v2ex.com';
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
  @State recognizing: boolean = false;
  private signinInfo: V2exSigninInfo | undefined = undefined;

  aboutToAppear(): void { this.loadSigninInfo(); }

  private siteBase(): string { return this.domain.replace(/\/$/, ''); }

  private async loadSigninInfo(): Promise<void> {
    this.loading = true;
    this.status = '正在获取验证码…';
    try {
      const info: V2exSigninInfo = await V2exService.signinInfo();
      this.signinInfo = info;
      this.captchaUrl = info.captchaUrl;
      this.limited = info.limited;
      this.status = info.limited ? '当前 IP 暂时无法获取验证码，请稍后重试' : '';
    } catch (error) {
      this.signinInfo = undefined;
      this.captchaUrl = '';
      this.status = error instanceof Error ? error.message : '获取验证码失败，请检查网络';
    } finally { this.loading = false; }
  }

  private async captchaBuffer(): Promise<ArrayBuffer> {
    if (this.captchaUrl.length === 0) throw new Error('验证码图片尚未加载');
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(this.captchaUrl, {
        method: http.RequestMethod.GET,
        header: { 'Cookie': V2exService.sessionCookie(), 'Referer': `${this.siteBase()}/signin` },
        connectTimeout: 10000,
        readTimeout: 15000,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      if (response.responseCode < 200 || response.responseCode >= 300 || !(response.result instanceof ArrayBuffer)) {
        throw new Error('验证码图片下载失败');
      }
      return response.result;
    } finally { request.destroy(); }
  }

  private async recognizeCaptcha(): Promise<void> {
    if (this.recognizing || this.captchaUrl.length === 0) return;
    this.recognizing = true;
    this.status = '正在识别验证码…';
    let source: image.ImageSource | undefined;
    let pixelMap: image.PixelMap | undefined;
    try {
      source = image.createImageSource(await this.captchaBuffer());
      if (!source) throw new Error('验证码图片解码失败');
      pixelMap = await source.createPixelMap({ desiredSize: { width: 1280, height: 320 }, desiredPixelFormat: image.PixelMapFormat.RGBA_8888 });
      if (!await textRecognition.init()) throw new Error('此设备未提供 OCR 模型');
      let result: textRecognition.TextRecognitionResult | undefined;
      let lastError: Error | undefined;
      for (let attempt: number = 0; attempt < 2 && result === undefined; attempt += 1) {
        try { result = await textRecognition.recognizeText({ pixelMap }, { isDirectionDetectionSupported: false }); }
        catch (error) {
          lastError = error instanceof Error ? error : new Error(String(error));
          if (attempt === 0) await new Promise<void>((resolve: () => void) => setTimeout(resolve, 350));
        }
      }
      if (result === undefined) throw lastError ?? new Error('验证码识别失败');
      const compact: string = result.value.replace(/[^A-Za-z0-9]/g, '').toUpperCase();
      const candidates: RegExpMatchArray | null = result.value.toUpperCase().match(/[A-Z0-9]{4}/g);
      const candidate: string = compact.length === 4 ? compact : (candidates?.[0] ?? compact.substring(0, 4));
      if (!/^[A-Z0-9]{4}$/.test(candidate)) throw new Error('未识别到 4 位验证码，请点击图片刷新后重试');
      this.code = candidate;
      this.status = `已识别：${candidate}`;
    } catch (error) {
      this.status = error instanceof Error ? `${error.message}，请手动输入` : '验证码识别失败，请手动输入';
    } finally {
      if (pixelMap) await pixelMap.release();
      if (source) await source.release();
      try { await textRecognition.release(); } catch (_) { /* OCR may be unavailable on this device. */ }
      this.recognizing = false;
    }
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
      this.status = error instanceof Error ? error.message : '登录失败，请检查输入';
      await this.loadSigninInfo();
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
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text(this.twoFactorOnce.length > 0 ? '两步验证' : '登录 V2EX').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
        Blank()
        if (this.twoFactorOnce.length === 0) Text(this.recognizing ? '识别中…' : '识别验证码').fontSize(13).fontColor(this.themeColor)
          .enabled(!this.recognizing && !this.loading).padding({ left: 10, right: 14 }).onClick(() => this.recognizeCaptcha())
      }.height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      if (this.twoFactorOnce.length > 0) {
        Scroll() {
          Column() {
            Text('你的 V2EX 账号已开启两步验证，请输入验证码继续。').fontSize(16).fontColor(themePrimaryText(this.darkMode)).width('100%').lineHeight(24)
            TextInput({ placeholder: '请输入两步验证码', text: this.twoFactorCode }).width('100%').height(52).margin({ top: 20 }).fontSize(16).fontColor(themePrimaryText(this.darkMode)).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode)).onChange((value: string) => this.twoFactorCode = value)
            Button(this.submitting ? '验证中…' : '继续登录').width('100%').height(48).margin({ top: 16 }).backgroundColor(this.themeColor).fontColor(Color.White).onClick(() => this.submitTwoFactor())
            Text('出于安全考虑，开启两步验证后需要定期输入验证码续期。').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).width('100%').lineHeight(22).margin({ top: 18 })
          }.width('82%').padding({ top: 28, bottom: 28 })
        }.layoutWeight(1).width('100%')
      } else {
        Scroll() {
          Column() {
            if (this.limited) {
              Text('登录受限').fontSize(28).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode)).width('100%')
              Text('由于当前 IP 在短时间内的登录尝试次数太多，暂时不能继续尝试。').fontSize(15).fontColor(themeBodyText(this.darkMode)).width('100%').lineHeight(24).margin({ top: 10 })
              Button(this.loading ? '重试中…' : '重试').width('100%').height(48).margin({ top: 24 }).backgroundColor(this.themeColor).fontColor(Color.White).onClick(() => this.loadSigninInfo())
            } else {
              Text('登录 V2EX').fontSize(26).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode)).width('100%')
              Text('使用用户名或电子邮件地址登录。').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).width('100%').margin({ top: 6, bottom: 22 })
              Text('用户名').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).width('100%')
              TextInput({ placeholder: '用户名或电子邮件地址', text: this.username }).width('100%').height(52).margin({ top: 6 }).fontSize(16).fontColor(themePrimaryText(this.darkMode)).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode)).onChange((value: string) => this.username = value)
              Text('密码').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).width('100%').margin({ top: 16 })
              TextInput({ placeholder: '请输入密码', text: this.password }).width('100%').height(52).margin({ top: 6 }).fontSize(16).fontColor(themePrimaryText(this.darkMode)).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode)).type(InputType.Password).showPasswordIcon(true).onChange((value: string) => this.password = value)
              Text('你是机器人吗？').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).width('100%').margin({ top: 16 })
              if (this.captchaUrl.length > 0) {
                Image(this.captchaUrl).width('100%').height(128).margin({ top: 6 }).borderRadius(8).objectFit(ImageFit.Fill).onClick(() => this.loadSigninInfo())
              } else {
                Text('点击刷新验证码').width('100%').height(128).margin({ top: 6 }).textAlign(TextAlign.Center).fontColor(themeSecondaryText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode)).borderRadius(8).onClick(() => this.loadSigninInfo())
              }
              TextInput({ placeholder: '请输入上图中的验证码，点击图片可更换', text: this.code }).width('100%').height(52).margin({ top: 8 }).fontSize(16).fontColor(themePrimaryText(this.darkMode)).placeholderColor(themeMutedText(this.darkMode)).backgroundColor(themeInputBackground(this.darkMode)).onChange((value: string) => this.code = value)
              if (this.status.length > 0) Text(this.status).fontSize(13).fontColor(this.themeColor).width('100%').lineHeight(20).margin({ top: 12 })
              Button(this.submitting ? '登录中…' : '登录').width('100%').height(48).margin({ top: 16 }).backgroundColor(this.themeColor).fontColor(Color.White).enabled(!this.loading && !this.submitting).onClick(() => this.submitSignin())
              Row() {
                Text(this.agreed ? '☑' : '□').fontSize(21).fontColor(this.themeColor).margin({ right: 8 })
                Text('我已阅读并同意').fontSize(13).fontColor(themeSecondaryText(this.darkMode))
                Text('《用户协议》').fontSize(13).fontColor(this.themeColor).onClick(() => router.pushUrl({ url: 'pages/GitHubMD', params: { url: 'https://raw.githubusercontent.com/liaoliao666/v2ex/main/terms-and-conditions_zh.md', title: '用户协议' } }))
                Text('和').fontSize(13).fontColor(themeSecondaryText(this.darkMode))
                Text('《隐私政策》').fontSize(13).fontColor(this.themeColor).onClick(() => router.pushUrl({ url: 'pages/GitHubMD', params: { url: 'https://raw.githubusercontent.com/liaoliao666/v2ex/main/privacy-policy_zh.md', title: '隐私政策' } }))
              }.width('100%').margin({ top: 18 }).onClick(() => this.agreementRow())
            }
          }.width('82%').padding({ top: 28, bottom: 32 })
        }.layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
