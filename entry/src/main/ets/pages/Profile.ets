import { router } from '@kit.ArkUI';
import { V2exMember, V2exMemberRelations, V2exReply, V2exTopic } from '../model/V2exModels';
import { V2exService } from '../service/V2exService';
import { themeAccentText, themeInputBackground, themeMutedText, themeSecondaryText, themeOnColor } from '../common/Theme';

function decodeHtmlEntities(value: string): string {
  return value.replace(/&nbsp;/gi, ' ').replace(/&amp;/gi, '&').replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>').replace(/&quot;/gi, '"').replace(/&#39;|&apos;/gi, "'")
    .replace(/&#x([0-9a-f]+);/gi, (match: string, code: string) => String.fromCharCode(parseInt(code, 16)))
    .replace(/&#(\d+);/g, (match: string, code: string) => String.fromCharCode(Number(code)));
}

function replyPreview(value: string): string {
  let text: string = value.replace(/<br\s*\/?>(\r?\n)?/gi, '\n').replace(/<[^>]+>/g, '');
  text = decodeHtmlEntities(text).replace(/!\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1').replace(/^#{1,6}\s+/gm, '')
    .replace(/\*\*([^*]+)\*\*/g, '$1').replace(/__([^_]+)__/g, '$1')
    .replace(/`([^`]+)`/g, '$1');
  return text.trim();
}

interface ProfileCacheEntry {
  member: V2exMember;
  topics: V2exTopic[];
  replies: V2exReply[];
  followed: boolean;
  blocked: boolean;
}

@Entry
@Component
struct Profile {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exBlockedUsers') blockedUsersJson: string = '[]';
  @StorageLink('v2exProfileCache') profileCacheJson: string = '{}';
  @StorageLink('v2exCachedMember') cachedMemberJson: string = '';
  @State member: V2exMember | undefined = undefined;
  @State topics: V2exTopic[] = [];
  @State replies: V2exReply[] = [];
  @State username: string = '';
  @State status: string = '加载中…';
  @State followed: boolean = false;
  @State blocked: boolean = false;
  @State tab: number = 0;
  private surface(): string { return this.darkMode ? '#18202A' : '#FFFFFF'; }
  private pageBackground(): string { return this.darkMode ? '#0F141A' : '#F5F7FA'; }
  private primaryText(): string { return this.darkMode ? '#F2F5F8' : '#202124'; }
  private bodyText(): string { return this.darkMode ? '#D4DCE5' : '#30343B'; }

  private isSelf(): boolean {
    try {
      const current: V2exMember = JSON.parse(this.cachedMemberJson) as V2exMember;
      return current.username?.toLowerCase() === this.username.toLowerCase();
    } catch (_) { return false; }
  }

  private replyTopicId(reply: V2exReply): number {
    return Number(reply.topic_id ?? 0);
  }

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    this.username = String(params?.['username'] ?? '');
    this.restoreCache();
    this.load();
  }

  private restoreCache(): void {
    if (this.username.length === 0) return;
    try {
      const cache: Record<string, ProfileCacheEntry> = JSON.parse(this.profileCacheJson) as Record<string, ProfileCacheEntry>;
      const saved: ProfileCacheEntry | undefined = cache[this.username];
      if (saved && saved.member) {
        this.member = saved.member;
        this.topics = saved.topics ?? [];
        this.replies = saved.replies ?? [];
        this.followed = saved.followed;
        this.blocked = saved.blocked;
        this.status = '';
      }
    } catch (_) { /* corrupt profile cache is ignored */ }
  }

  private saveCache(): void {
    if (!this.member || this.username.length === 0) return;
    try {
      const cache: Record<string, ProfileCacheEntry> = JSON.parse(this.profileCacheJson) as Record<string, ProfileCacheEntry>;
      cache[this.username] = {
        member: this.member,
        topics: this.topics,
        replies: this.replies,
        followed: this.followed,
        blocked: this.blocked
      };
      this.profileCacheJson = JSON.stringify(cache);
    } catch (_) { /* cache failures must not affect profile */ }
  }

  private async load(): Promise<void> {
    const hasCachedProfile: boolean = this.member !== undefined;
    if (!hasCachedProfile) this.status = '加载中…';
    try {
      this.member = await V2exService.member(this.username);
      const results: [V2exTopic[], V2exReply[], V2exMemberRelations] = await Promise.all([
        V2exService.memberTopics(this.username), V2exService.memberReplies(this.username), V2exService.memberRelations(this.username)
      ]);
      this.topics = results[0];
      this.replies = results[1];
      this.followed = results[2].followed;
      this.blocked = results[2].blocked;
      this.saveCache();
      this.status = '';
    } catch (_) {
      this.status = hasCachedProfile ? '网络刷新失败，当前显示缓存' : '用户资料暂时不可用';
    }
  }

  private setBlockedUser(username: string, blocked: boolean): void {
    let users: string[] = [];
    try { users = JSON.parse(this.blockedUsersJson) as string[]; } catch (_) { users = []; }
    users = blocked ? (users.indexOf(username) >= 0 ? users : users.concat([username])) : users.filter((item: string) => item !== username);
    this.blockedUsersJson = JSON.stringify(users);
  }

  private async toggleMemberAction(action: 'follow' | 'unfollow' | 'block' | 'unblock'): Promise<void> {
    if (this.isSelf()) {
      this.status = '不能对自己执行此操作';
      return;
    }
    this.status = '处理中…';
    try {
      const ok: boolean = await V2exService.memberAction(this.username, action);
      if (!ok) { this.status = '请先登录'; return; }
      if (action === 'follow' || action === 'unfollow') this.followed = action === 'follow';
      else {
        this.blocked = action === 'block';
        this.setBlockedUser(this.username, this.blocked);
      }
      this.saveCache();
      this.status = '操作成功';
    } catch (_) { this.status = '操作失败，请稍后重试'; }
  }

  @Builder
  topicRow(topic: V2exTopic) {
    ListItem() {
      Row() {
          Stack() {
            Text((topic.member?.username ?? '?').substring(0, 1).toUpperCase()).fontSize(12).fontColor(Color.White)
              .width(26).height(26).textAlign(TextAlign.Center).backgroundColor(this.darkMode ? '#435466' : '#B7C4D2').borderRadius(13)
            if (topic.member?.avatar_large) Image(topic.member.avatar_large).width(26).height(26).borderRadius(13).objectFit(ImageFit.Cover)
          }.onClick(() => { if (topic.member?.username) router.pushUrl({ url: 'pages/Profile', params: { username: topic.member.username } }); })
            .hitTestBehavior(HitTestMode.Block)
        Column() {
          Text(topic.member?.username ?? '匿名').fontSize(12)
            .fontColor(themeMutedText(this.darkMode))
          Text(topic.title).fontSize(16).fontColor(this.primaryText()).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 3 })
          Text(`${topic.node?.title ?? 'V2EX'} · ${topic.replies} 回复`).fontSize(12)
            .fontColor(themeMutedText(this.darkMode)).margin({ top: 5 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 10 })
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 }).backgroundColor(this.surface())
    }.onClick(() => router.pushUrl({ url: 'pages/TopicDetail', params: { id: topic.id } }))
  }

  @Builder
  replyRow(reply: V2exReply) {
    ListItem() {
      Row() {
        Stack() {
          Text((reply.member?.username ?? this.username).substring(0, 1).toUpperCase()).fontSize(14).fontColor(Color.White)
            .width(36).height(36).textAlign(TextAlign.Center).backgroundColor(this.darkMode ? '#435466' : '#B7C4D2').borderRadius(18)
          if (reply.member?.avatar_large) Image(reply.member.avatar_large).width(36).height(36).borderRadius(18).objectFit(ImageFit.Cover)
        }.hitTestBehavior(HitTestMode.Block)
        Column() {
          Row() {
            Text(reply.member?.username ?? this.username).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.primaryText())
            Blank()
            Text(reply.createdLabel ?? new Date(reply.created * 1000).toLocaleDateString()).fontSize(11).fontColor(themeMutedText(this.darkMode))
          }.width('100%')
          Text(`回复主题：${replyPreview(reply.topic_title ?? '未知主题')}`).fontSize(12).fontColor(themeAccentText(this.themeColor, this.darkMode))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 5 })
          Text(replyPreview(reply.content)).fontSize(15).fontColor(this.bodyText()).lineHeight(23).maxLines(5)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).copyOption(CopyOptions.LocalDevice)
            .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE).width('100%')
            .padding({ left: 11, right: 11, top: 8, bottom: 8 }).backgroundColor(themeInputBackground(this.darkMode)).borderRadius(7).margin({ top: 7 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 12 })
      }.width('100%').padding({ left: 18, right: 18, top: 13, bottom: 13 }).backgroundColor(this.surface())
    }.onClick(() => {
      const topicId: number = this.replyTopicId(reply);
      if (topicId > 0) router.pushUrl({ url: 'pages/TopicDetail', params: { id: topicId } });
    })
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(themeAccentText(this.themeColor, this.darkMode)).width(46).textAlign(TextAlign.Center).onClick(() => router.back())
        Text(this.username || '个人资料').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.primaryText())
        Blank()
      }.height(64).width('100%').padding({ right: 8 }).backgroundColor(this.surface())
      if (this.member) {
        Scroll() {
          Column() {
            Column() {
              Stack() {
                Text(this.member.username.substring(0, 1).toUpperCase()).fontSize(28).fontColor(Color.White)
                  .width(76).height(76).textAlign(TextAlign.Center).backgroundColor(this.darkMode ? '#435466' : '#B7C4D2').borderRadius(38)
                if (this.member.avatar_large) Image(this.member.avatar_large).width(76).height(76).borderRadius(38).objectFit(ImageFit.Cover)
              }
              Text(this.member.username).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.primaryText()).margin({ top: 12 })
              Text(this.member.tagline || 'V2EX 用户').fontSize(14).fontColor(themeSecondaryText(this.darkMode)).margin({ top: 6 })
              if (this.member.website && this.member.website.length > 0) Text(this.member.website).fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode)).margin({ top: 6 })
                .onClick(() => router.pushUrl({ url: 'pages/WebViewPage', params: { title: this.member?.username ?? '网站', url: this.member?.website ?? '' } }))
              if (!this.isSelf()) {
                Row() {
                  Button(this.followed ? '已关注' : '关注').layoutWeight(1).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.toggleMemberAction(this.followed ? 'unfollow' : 'follow'))
                  Button(this.blocked ? '已屏蔽' : '屏蔽').layoutWeight(1).margin({ left: 10 }).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.toggleMemberAction(this.blocked ? 'unblock' : 'block'))
                }.width('80%').margin({ top: 16 })
              }
              if (this.status.length > 0 && this.status !== '加载中…') Text(this.status).fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode)).margin({ top: 12 })
            }.width('100%').padding({ top: 28, bottom: 24 }).backgroundColor(this.surface())
            Row() {
              Text('主题').fontColor(this.tab === 0 ? themeAccentText(this.themeColor, this.darkMode) : themeSecondaryText(this.darkMode)).fontSize(15)
                .layoutWeight(1).textAlign(TextAlign.Center).onClick(() => this.tab = 0)
              Text('回复').fontColor(this.tab === 1 ? themeAccentText(this.themeColor, this.darkMode) : themeSecondaryText(this.darkMode)).fontSize(15)
                .layoutWeight(1).textAlign(TextAlign.Center).onClick(() => this.tab = 1)
            }.width('100%').height(52).backgroundColor(this.surface())
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
        Text(this.status).fontSize(15).fontColor(themeSecondaryText(this.darkMode)).margin({ top: 48 })
      }
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor(this.pageBackground())
  }
}
