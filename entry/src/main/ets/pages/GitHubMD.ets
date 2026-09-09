import { router } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { themeBackground, themeBodyText, themeMutedText, themePrimaryText, themeSurface } from '../common/Theme';

@Entry
@Component
struct GitHubMD {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @State title: string = 'Markdown 帮助';
  @State content: string = '**粗体文字**\n*斜体文字*\n`行内代码`\n\n- 无序列表\n1. 有序列表\n\n[链接文字](https://www.v2ex.com)';
  @State loading: boolean = false;
  @State status: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    const url: string = String(params?.['url'] ?? '');
    this.title = String(params?.['title'] ?? 'Markdown 帮助');
    if (/^https?:\/\//i.test(url)) this.loadDocument(url);
  }

  private async loadDocument(url: string): Promise<void> {
    this.loading = true;
    this.status = '正在加载文档…';
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'text/plain,text/markdown,*/*', 'User-Agent': 'V2EX-HarmonyOS/1.0' },
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      if (response.responseCode < 200 || response.responseCode >= 300) throw new Error(`文档加载失败 (${response.responseCode})`);
      const value: string = String(response.result ?? '').trim();
      if (value.length === 0) throw new Error('文档内容为空');
      this.content = value;
      this.status = '';
    } catch (error) {
      this.status = error instanceof Error ? error.message : '文档加载失败，请稍后重试';
    } finally {
      request.destroy();
      this.loading = false;
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text(this.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode)).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      Scroll() {
        Column() {
          if (this.loading) Text(this.status).fontSize(14).fontColor(themeMutedText(this.darkMode)).width('100%')
          if (this.status.length > 0 && !this.loading) Text(this.status).fontSize(14).fontColor(this.themeColor).width('100%').lineHeight(22)
          Text(this.content).fontSize(16).fontColor(themeBodyText(this.darkMode)).lineHeight(29).width('100%').padding(16).backgroundColor(themeSurface(this.darkMode)).margin({ top: 12 })
        }.width('100%').padding(20)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
