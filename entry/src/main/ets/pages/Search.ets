import { router } from '@kit.ArkUI';
import { V2exMember, V2exTopic } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';

@Entry
@Component
struct SearchPage {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @State query: string = '';
  @State mode: number = 0;
  @State topics: V2exTopic[] = [];
  @State members: V2exMember[] = [];
  @State loading: boolean = false;
  @State status: string = '输入关键词搜索主题或用户';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    this.query = String(params?.['query'] ?? '');
    if (this.query.length > 0) this.submit();
  }

  private async submit(): Promise<void> {
    if (this.query.trim().length === 0 || this.loading) return;
    this.loading = true;
    this.status = '';
    try {
      if (this.mode === 0) {
        this.topics = await V2exService.searchTopics(this.query.trim());
        if (this.topics.length === 0) this.status = '没有找到匹配主题';
      } else {
        this.members = await V2exService.searchMembers(this.query.trim());
        if (this.members.length === 0) this.status = '没有找到匹配用户';
      }
    } catch (_) { this.status = '搜索失败，请稍后重试'; }
    finally { this.loading = false; }
  }

  @Builder
  topicRow(topic: V2exTopic) {
    ListItem() {
      Column() {
        Text(topic.title).fontSize(16).fontColor('#202124').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${topic.member?.username ?? '匿名'} · ${topic.node?.title ?? 'V2EX'} · ${topic.replies} 回复`).fontSize(12).fontColor('#8A97A6').margin({ top: 7 })
      }.width('100%').padding({ left: 18, right: 18, top: 14, bottom: 14 }).backgroundColor(Color.White)
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: topic.id } }))
  }

  @Builder
  memberRow(member: V2exMember) {
    ListItem() {
      Row() {
        Text(member.username.substring(0, 1).toUpperCase()).fontSize(13).fontColor(Color.White)
          .width(36).height(36).textAlign(TextAlign.Center).backgroundColor('#B7C4D2').borderRadius(18)
        Text(member.username).fontSize(16).fontColor('#202124').margin({ left: 12 })
      }.width('100%').padding({ left: 18, right: 18, top: 14, bottom: 14 }).backgroundColor(Color.White)
    }.onClick(() => router.pushUrl({ url: 'pages/Profile', params: { username: member.username } }))
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('搜索').fontSize(20).fontWeight(FontWeight.Bold)
      }.height(60).width('100%').backgroundColor(Color.White)
      Row() {
        TextInput({ placeholder: '搜索主题、正文或用户名', text: this.query }).layoutWeight(1).height(46).fontSize(15)
          .onChange((value: string) => this.query = value).onSubmit(() => this.submit())
        Button('搜索').fontSize(14).margin({ left: 10 }).onClick(() => this.submit())
      }.width('100%').padding(16).backgroundColor(Color.White)
      Row() {
        Text('主题').fontSize(15).fontColor(this.mode === 0 ? this.themeColor : '#7B8794').layoutWeight(1).textAlign(TextAlign.Center).onClick(() => this.mode = 0)
        Text('用户').fontSize(15).fontColor(this.mode === 1 ? this.themeColor : '#7B8794').layoutWeight(1).textAlign(TextAlign.Center).onClick(() => this.mode = 1)
      }.height(48).width('100%').backgroundColor(Color.White)
      if (this.loading) LoadingProgress().width(30).height(30).color(this.themeColor).margin({ top: 40 })
      else if (this.status.length > 0) Text(this.status).fontSize(15).fontColor('#7B8794').margin({ top: 46 })
      else if (this.mode === 0) List({ space: 1 }) { ForEach(this.topics, (topic: V2exTopic) => this.topicRow(topic), (topic: V2exTopic) => `${topic.id}`) }.layoutWeight(1).width('100%')
      else List({ space: 1 }) { ForEach(this.members, (member: V2exMember) => this.memberRow(member), (member: V2exMember) => member.username) }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
