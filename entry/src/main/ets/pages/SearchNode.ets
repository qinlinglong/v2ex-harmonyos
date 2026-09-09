import { router } from '@kit.ArkUI';
import { V2exNode } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';
import { themeBackground, themeInputBackground, themePrimaryText, themeSurface } from '../common/Theme';

@Entry
@Component
struct SearchNode {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @State query: string = '';
  @State nodes: V2exNode[] = [];
  @State loading: boolean = true;
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> { try { this.nodes = await V2exService.nodes(); } finally { this.loading = false; } }
  private filtered(): V2exNode[] { const q = this.query.trim().toLowerCase(); return q.length === 0 ? this.nodes : this.nodes.filter((n: V2exNode) => `${n.title} ${n.name}`.toLowerCase().includes(q)); }
  build() {
    Column() {
      Row() { Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back()); Text('搜索节点').fontSize(20).fontWeight(FontWeight.Bold).fontColor(themePrimaryText(this.darkMode)) }
        .height(60).width('100%').backgroundColor(themeSurface(this.darkMode))
      TextInput({ placeholder: '搜索节点名称或英文标识', text: this.query }).width('100%').height(48).margin(16).fontColor(themePrimaryText(this.darkMode)).placeholderColor('#8A97A6').backgroundColor(themeInputBackground(this.darkMode)).onChange((v: string) => this.query = v)
      if (this.loading) LoadingProgress().width(32).height(32).color(this.themeColor).margin({ top: 32 })
      else List({ space: 1 }) { ForEach(this.filtered(), (node: V2exNode) => ListItem() {
        Row() { Text(node.title).fontSize(16).fontColor(themePrimaryText(this.darkMode)).layoutWeight(1); Text(node.name).fontSize(13).fontColor('#8A97A6') }.width('100%').padding(16).backgroundColor(themeSurface(this.darkMode))
      }.onClick(() => router.pushUrl({ url: 'pages/NodeTopics', params: { name: node.name, title: node.title } })), (node: V2exNode) => node.name) }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(themeBackground(this.darkMode))
  }
}
