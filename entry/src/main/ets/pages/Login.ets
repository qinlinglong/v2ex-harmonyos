import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { themeBackground, themePrimaryText, themeSurface } from '../common/Theme';

@Entry
@Component
struct Login {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exDomain') domain: string = 'https://www.v2ex.com';
  private controller: webview.WebviewController = new webview.WebviewController();
  @State captchaStatus: string = '';
  @State recognizingCaptcha: boolean = false;

  private siteBase(): string {
    return this.domain.replace(/\/$/, '');
  }

  private async captchaBuffer(): Promise<ArrayBuffer> {
    let sourceResult: string = await this.controller.runJavaScript(`(() => {
      const image = document.getElementById('captcha-image');
      return image ? (image.currentSrc || image.src || '') : '';
    })()`);
    if ((sourceResult ?? '').trim().length === 0) {
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 500));
      sourceResult = await this.controller.runJavaScript(`(() => {
        const image = document.getElementById('captcha-image');
        return image ? (image.currentSrc || image.src || '') : '';
      })()`);
    }
    const source: string = (sourceResult ?? '').replace(/^['"]|['"]$/g, '').trim();
    if (source.length === 0) throw new Error('验证码图片尚未加载');
    const url: string = /^https?:\/\//i.test(source) ? source : `${this.siteBase()}${source.startsWith('/') ? source : `/${source}`}`;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { Cookie: webview.WebCookieManager.fetchCookieSync(this.siteBase()) || '' },
        connectTimeout: 10000,
        readTimeout: 15000,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      if (response.responseCode < 200 || response.responseCode >= 300) throw new Error(`验证码请求失败 (${response.responseCode})`);
      if (!(response.result instanceof ArrayBuffer)) throw new Error('验证码返回格式异常');
      return response.result;
    } finally {
      request.destroy();
    }
  }

  private async recognizeCaptcha(): Promise<void> {
    if (this.recognizingCaptcha) return;
    this.recognizingCaptcha = true;
    this.captchaStatus = '正在识别验证码…';
    let source: image.ImageSource | undefined;
    let pixelMap: image.PixelMap | undefined;
    try {
      const buffer: ArrayBuffer = await this.captchaBuffer();
      source = image.createImageSource(buffer);
      if (!source) throw new Error('验证码图片解码失败');
      // V2EX serves a compact 320×80 bitmap; upscale it before OCR so thin glyphs
      // remain legible on devices whose OCR model has a larger minimum text size.
      pixelMap = await source.createPixelMap({
        desiredSize: { width: 1280, height: 320 },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const ready: boolean = await textRecognition.init();
      if (!ready) throw new Error('此设备未提供 OCR 模型');
      let result: textRecognition.TextRecognitionResult | undefined;
      let lastError: Error | undefined;
      for (let attempt: number = 0; attempt < 2 && result === undefined; attempt += 1) {
        try {
          result = await textRecognition.recognizeText({ pixelMap }, { isDirectionDetectionSupported: false });
        } catch (error) {
          lastError = error instanceof Error ? error : new Error(String(error));
          if (attempt === 0) await new Promise<void>((resolve: () => void) => setTimeout(resolve, 350));
        }
      }
      if (result === undefined) throw lastError ?? new Error('验证码识别失败');
      const code: string = result.value.replace(/[^A-Za-z0-9]/g, '').toUpperCase();
      if (!/^[A-Z0-9]{4}$/.test(code)) throw new Error('未识别到 4 位验证码，请点击图片刷新后重试');
      const filled: string = await this.controller.runJavaScript(`(() => {
        const input = Array.from(document.querySelectorAll('input')).find((item) => {
          const element = item as HTMLInputElement;
          return element.placeholder?.includes('code') || element.name.length > 20 && element.type === 'text';
        }) as HTMLInputElement | undefined;
        if (!input) return 'false';
        input.focus();
        input.value = '${code}';
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.dispatchEvent(new Event('change', { bubbles: true }));
        return 'true';
      })()`);
      if (filled !== 'true') throw new Error('未找到验证码输入框');
      this.captchaStatus = `已识别：${code}`;
    } catch (error) {
      const detail: Record<string, Object> = (error ?? {}) as Record<string, Object>;
      const code: string = detail['code'] !== undefined ? ` (${String(detail['code'])})` : '';
      const message: string = detail['message'] !== undefined ? String(detail['message']) : (error instanceof Error ? error.message : '验证码识别失败');
      this.captchaStatus = `${message}${code}，请手动输入`;
    } finally {
      if (pixelMap) await pixelMap.release();
      if (source) await source.release();
      try { await textRecognition.release(); } catch (_) { /* OCR may be unavailable on this device. */ }
      this.recognizingCaptcha = false;
    }
  }

  private applyWebTheme(): void {
    const background: string = this.darkMode ? '#0F141A' : '#FFFFFF';
    const surface: string = this.darkMode ? '#18202A' : '#FFFFFF';
    const input: string = this.darkMode ? '#26313D' : '#F1F4F7';
    const text: string = this.darkMode ? '#F2F5F8' : '#202124';
    const muted: string = this.darkMode ? '#AAB7C4' : '#7B8794';
    const css: string = `body { background:${background} !important; color:${text} !important; }
      body * { color:${text}; }
      a, .fade, .small, .normal { color:${muted} !important; }
      input, textarea, select { background:${input} !important; color:${text} !important; border-color:${muted} !important; }
      button, input[type=submit], .button { background:${this.themeColor} !important; color:#FFFFFF !important; border-color:${this.themeColor} !important; }
      .box, .cell, .content, .topic_content { background:${surface} !important; color:${text} !important; }`;
    const script: string = `(() => { let style = document.getElementById('v2ex-native-theme'); if (!style) { style = document.createElement('style'); style.id = 'v2ex-native-theme'; document.head.appendChild(style); } style.textContent = ${JSON.stringify(css)}; return 'ok'; })()`;
    this.controller.runJavaScript(script).catch(() => { /* The page may have navigated away. */ });
  }

  onPageShow(): void {
    this.applyWebTheme();
    setTimeout(() => this.applyWebTheme(), 800);
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('登录 V2EX').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode))
        Blank()
        Text(this.recognizingCaptcha ? '识别中…' : '识别验证码').fontSize(13).fontColor(this.themeColor)
          .padding({ left: 10, right: 14 }).enabled(!this.recognizingCaptcha)
          .onClick(() => this.recognizeCaptcha())
      }.height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      if (this.captchaStatus.length > 0) {
        Text(this.captchaStatus).fontSize(12).fontColor(this.themeColor).width('100%')
          .padding({ left: 16, right: 16, top: 5, bottom: 5 }).backgroundColor(this.darkMode ? '#26313D' : '#EEF4FB')
      }
      Web({ src: `${this.domain.replace(/\/$/, '')}/signin`, controller: this.controller })
        .javaScriptAccess(true).domStorageAccess(true).layoutWeight(1).width('100%')
        .onPageEnd((event: OnPageEndEvent) => {
          this.applyWebTheme();
          setTimeout(() => this.applyWebTheme(), 800);
          if (event.url.indexOf(this.domain.replace(/^https?:\/\//, '').replace(/\/$/, '')) >= 0 && event.url.indexOf('/signin') < 0 &&
            event.url.indexOf('/recover') < 0) {
            setTimeout(() => router.back(), 300);
          }
        })
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
