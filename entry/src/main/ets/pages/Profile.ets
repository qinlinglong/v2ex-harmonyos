import { router } from '@kit.ArkUI';
import { V2exMember, V2exReply, V2exTopic } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';

@Entry
@Component
struct Profile {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exBlockedUsers') blockedUsersJson: string = '[]';
  @State member: V2exMember | undefined = undefined;
  @State topics: V2exTopic[] = [];
  @State replies: V2exReply[] = [];
  @State username: string = '';
  @State status: string = '加载中…';
  @State followed: boolean = false;
  @State blocked: boolean = false;
  @State tab: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    this.username = String(params?.['username'] ?? '');
    this.load();
  }

  private async load(): Promise<void> {
    try {
      this.member = await V2exService.member(this.username);
      const results: [V2exTopic[], V2exReply[]] = await Promise.all([
        V2exService.memberTopics(this.username), V2exService.memberReplies(this.username)
      ]);
      this.topics = results[0];
      this.replies = results[1];
      this.status = '';
    } catch (_) {
      this.status = '用户资料暂时不可用';
    }
  }

  private setBlockedUser(username: string, blocked: boolean): void {
    let users: string[] = [];
    try { users = JSON.parse(this.blockedUsersJson) as string[]; } catch (_) { users = []; }
    users = blocked ? (users.indexOf(username) >= 0 ? users : users.concat([username])) : users.filter((item: string) => item !== username);
    this.blockedUsersJson = JSON.stringify(users);
  }

  @Builder
  topicRow(topic: V2exTopic) {
    ListItem() {
      Column() {
        Text(topic.title).fontSize(16).fontColor('#202124').maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${topic.node?.title ?? 'V2EX'} · ${topic.replies} 回复`).fontSize(12)
          .fontColor('#8A97A6').margin({ top: 7 })
      }.width('100%').padding({ left: 18, right: 18, top: 14, bottom: 14 }).backgroundColor(Color.White)
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: topic.id } }))
  }

  @Builder
  replyRow(reply: V2exReply) {
    ListItem() {
      Column() {
        Text(reply.content).fontSize(15).fontColor('#30343B').maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('回复').fontSize(12).fontColor(this.themeColor).margin({ top: 7 })
      }.width('100%').padding({ left: 18, right: 18, top: 14, bottom: 14 }).backgroundColor(Color.White)
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(46).textAlign(TextAlign.Center).onClick(() => router.back())
        Text(this.username || '个人资料').fontSize(20).fontWeight(FontWeight.Bold)
        Blank()
        Text('↻').fontSize(24).fontColor(this.themeColor).width(46).textAlign(TextAlign.Center).onClick(() => this.load())
      }.height(64).width('100%').padding({ right: 8 }).backgroundColor(Color.White)
      if (this.member) {
        Scroll() {
          Column() {
            Column() {
              Stack() {
                Text(this.member.username.substring(0, 1).toUpperCase()).fontSize(28).fontColor(Color.White)
                  .width(76).height(76).textAlign(TextAlign.Center).backgroundColor('#B7C4D2').borderRadius(38)
                if (this.member.avatar_large) Image(this.member.avatar_large).width(76).height(76).borderRadius(38).objectFit(ImageFit.Cover)
              }
              Text(this.member.username).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#202124').margin({ top: 12 })
              Text(this.member.tagline || 'V2EX 用户').fontSize(14).fontColor('#7B8794').margin({ top: 6 })
              if (this.member.website && this.member.website.length > 0) Text(this.member.website).fontSize(13).fontColor('#4F7CAC').margin({ top: 6 })
                .onClick(() => router.pushUrl({ url: 'pages/WebViewPage', params: { title: this.member?.username ?? '网站', url: this.member?.website ?? '' } }))
              Row() {
                Button(this.followed ? '已关注' : '关注').layoutWeight(1).onClick(async () => {
                  const ok: boolean = await V2exService.memberAction(this.username, this.followed ? 'unfollow' : 'follow');
                  if (ok) this.followed = !this.followed;
                  else this.status = '请先登录';
                })
                Button(this.blocked ? '已屏蔽' : '屏蔽').layoutWeight(1).margin({ left: 10 }).onClick(async () => {
                  const nextBlocked: boolean = !this.blocked;
                  const ok: boolean = await V2exService.memberAction(this.username, nextBlocked ? 'block' : 'unblock');
                  if (ok) { this.blocked = nextBlocked; this.setBlockedUser(this.username, nextBlocked); }
                  else this.status = '请先登录';
                })
              }.width('80%').margin({ top: 16 })
            }.width('100%').padding({ top: 28, bottom: 24 }).backgroundColor(Color.White)
            Row() {
              Text('主题').fontColor(this.tab === 0 ? '#4F7CAC' : '#7B8794').fontSize(15)
                .layoutWeight(1).textAlign(TextAlign.Center).onClick(() => this.tab = 0)
              Text('回复').fontColor(this.tab === 1 ? '#4F7CAC' : '#7B8794').fontSize(15)
                .layoutWeight(1).textAlign(TextAlign.Center).onClick(() => this.tab = 1)
            }.width('100%').height(52).backgroundColor(Color.White)
            if (this.tab === 0) {
              List({ space: 1 }) { ForEach(this.topics, (topic: V2exTopic) => this.topicRow(topic), (topic: V2exTopic) => `${topic.id}`) }
                .width('100%').height(560)
            } else {
              List({ space: 1 }) { ForEach(this.replies, (reply: V2exReply) => this.replyRow(reply), (reply: V2exReply) => `${reply.id}`) }
                .width('100%').height(560)
            }
          }.width('100%')
        }.layoutWeight(1).width('100%')
      } else {
        Text(this.status).fontSize(15).fontColor('#7B8794').margin({ top: 48 })
      }
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
