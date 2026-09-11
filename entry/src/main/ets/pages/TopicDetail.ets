import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { systemShare } from '@kit.ShareKit';
import { V2exService } from '../service/V2exService';
import { V2exMember, V2exReply, V2exTopic, V2exVoteResult } from '../model/V2exModels';
import { themeAccentText, themeMutedText, themeSecondaryText, themeOnColor } from '../common/Theme';

interface MarkdownTable { headers: string[]; rows: string[][]; }
interface DetailPart { kind: string; value: string; label?: string; table?: MarkdownTable; }
interface ReplyTextPart { kind: string; value: string; }

const BASE64_MENU_ID: TextMenuItemId = TextMenuItemId.of('v2ex_base64_decode');

/**
 * Normalize content copied from Markdown editors and forum posts. Some posts
 * contain escaped HTML (`\\<p>`), numeric spaces (`&#x20;`) or an image URL
 * wrapped in Markdown inside an HTML img tag. Treat those forms as markup so
 * the detail view renders the same image and text as the web page.
 */
function normalizeDetailMarkup(value: string): string {
  return value
    .replace(/&#x20;|&#32;/gi, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&quot;/gi, '"').replace(/&lt;/gi, '<').replace(/&gt;/gi, '>').replace(/&amp;/gi, '&')
    .replace(/\\([\\`*{}\[\]()#+.!_<>-])/g, '$1')
    .replace(/<p\b[^>]*>/gi, '').replace(/<\/p>/gi, '\n')
    .replace(/<br\s*\/?\s*>/gi, '\n')
    .replace(/<img\b[^>]*src=["']\s*\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)["'][^>]*>/gi, '![$1]($2)')
    .replace(/<img\b[^>]*src=["']\s*([^"'\s>]+)["'][^>]*>/gi, '![]($1)');
}

function appendTextWithLinks(parts: DetailPart[], value: string): void {
  const pattern: RegExp = /https?:\/\/[^\s<>()]+/gi;
  let cursor: number = 0;
  let match: RegExpExecArray | null = pattern.exec(value);
  while (match !== null) {
    const url: string = match[0].replace(/[.,!?;:，。！？；：）)]+$/g, '');
    const punctuation: string = match[0].substring(url.length);
    if (match.index > cursor) parts.push({ kind: 'text', value: value.substring(cursor, match.index) });
    parts.push({ kind: 'link', value: url, label: url });
    if (punctuation.length > 0) parts.push({ kind: 'text', value: punctuation });
    cursor = match.index + match[0].length;
    match = pattern.exec(value);
  }
  const tail: string = value.substring(cursor);
  if (tail.length > 0) parts.push({ kind: 'text', value: tail });
}

function appendInlineParts(parts: DetailPart[], markdown: string): void {
  // V2EX's native format leaves image URLs as plain text (for example
  // https://i.v2ex.co/xxxx.png). Keep Markdown links and native links in the
  // same pass so both formats render identically.
  const pattern: RegExp = /!\[[^\]]*\]\(\s*((?:https?:\/\/|\/\/|\/)[^)\s]+)\s*\)|\[([^\]]+)\]\(\s*((?:https?:\/\/|\/\/|\/)[^)\s]+)\s*\)|((?:https?:\/\/|\/\/)[^\s<>()]+)/gi;
  let cursor: number = 0;
  let match: RegExpExecArray | null = pattern.exec(markdown);
  while (match !== null) {
    const before: string = markdown.substring(cursor, match.index);
    if (before.length > 0) appendTextWithLinks(parts, before);
    if (match[1]) parts.push({ kind: 'image', value: match[1] });
    else if (match[2]) parts.push({ kind: 'link', value: match[3], label: match[2] });
    else {
      const rawUrl: string = match[4];
      const url: string = rawUrl.replace(/[.,!?;:，。！？；：）)]+$/g, '');
      const punctuation: string = rawUrl.substring(url.length);
      if (isImageUrl(url)) parts.push({ kind: 'image', value: url });
      else parts.push({ kind: 'link', value: url, label: url });
      if (punctuation.length > 0) parts.push({ kind: 'text', value: punctuation });
    }
    cursor = match.index + match[0].length;
    match = pattern.exec(markdown);
  }
  const tail: string = markdown.substring(cursor);
  if (tail.length > 0) appendTextWithLinks(parts, tail);
}

function isImageUrl(value: string): boolean {
  const url: string = value.trim().toLowerCase();
  return /^(?:https?:)?\/\/i\.v2ex\.co\//i.test(url)
    || /^(?:https?:)?\/\/(?:i\.)?imgur\.com\//i.test(url)
    || /\.(?:png|jpe?g|gif|webp|bmp|svg)(?:[?#].*)?$/i.test(url);
}

// The web page renders forum emoticons as small inline images. They arrive here as
// ordinary image parts, so identify those paths before using the body-image
// full-width layout.
function isInlineEmojiImage(value: string): boolean {
  return /(?:emoji|emoticon|smiley|smileys|emotion|twemoji|\/face(?:s)?\/)/i.test(value);
}

function splitTableRow(line: string): string[] {
  let row: string = line.trim();
  if (row.startsWith('|')) row = row.substring(1);
  if (row.endsWith('|') && !row.endsWith('\\|')) row = row.substring(0, row.length - 1);
  const cells: string[] = [];
  let cell: string = '';
  let escaped: boolean = false;
  for (let index = 0; index < row.length; index += 1) {
    const character: string = row.charAt(index);
    if (character === '|' && !escaped) {
      cells.push(cell.trim());
      cell = '';
      continue;
    }
    cell += character;
    escaped = character === '\\' && !escaped;
    if (character !== '\\') escaped = false;
  }
  cells.push(cell.trim());
  return cells.map((value: string) => value.replace(/\\\|/g, '|'));
}

function isTableSeparator(line: string): boolean {
  return /^\s*\|?\s*:?-{3,}:?\s*(?:\|\s*:?-{3,}:?\s*)+\|?\s*$/.test(line);
}

function detailParts(markdown: string): DetailPart[] {
  const parts: DetailPart[] = [];
  const lines: string[] = normalizeDetailMarkup(markdown).replace(/\r/g, '').split('\n');
  const inlineLines: string[] = [];
  const flushInline = (): void => {
    if (inlineLines.length === 0) return;
    appendInlineParts(parts, inlineLines.join('\n'));
    inlineLines.length = 0;
  };
  let index: number = 0;
  while (index < lines.length) {
    if (lines[index].trim().startsWith('```')) {
      flushInline();
      index += 1;
      const codeLines: string[] = [];
      while (index < lines.length && !lines[index].trim().startsWith('```')) {
        codeLines.push(lines[index]);
        index += 1;
      }
      if (index < lines.length) index += 1;
      parts.push({ kind: 'code', value: codeLines.join('\n') });
      continue;
    }
    if (index + 1 < lines.length && lines[index].indexOf('|') >= 0 && isTableSeparator(lines[index + 1])) {
      flushInline();
      const headers: string[] = splitTableRow(lines[index]);
      const rows: string[][] = [];
      index += 2;
      while (index < lines.length && lines[index].trim().length > 0 && lines[index].indexOf('|') >= 0) {
        rows.push(splitTableRow(lines[index]));
        index += 1;
      }
      if (headers.length > 0) parts.push({ kind: 'table', value: '', table: { headers, rows } });
      continue;
    }
    inlineLines.push(lines[index]);
    index += 1;
  }
  flushInline();
  return parts;
}

function plainMarkdown(value: string): string {
  return normalizeDetailMarkup(value).replace(/<[^>]+>/g, '').replace(/^#{1,6}\s+/gm, '').replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/__([^_]+)__/g, '$1').replace(/\*([^*]+)\*/g, '$1')
    .replace(/_([^_]+)_/g, '$1').replace(/`([^`]+)`/g, '$1');
}

function replyTextParts(value: string): ReplyTextPart[] {
  const parts: ReplyTextPart[] = [];
  // Keep emoji in the same Text node as surrounding content. HarmonyOS gives
  // a standalone emoji Text an oversized minimum line box, while the web page renders
  // the same glyph inline. Mentions remain separate so they stay clickable.
  const pattern: RegExp = /@([A-Za-z0-9_\-\u4e00-\u9fff]+)/g;
  let cursor: number = 0;
  let match: RegExpExecArray | null = pattern.exec(value);
  while (match !== null) {
    if (match.index > cursor) parts.push({ kind: 'text', value: value.substring(cursor, match.index) });
    if (match[1]) parts.push({ kind: 'mention', value: match[1] });
    cursor = match.index + match[0].length;
    match = pattern.exec(value);
  }
  if (cursor < value.length) parts.push({ kind: 'text', value: value.substring(cursor) });
  if (parts.length === 0 && value.length > 0) parts.push({ kind: 'text', value });
  return parts;
}

/**
 * V2EX sometimes serializes a mention as two adjacent blocks (`@` followed
 * by a linked username), with a newline between them. Merge those blocks
 * before rendering so the mention remains one inline, clickable unit.
 */
function replyDetailParts(value: string): DetailPart[] {
  // The rendered markup may put the @ marker and its linked username on
  // separate lines. Remove that structural newline, and the first newline
  // after the mention, before parsing. This keeps @username and a short reply
  // body in the same visual line while leaving unrelated paragraph breaks.
  const normalized: string = value
    .replace(/@\s*\r?\n\s*(?=(?:\[[^\]]+\]\(|[A-Za-z0-9_\-\u4e00-\u9fff]))/g, '@')
    .replace(/(\[[^\]]+\]\((?:https?:\/\/|\/)[^)]+\)|@[A-Za-z0-9_\-\u4e00-\u9fff]+)\s*\r?\n\s*/g, '$1 ');
  const source: DetailPart[] = detailParts(normalized);
  const result: DetailPart[] = [];
  for (let index = 0; index < source.length; index += 1) {
    const current: DetailPart = source[index];
    const next: DetailPart | undefined = source[index + 1];
    const currentText: string = current.kind === 'text' ? current.value : '';
    const atIndex: number = currentText.lastIndexOf('@');
    if (atIndex >= 0 && next !== undefined && (next.kind === 'link' || next.kind === 'text')) {
      const prefix: string = currentText.substring(0, atIndex);
      const mentionName: string = next.kind === 'link' ? (next.label ?? next.value) : next.value;
      const between: string = currentText.substring(atIndex + 1).replace(/[\s\r\n]+$/g, '');
      if (between.length === 0 && mentionName.trim().length > 0 && !mentionName.includes('\n')) {
        if (prefix.length > 0) result.push({ kind: 'text', value: prefix });
        const following: DetailPart | undefined = source[index + 2];
        if (following?.kind === 'text' && following.value.length > 0) {
          const hadBreak: boolean = /^\s*\r?\n/.test(following.value);
          let tail: string = hadBreak ? following.value.replace(/^\s*\r?\n\s*/, ' ') : following.value;
          if (!hadBreak && tail.length > 0 && !/^\s/.test(tail)) tail = ` ${tail}`;
          result.push({ kind: 'text', value: `@${mentionName.trim()}${tail}` });
          index += 2;
        } else {
          result.push({ kind: 'mention', value: mentionName.trim(), label: next.kind === 'link' ? next.value : undefined });
          index += 1;
        }
        continue;
      }
    }
    result.push(current);
  }
  return result;
}

function hasReplyReferences(value: string): boolean {
  return /@(?:<a\s+href=["']\/member\/[^"']+["'][^>]*>[\s\S]*?<\/a>|[A-Za-z0-9_\-\u4e00-\u9fff]+)/i.test(value);
}

@Entry
@Component
struct TopicDetail {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exDarkMode') darkMode: boolean = false;
  @StorageLink('v2exSafeAreaTop') safeAreaTop: number = 0;
  @StorageLink('v2exSafeAreaBottom') safeAreaBottom: number = 0;
  @StorageLink('v2exRecentTopicIds') recentJson: string = '[]';
  @StorageLink('v2exIgnoredTopicIds') ignoredTopicsJson: string = '[]';
  @StorageLink('v2exParseContent') parseContent: boolean = true;
  @StorageLink('v2exReplyMention') replyMention: string = '';
  @StorageLink('v2exIgnoredReplyIds') ignoredReplyIdsJson: string = '[]';
  @StorageLink('v2exTopicCache') topicCacheJson: string = '{}';
  @StorageLink('v2exRepliesCache') repliesCacheJson: string = '{}';
  @StorageLink('v2exCachedMember') cachedMemberJson: string = '';
  @State topic: V2exTopic | undefined = undefined;
  @State replies: V2exReply[] = [];
  @State loading: boolean = true;
  @State errorText: string = '';
  @State replyText: string = '';
  @State replyStatus: string = '';
  @State replying: boolean = false;
  @State replyComposerOpen: boolean = false;
  @State favorited: boolean = false;
  @State thanked: boolean = false;
  @State actionStatus: string = '';
  @State thankedReplies: number[] = [];
  @State editingReplyId: number = 0;
  @State editingReplyText: string = '';
  @State editingReplyStatus: string = '';
  @State appendOpen: boolean = false;
  @State appendText: string = '';
  @State appendStatus: string = '';
  @State voteState: number = 0;
  @State replyOrder: number = 0;
  @State replyPage: number = 1;
  @State loadingMoreReplies: boolean = false;
  @State noMoreReplies: boolean = false;
  @State replyMoreStatus: string = '';
  @State ignored: boolean = false;
  @State base64Result: string = '';
  @State base64Source: string = '';
  @State base64SelectedText: string = '';
  private topicId: number = 0;
  private surface(): string { return this.darkMode ? '#18202A' : '#FFFFFF'; }
  private pageBackground(): string { return this.darkMode ? '#0F141A' : '#F5F7FA'; }
  private primaryText(): string { return this.darkMode ? '#F2F5F8' : '#202124'; }
  private bodyText(): string { return this.darkMode ? '#D4DCE5' : '#30343B'; }

  private currentUsername(): string {
    try {
      const member: V2exMember = JSON.parse(this.cachedMemberJson) as V2exMember;
      return member.username?.toLowerCase() ?? '';
    } catch (_) { return ''; }
  }

  private isSelf(username: string | undefined): boolean {
    const current: string = this.currentUsername();
    return current.length > 0 && username !== undefined && current === username.toLowerCase();
  }

  private canEditReply(reply: V2exReply): boolean {
    return reply.editable === true && this.isSelf(reply.member?.username);
  }

  private decodeBase64Selection(value: string): string {
    let normalized: string = value.replace(/\s+/g, '').replace(/-/g, '+').replace(/_/g, '/');
    if (!/^[A-Za-z0-9+/]*={0,2}$/.test(normalized)) {
      const candidates: string[] = value.match(/[A-Za-z0-9+/_-]{4,}={0,2}/g) ?? [];
      if (candidates.length === 0) throw new Error('invalid base64');
      normalized = candidates.sort((a: string, b: string) => b.length - a.length)[0]
        .replace(/\s+/g, '').replace(/-/g, '+').replace(/_/g, '/');
    }
    const remainder: number = normalized.length % 4;
    if (remainder > 0) normalized += '='.repeat(4 - remainder);
    const bytes: Uint8Array = new util.Base64Helper().decodeSync(normalized, util.Type.BASIC);
    const decoded: string = util.TextDecoder.create('utf-8').decodeToString(bytes);
    if (decoded.length === 0) throw new Error('empty result');
    return decoded;
  }

  private selectionMenu(source: string): EditMenuOptions {
    return {
      onCreateMenu: (items: Array<TextMenuItem>): Array<TextMenuItem> => {
        if (items.some((item: TextMenuItem) => item.id.equals(BASE64_MENU_ID))) return items;
        return items.concat([{ id: BASE64_MENU_ID, content: 'Base64 解码' }]);
      },
      onMenuItemClick: (item: TextMenuItem, range: TextRange): boolean => {
        if (!item.id.equals(BASE64_MENU_ID)) return false;
        const start: number = Math.max(0, Math.min(range.start ?? 0, source.length));
        const end: number = Math.max(start, Math.min(range.end ?? source.length, source.length));
        const selected: string = source.substring(start, end).trim();
        if (selected.length === 0) {
          this.actionStatus = '请先选择 Base64 文本';
          return true;
        }
        try {
          this.base64Result = this.decodeBase64Selection(selected);
          this.base64Source = source;
          this.base64SelectedText = selected;
          this.actionStatus = 'Base64 解码完成';
        } catch (_) {
          this.base64Result = '';
          this.base64Source = '';
          this.base64SelectedText = '';
          this.actionStatus = '选中的内容不是有效 Base64';
        }
        return true;
      }
    };
  }

  private topicShareUrl(): string {
    if (this.topic?.url && this.topic.url.length > 0) return this.topic.url;
    const configured: string = AppStorage.get<string>('v2exDomain') ?? 'https://www.v2ex.com';
    return `${configured.replace(/\/$/, '')}/t/${this.topicId}`;
  }

  private replyShareUrl(reply: V2exReply): string {
    const configured: string = AppStorage.get<string>('v2exDomain') ?? 'https://www.v2ex.com';
    const page: number = Math.max(1, Math.ceil(Math.max(1, reply.no ?? 1) / 100));
    return `${configured.replace(/\/$/, '')}/t/${this.topicId}?p=${page}#r_${reply.id}`;
  }

  private async shareLink(url: string, title: string): Promise<void> {
    try {
      const data = new systemShare.SharedData({ utd: 'general.hyperlink', content: url, title, label: 'HYPERLINK' });
      const controller = new systemShare.ShareController(data);
      const context = getContext(this) as common.UIAbilityContext;
      await controller.show(context, {});
    } catch (_) { this.actionStatus = '分享失败，请稍后重试'; }
  }

  private async copyTopicLink(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.topicShareUrl());
      await pasteboard.getSystemPasteboard().setData(data);
      this.actionStatus = '主题链接已复制';
    } catch (_) {
      this.actionStatus = '复制链接失败';
    }
  }

  private async copyBase64Result(): Promise<void> {
    if (this.base64Result.length === 0) return;
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.base64Result);
      await pasteboard.getSystemPasteboard().setData(data);
      this.actionStatus = '解码结果已复制';
    } catch (_) { this.actionStatus = '复制失败'; }
  }

  @Builder
  private base64Card(): void {
    Column() {
      Text(`选中内容：${this.base64SelectedText}`).fontSize(12).fontColor(themeMutedText(this.darkMode)).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ bottom: 4 })
      Text('Base64 解码结果').fontSize(12).fontColor(themeAccentText(this.themeColor, this.darkMode)).margin({ bottom: 4 })
      Text(this.base64Result).fontSize(15).fontColor(this.bodyText()).lineHeight(24)
        .width('100%').copyOption(CopyOptions.LocalDevice)
        .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
      Button('复制解码结果').fontSize(13).fontColor(themeOnColor(this.themeColor)).backgroundColor(this.themeColor)
        .margin({ top: 8 }).onClick(() => this.copyBase64Result())
    }.width('100%').padding(10).backgroundColor(this.darkMode ? '#202A35' : '#F3F6FA')
      .borderRadius(8).margin({ top: 8, bottom: 4 })
  }

  private async toggleIgnoredFromMenu(): Promise<void> {
    const nextIgnored: boolean = !this.ignored;
    try {
      const ok: boolean = await this.action(nextIgnored ? 'ignore' : 'unignore');
      if (ok) {
        this.ignored = nextIgnored;
        this.setIgnoredTopic(nextIgnored);
      }
    } catch (_) { this.actionStatus = '操作失败，请稍后重试'; }
  }

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    this.topicId = Number(params?.['id'] ?? 0);
    const savedSort: string | undefined = AppStorage.get<string>('v2exTopicSort');
    if (savedSort === 'latest') this.replyOrder = 1;
    this.rememberRecentTopic();
    this.applyReplyMention();
    this.restoreCache();
    this.load();
  }

  onPageShow(): void {
    this.applyReplyMention();
    // A topic edit page returns to this page without recreating the route.
    // Refresh the existing detail in place so the edited title/body is visible
    // immediately while the cached content remains on screen during the request.
    if (this.topicId > 0 && this.topic !== undefined) this.load();
  }

  private applyReplyMention(): void {
    const value: string = this.replyMention.trim();
    if (value.length === 0) return;
    this.replyText = this.replyText.length > 0 ? `${this.replyText}${this.replyText.endsWith(' ') ? '' : ' '}${value} ` : `${value} `;
    this.replyComposerOpen = true;
    this.replyMention = '';
  }

  private rememberRecentTopic(): void {
    try {
      const ids: number[] = JSON.parse(this.recentJson) as number[];
      const next: number[] = [this.topicId].concat(ids.filter((id: number) => id !== this.topicId)).slice(0, 30);
      this.recentJson = JSON.stringify(next);
    } catch (_) { this.recentJson = JSON.stringify([this.topicId]); }
  }

  private setIgnoredTopic(ignored: boolean): void {
    let ids: number[] = [];
    try { ids = JSON.parse(this.ignoredTopicsJson) as number[]; } catch (_) { ids = []; }
    ids = ignored ? (ids.indexOf(this.topicId) >= 0 ? ids : ids.concat([this.topicId])) : ids.filter((id: number) => id !== this.topicId);
    this.ignoredTopicsJson = JSON.stringify(ids);
  }

  private async load(): Promise<void> {
    // Cached content stays on screen while the network refresh runs. This
    // avoids the blank detail transition seen when opening a topic from a list.
    const hasCachedTopic: boolean = this.topic !== undefined;
    if (!hasCachedTopic) this.loading = true;
    this.errorText = '';
    // Start both requests before awaiting either one. The topic endpoint also
    // performs an authenticated HTML lookup, so serializing it ahead of the
    // replies request made comments appear noticeably late on a cold detail
    // page. Each result is applied independently as soon as it is available.
    const topicTask: Promise<void> = V2exService.topic(this.topicId).then((loadedTopic: V2exTopic) => {
      this.topic = loadedTopic;
      this.favorited = loadedTopic.favorited === true;
      this.thanked = loadedTopic.thanked === true;
      let locallyIgnored: number[] = [];
      try { locallyIgnored = JSON.parse(this.ignoredTopicsJson) as number[]; } catch (_) { locallyIgnored = []; }
      this.ignored = loadedTopic.ignored === true || locallyIgnored.indexOf(this.topicId) >= 0;
      if (loadedTopic.vote === 1 || loadedTopic.vote === -1) this.voteState = loadedTopic.vote;
      this.saveTopicCache(loadedTopic);
      this.loading = false;
    }).catch(() => {
      if (!hasCachedTopic) {
        this.errorText = '主题加载失败，请稍后重试';
        this.loading = false;
      } else {
        this.actionStatus = '网络刷新失败，当前显示缓存';
      }
    });
    const repliesTask: Promise<void> = V2exService.replies(this.topicId).then((loadedReplies: V2exReply[]) => {
      this.replies = loadedReplies;
      this.replyPage = 1;
      this.noMoreReplies = false;
      this.replyMoreStatus = '';
      this.saveRepliesCache(this.topicId, loadedReplies);
    }).catch(() => {
      if (this.replies.length === 0) this.replyStatus = '回复暂时无法加载，可稍后重试';
    });
    await Promise.all([topicTask, repliesTask]);
  }

  private async loadMoreReplies(): Promise<void> {
    if (this.loading || this.loadingMoreReplies || this.noMoreReplies || this.topicId <= 0) return;
    this.loadingMoreReplies = true;
    try {
      const next: V2exReply[] = await V2exService.repliesPage(this.topicId, this.replyPage + 1);
      const unique: V2exReply[] = next.filter((reply: V2exReply) => this.replies.findIndex((item: V2exReply) => item.id === reply.id) < 0);
      if (unique.length === 0) {
        this.noMoreReplies = true;
        this.replyMoreStatus = '没有更多回复';
      } else {
        this.replies = this.replies.concat(unique);
        this.replyPage += 1;
        this.replyMoreStatus = '';
        this.saveRepliesCache(this.topicId, this.replies);
      }
    } catch (_) {
      this.replyMoreStatus = '加载更多回复失败';
    } finally {
      this.loadingMoreReplies = false;
    }
  }

  private restoreCache(): void {
    try {
      const topics: Record<string, Object> = JSON.parse(this.topicCacheJson) as Record<string, Object>;
      const cachedTopic: V2exTopic | undefined = topics[String(this.topicId)] as V2exTopic | undefined;
      if (cachedTopic && cachedTopic.id === this.topicId) {
        this.topic = cachedTopic;
        this.favorited = cachedTopic.favorited === true;
        this.thanked = cachedTopic.thanked === true;
        this.voteState = cachedTopic.vote === 1 || cachedTopic.vote === -1 ? cachedTopic.vote : 0;
        this.loading = false;
      }
      const replies: Record<string, Object> = JSON.parse(this.repliesCacheJson) as Record<string, Object>;
      const cachedReplies: V2exReply[] | undefined = replies[String(this.topicId)] as V2exReply[] | undefined;
      if (cachedReplies && Array.isArray(cachedReplies)) this.replies = cachedReplies;
    } catch (_) {
      // A corrupt cache must never prevent the live request from loading.
    }
  }

  private saveTopicCache(topic: V2exTopic): void {
    try {
      const topics: Record<string, Object> = JSON.parse(this.topicCacheJson) as Record<string, Object>;
      topics[String(topic.id)] = topic as Object;
      this.topicCacheJson = JSON.stringify(topics);
    } catch (_) { /* ignore cache failures */ }
  }

  private saveRepliesCache(topicId: number, replies: V2exReply[]): void {
    try {
      const cache: Record<string, Object> = JSON.parse(this.repliesCacheJson) as Record<string, Object>;
      cache[String(topicId)] = replies as Object;
      this.repliesCacheJson = JSON.stringify(cache);
    } catch (_) { /* ignore cache failures */ }
  }

  private async submitReply(): Promise<void> {
    // Take a stable snapshot before starting the request. The IME can emit a
    // final composition change while the send button is tapped; submitting
    // the snapshot prevents a visible non-empty editor from becoming an empty
    // form value, and gives the user feedback when it really is blank.
    const message: string = this.replyText.replace(/[\u200B\u200C\u200D]/g, '').trim();
    if (message.length === 0) {
      this.replyStatus = '回复内容不能为空';
      return;
    }
    if (this.replying) return;
    this.replying = true; this.replyStatus = '发送中…';
    try {
      const ok: boolean = await V2exService.reply(this.topicId, message);
      if (ok) {
        this.replyText = '';
        this.replyStatus = '回复成功';
        this.replyComposerOpen = false;
        await this.load();
      }
      else this.replyStatus = '回复失败，请检查登录状态或稍后重试';
    } catch (error) {
      this.replyStatus = error instanceof Error ? error.message : '回复失败，请稍后重试';
    }
    finally { this.replying = false; }
  }

  private async action(kind: 'favorite' | 'thank' | 'up' | 'down' | 'ignore' | 'unignore' | 'report'): Promise<boolean> {
    if (kind === 'thank' && this.thanked) {
      this.actionStatus = '已感谢';
      return false;
    }
    this.actionStatus = '处理中…';
    if (kind === 'up' || kind === 'down') {
      try {
        const result: V2exVoteResult = await V2exService.topicVote(this.topicId, kind);
        if (!result.success) {
          this.actionStatus = result.message ?? '请先登录';
          return false;
        }
        if (!result.changed) {
          this.actionStatus = result.message ?? '没有变化';
          return false;
        }
        this.voteState = kind === 'up' ? 1 : -1;
        if (this.topic && result.votes !== undefined) {
          this.topic = {
            id: this.topic.id, title: this.topic.title, content: this.topic.content, replies: this.topic.replies,
            last_modified: this.topic.last_modified, last_touched: this.topic.last_touched, lastTouchedLabel: this.topic.lastTouchedLabel,
            node: this.topic.node, member: this.topic.member, editable: this.topic.editable, appendable: this.topic.appendable,
            favorited: this.topic.favorited, thanked: this.topic.thanked, ignored: this.topic.ignored, vote: this.topic.vote,
            votes: result.votes, views: this.topic.views, likes: this.topic.likes, thanks: this.topic.thanks,
            last_reply_by: this.topic.last_reply_by, syntax: this.topic.syntax, url: this.topic.url
          } as V2exTopic;
          this.saveTopicCache(this.topic);
        }
        this.actionStatus = kind === 'up' ? '已点赞' : '已踩';
        return true;
      } catch (_) {
        this.actionStatus = '操作失败';
        return false;
      }
    }
    const action = kind === 'favorite' ? (this.favorited ? 'unfavorite' : 'favorite') : kind;
    try {
      const ok: boolean = await V2exService.topicAction(this.topicId, action);
      if (ok) {
        if (kind === 'favorite') this.favorited = !this.favorited;
        if (kind === 'thank') {
          this.thanked = true;
          if (this.topic) {
            this.topic = {
              id: this.topic.id, title: this.topic.title, content: this.topic.content, replies: this.topic.replies,
              last_modified: this.topic.last_modified, last_touched: this.topic.last_touched, lastTouchedLabel: this.topic.lastTouchedLabel,
              node: this.topic.node, member: this.topic.member, editable: this.topic.editable, appendable: this.topic.appendable,
              favorited: this.topic.favorited, thanked: true, ignored: this.topic.ignored, vote: this.topic.vote, votes: this.topic.votes,
              views: this.topic.views, likes: this.topic.likes, thanks: (this.topic.thanks ?? 0) + 1,
              last_reply_by: this.topic.last_reply_by, syntax: this.topic.syntax, url: this.topic.url
            } as V2exTopic;
            this.saveTopicCache(this.topic);
          }
        }
        this.actionStatus = kind === 'favorite' ? (this.favorited ? '已收藏' : '已取消收藏') : (kind === 'thank' ? '感谢已发送' : '已完成');
        return true;
      } else this.actionStatus = '请先登录';
    } catch (_) { this.actionStatus = '操作失败'; }
    return false;
  }

  private async thankReply(replyId: number): Promise<void> {
    if (this.thankedReplies.indexOf(replyId) >= 0) return;
    this.replyStatus = '点赞中…';
    try {
      const ok: boolean = await V2exService.replyAction(this.topicId, replyId, 'thank');
      if (ok) {
        this.thankedReplies = this.thankedReplies.concat([replyId]);
        this.replyStatus = '已点赞';
        this.replies = this.replies.map((item: V2exReply) => {
          if (item.id !== replyId) return item;
          return {
            id: item.id, no: item.no, createdLabel: item.createdLabel, content: item.content, created: item.created, member: item.member,
            thanks: (item.thanks ?? 0) + 1, thanked: true, editable: item.editable,
            op: item.op, mod: item.mod
          } as V2exReply;
        });
      }
      else this.replyStatus = '请先登录';
    } catch (_) { this.replyStatus = '操作失败'; }
  }

  private async ignoreReply(replyId: number): Promise<void> {
    try {
      const ok: boolean = await V2exService.replyAction(this.topicId, replyId, 'ignore');
      if (!ok) { this.replyStatus = '请先登录'; return; }
      let ids: number[] = [];
      try { ids = JSON.parse(this.ignoredReplyIdsJson) as number[]; } catch (_) { ids = []; }
      if (ids.indexOf(replyId) < 0) this.ignoredReplyIdsJson = JSON.stringify(ids.concat([replyId]));
      this.replyStatus = '回复已忽略';
    } catch (_) { this.replyStatus = '操作失败'; }
  }

  private ignoredReplyIds(): number[] {
    try { return JSON.parse(this.ignoredReplyIdsJson) as number[]; } catch (_) { return []; }
  }

  private orderedReplies(): V2exReply[] {
    const ignored: number[] = this.ignoredReplyIds();
    const list: V2exReply[] = this.replies.filter((reply: V2exReply) => ignored.indexOf(reply.id) < 0);
    if (this.replyOrder === 1) list.reverse();
    return list;
  }

  private replyFloor(reply: V2exReply, renderedIndex: number): number {
    if (reply.no !== undefined && reply.no > 0) return reply.no;
    const sourceIndex: number = this.replies.findIndex((item: V2exReply) => item.id === reply.id);
    return sourceIndex >= 0 ? sourceIndex + 1 : renderedIndex + 1;
  }

  private beginEditReply(reply: V2exReply): void {
    if (!this.canEditReply(reply)) {
      this.replyStatus = '当前回复不可编辑';
      return;
    }
    this.editingReplyId = reply.id;
    this.editingReplyText = reply.content;
    this.editingReplyStatus = '';
  }

  private async saveReplyEdit(): Promise<void> {
    if (this.editingReplyId <= 0 || this.editingReplyText.trim().length === 0) return;
    const target: V2exReply | undefined = this.replies.find((item: V2exReply) => item.id === this.editingReplyId);
    if (!target || !this.canEditReply(target)) {
      this.editingReplyStatus = '当前回复不可编辑';
      return;
    }
    this.editingReplyStatus = '保存中…';
    const id: number = this.editingReplyId;
    const content: string = this.editingReplyText.trim();
    try {
      const ok: boolean = await V2exService.editReply(id, content);
      if (!ok) { this.editingReplyStatus = '保存失败，请确认登录状态'; return; }
      this.replies = this.replies.map((item: V2exReply) => {
        if (item.id !== id) return item;
        return {
          id: item.id, no: item.no, createdLabel: item.createdLabel, content, created: item.created, member: item.member,
          thanks: item.thanks, thanked: item.thanked, editable: item.editable,
          op: item.op, mod: item.mod
        } as V2exReply;
      });
      this.saveRepliesCache(this.topicId, this.replies);
      this.editingReplyId = 0;
      this.editingReplyText = '';
      this.editingReplyStatus = '保存成功';
      this.replyStatus = '评论已更新';
    } catch (_) { this.editingReplyStatus = '保存失败，请稍后重试'; }
  }

  private async submitAppend(): Promise<void> {
    if (this.appendText.trim().length === 0) return;
    this.appendStatus = '保存中…';
    try {
      const ok: boolean = await V2exService.appendTopic(this.topicId, this.appendText.trim());
      if (!ok) { this.appendStatus = '保存失败，请确认登录状态'; return; }
      if (this.topic) this.topic = {
        id: this.topic.id, title: this.topic.title, content: `${this.topic.content}\n\n${this.appendText.trim()}`,
        replies: this.topic.replies, last_modified: this.topic.last_modified, last_touched: this.topic.last_touched,
        node: this.topic.node, member: this.topic.member, url: this.topic.url,
        editable: this.topic.editable, appendable: this.topic.appendable,
        favorited: this.topic.favorited, thanked: this.topic.thanked,
        ignored: this.topic.ignored, vote: this.topic.vote
      } as V2exTopic;
      this.appendText = '';
      this.appendStatus = '追加成功';
    } catch (_) { this.appendStatus = '保存失败，请稍后重试'; }
  }

  private openLink(url: string): void {
    const configured: string = AppStorage.get<string>('v2exDomain') ?? 'https://www.v2ex.com';
    const absolute: string = url.startsWith('/') ? `${configured.replace(/\/$/, '')}${url}` : url;
    const topicMatch: RegExpMatchArray | null = absolute.match(/\/t\/(\d+)/);
    const configuredOriginMatch: RegExpMatchArray | null = configured.match(/^https?:\/\/[^/]+/i);
    const absoluteOriginMatch: RegExpMatchArray | null = absolute.match(/^https?:\/\/[^/]+/i);
    const sameConfiguredSite: boolean = configuredOriginMatch !== null && absoluteOriginMatch !== null &&
      configuredOriginMatch[0].toLowerCase() === absoluteOriginMatch[0].toLowerCase();
    const isV2ex: boolean = sameConfiguredSite || /^https?:\/\/([^/]*\.)?v2ex\.com(?:\/|$)/i.test(absolute);
    if (isV2ex && topicMatch) {
      router.pushUrl({ url: 'pages/TopicDetail', params: { id: Number(topicMatch[1]) } });
      return;
    }
    const memberMatch: RegExpMatchArray | null = absolute.match(/\/member\/([^/?#]+)/);
    if (isV2ex && memberMatch) {
      router.pushUrl({ url: 'pages/Profile', params: { username: decodeURIComponent(memberMatch[1]) } });
      return;
    }
    this.openExternal(absolute);
  }

  private async openExternal(url: string): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      await context.openLink(url);
    } catch (_) {
      // Some devices have no default browser handler. Keep the link usable in
      // the app as a safe fallback instead of dropping the click silently.
      router.pushUrl({ url: 'pages/WebViewPage', params: { title: '网页', url } });
    }
  }

  private contentUrl(url: string): string {
    const normalized: string = url.trim().replace(/&amp;/gi, '&');
    if (normalized.startsWith('//')) return `https:${normalized}`;
    if (!normalized.startsWith('/')) return normalized;
    const configured: string = AppStorage.get<string>('v2exDomain') ?? 'https://www.v2ex.com';
    return `${configured.replace(/\/$/, '')}${normalized}`;
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(themeAccentText(this.themeColor, this.darkMode)).width(42).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('帖子').fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.primaryText()).textAlign(TextAlign.Center)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        Text('⋮').fontSize(28).fontColor(this.primaryText()).width(44).height(44).textAlign(TextAlign.Center)
          .bindMenu([
            { value: '复制主题链接', action: () => this.copyTopicLink() },
            { value: '分享主题', action: () => this.shareLink(this.topicShareUrl(), this.topic?.title ?? 'V2EX 主题') },
            { value: '在浏览器打开', action: () => this.openLink(this.topicShareUrl()) },
            { value: this.favorited ? '取消收藏主题' : '收藏主题', action: () => this.action('favorite') },
            { value: '编辑主题', enabled: this.topic?.editable === true && this.isSelf(this.topic?.member?.username), action: () => {
              if (this.topic?.editable === true && this.isSelf(this.topic.member?.username)) {
                router.pushUrl({ url: 'pages/WriteTopic', params: { topicId: this.topicId } });
              }
            } },
            { value: '追加内容', enabled: this.topic?.appendable === true && this.isSelf(this.topic?.member?.username), action: () => {
              if (this.topic?.appendable === true && this.isSelf(this.topic.member?.username)) this.appendOpen = true;
            } },
            { value: '感谢作者', enabled: !this.isSelf(this.topic?.member?.username), action: () => this.action('thank') },
            { value: this.ignored ? '取消忽略主题' : '忽略主题', enabled: !this.isSelf(this.topic?.member?.username), action: () => this.toggleIgnoredFromMenu() },
            { value: '举报主题', enabled: !this.isSelf(this.topic?.member?.username), action: () => this.action('report') }
          ], { placement: Placement.BottomRight })
      }.height(60).width('100%').padding({ right: 8 }).backgroundColor(this.surface())
      if (this.loading) {
        LoadingProgress().width(30).height(30).color(themeAccentText(this.themeColor, this.darkMode)).margin({ top: 32 })
      } else if (this.errorText.length > 0) {
        Text(this.errorText).fontSize(15).fontColor(themeSecondaryText(this.darkMode)).margin({ top: 40 })
      } else if (this.topic) {
        Column() {
          Scroll() {
          Column() {
            Column() {
              Row() {
                Stack() {
                  Text((this.topic.member?.username ?? '?').substring(0, 1).toUpperCase()).fontSize(16).fontColor(Color.White)
                    .width(48).height(48).textAlign(TextAlign.Center).backgroundColor(this.darkMode ? '#435466' : '#B7C4D2').borderRadius(24)
                  if (this.topic.member?.avatar_large) {
                    Image(this.topic.member.avatar_large).width(48).height(48).borderRadius(24).objectFit(ImageFit.Cover)
                  }
                }.onClick(() => {
                  if (this.topic?.member?.username) router.pushUrl({ url: 'pages/Profile', params: { username: this.topic.member.username } })
                })
                Column() {
                  Row() {
                    Text(this.topic.member?.username ?? '匿名').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.primaryText())
                      .onClick(() => { if (this.topic?.member?.username) router.pushUrl({ url: 'pages/Profile', params: { username: this.topic.member.username } }) })
                    if (this.topic?.node?.title) {
                      Text(this.topic.node.title).fontSize(12).fontColor(themeAccentText(this.themeColor, this.darkMode))
                        .padding({ left: 10, right: 10, top: 2, bottom: 2 })
                        .backgroundColor(this.darkMode ? '#26313D' : '#EEF3F8').borderRadius(10)
                        .margin({ left: 10 }).onClick(() => {
                          if (this.topic?.node?.name) router.pushUrl({ url: 'pages/NodeTopics', params: { name: this.topic.node.name, title: this.topic.node.title } })
                        })
                    }
                  }
                  Row() {
                    Text(`${Math.max(this.topic.replies, this.replies.length)} 条回复`).fontSize(13).fontColor(themeSecondaryText(this.darkMode))
                    if (this.topic.views !== undefined) {
                      Text(`${this.topic.views} 点击`).fontSize(13).fontColor(themeSecondaryText(this.darkMode)).margin({ left: 12 })
                    }
                  }.margin({ top: 7 })
                }.margin({ left: 18 }).layoutWeight(1).alignItems(HorizontalAlign.Start)
              }.width('100%')
              Text(this.topic.title).fontSize(21).fontWeight(FontWeight.Medium).fontColor(this.primaryText())
                .lineHeight(30).margin({ top: 16 }).copyOption(CopyOptions.LocalDevice)
                .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE).editMenuOptions(this.selectionMenu(this.topic.title))
              if (this.base64Result.length > 0 && this.base64Source === this.topic.title) this.base64Card()
              if (this.topic.editable === true && this.isSelf(this.topic.member?.username)) {
                Button('编辑主题').fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode)).backgroundColor(Color.Transparent)
                  .margin({ top: 4 }).onClick(() => router.pushUrl({ url: 'pages/WriteTopic', params: { topicId: this.topicId } }))
              }
              if (this.topic.appendable === true && this.isSelf(this.topic.member?.username)) {
                Button(this.appendOpen ? '收起追加' : '追加内容').fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode)).backgroundColor(Color.Transparent)
                  .margin({ top: 4 }).onClick(() => this.appendOpen = !this.appendOpen)
              }
              if (this.appendOpen) {
                TextArea({ placeholder: '追加内容', text: this.appendText }).width('100%').height(110).fontSize(15).fontColor(this.primaryText())
                  .onChange((value: string) => this.appendText = value)
                Row() {
                  if (this.appendStatus.length > 0) Text(this.appendStatus).fontSize(12).fontColor(themeAccentText(this.themeColor, this.darkMode))
                  Blank()
                  Button('保存追加').fontSize(13).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.submitAppend())
                }.width('100%').margin({ top: 8 })
              }
              ForEach(detailParts(this.parseContent ? (this.topic.content || '（无正文）') : (this.topic.content || '（无正文）').replace(/!\[[^\]]*\]\([^)]*\)/g, '')), (part: DetailPart) => {
                if (part.kind === 'code') {
                  Column() {
                    Text(part.value).fontSize(14).fontColor(this.bodyText()).lineHeight(22).fontFamily('monospace')
                      .width('100%').padding(12).backgroundColor(this.darkMode ? '#18212B' : '#F3F5F7')
                      .borderRadius(6).margin({ top: 16 }).copyOption(CopyOptions.LocalDevice)
                      .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE).editMenuOptions(this.selectionMenu(part.value))
                    if (this.base64Result.length > 0 && this.base64Source === part.value) this.base64Card()
                  }.width('100%')
                } else if (part.kind === 'table' && part.table) {
                  Column({ space: 1 }) {
                    Row() {
                      ForEach(part.table.headers, (cell: string, cellIndex: number) => Text(plainMarkdown(cell)).fontSize(14)
                        .fontWeight(FontWeight.Medium).fontColor(this.primaryText()).layoutWeight(1)
                        .padding({ left: 8, right: 8, top: 8, bottom: 8 }).backgroundColor(this.darkMode ? '#26313D' : '#EAF1F8')
                        .copyOption(CopyOptions.LocalDevice).textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
                        .editMenuOptions(this.selectionMenu(plainMarkdown(cell))),
                        (cell: string, cellIndex: number) => `table-header-${cellIndex}`)
                    }.width('100%')
                    ForEach(part.table.rows, (row: string[], rowIndex: number) => Row() {
                      ForEach(part.table?.headers ?? [], (header: string, cellIndex: number) => Text(plainMarkdown(row[cellIndex] ?? ''))
                        .fontSize(14).fontColor(this.bodyText()).layoutWeight(1)
                        .padding({ left: 8, right: 8, top: 8, bottom: 8 })
                        .backgroundColor(rowIndex % 2 === 0 ? this.surface() : (this.darkMode ? '#202A35' : '#F7F9FB'))
                        .copyOption(CopyOptions.LocalDevice).textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
                        .editMenuOptions(this.selectionMenu(plainMarkdown(row[cellIndex] ?? ''))),
                        (header: string, cellIndex: number) => `table-cell-${rowIndex}-${cellIndex}`)
                    }.width('100%'), (row: string[], rowIndex: number) => `table-row-${rowIndex}`)
                  }.width('100%').border({ width: 1, color: this.darkMode ? '#3A4858' : '#D7E0EA' })
                    .margin({ top: 16, bottom: 4 })
                } else if (part.kind === 'image') {
                  if (isInlineEmojiImage(part.value)) {
                    Image(this.contentUrl(part.value)).width(18).height(18).objectFit(ImageFit.Contain)
                      .margin({ top: 8 }).onClick(() => this.openLink(part.value))
                  } else {
                    Image(this.contentUrl(part.value)).constraintSize({ maxWidth: '100%', maxHeight: 520 }).objectFit(ImageFit.Contain)
                      .margin({ top: 14, bottom: 4 })
                      .onClick(() => this.openLink(part.value))
                  }
                } else if (part.kind === 'link') {
                  Column() {
                    Text(part.label ?? part.value).fontSize(16).fontColor(themeAccentText(this.themeColor, this.darkMode)).lineHeight(26)
                      .decoration({ type: TextDecorationType.Underline, color: themeAccentText(this.themeColor, this.darkMode) }).margin({ top: 20 })
                      .copyOption(CopyOptions.LocalDevice).textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
                      .editMenuOptions(this.selectionMenu(part.label ?? part.value))
                      .onClick(() => this.openLink(part.value))
                    if (this.base64Result.length > 0 && this.base64Source === (part.label ?? part.value)) this.base64Card()
                  }
                } else {
                  Column() {
                    Text(plainMarkdown(part.value)).fontSize(16).fontColor(this.bodyText()).lineHeight(26).margin({ top: 20 }).textAlign(TextAlign.Start)
                      .copyOption(CopyOptions.LocalDevice).textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
                      .editMenuOptions(this.selectionMenu(plainMarkdown(part.value)))
                    if (this.base64Result.length > 0 && this.base64Source === plainMarkdown(part.value)) this.base64Card()
                  }
                }
              }, (part: DetailPart, index: number) => `${part.kind}-${index}-${part.value.substring(0, 12)}`)
              Row({ space: 8 }) {
                Row() {
                  Text(this.favorited ? '★' : '☆').fontSize(18).fontColor(this.favorited ? '#D69E00' : themeAccentText(this.themeColor, this.darkMode))
                  if ((this.topic.likes ?? 0) > 0) {
                    Text(`${this.topic.likes}`).fontSize(13).fontColor(this.favorited ? '#D69E00' : themeSecondaryText(this.darkMode)).margin({ left: 3 })
                  }
                }.height(42).padding({ left: 16, right: 16 }).justifyContent(FlexAlign.Center)
                  .backgroundColor(this.darkMode ? (this.favorited ? '#5C4A18' : '#26313D') : (this.favorited ? '#FFF7D6' : '#F3F6FA')).borderRadius(21)
                  .onClick(() => this.action('favorite'))
                if (!this.isSelf(this.topic.member?.username)) {
                  Row() {
                    Image($r('app.media.ic_heart')).width(18).height(18).fillColor(this.thanked ? '#D05A73' : themeAccentText(this.themeColor, this.darkMode))
                    if ((this.topic.thanks ?? 0) > 0) {
                      Text(`${this.topic.thanks}`).fontSize(13).fontColor(this.thanked ? '#D05A73' : themeSecondaryText(this.darkMode)).margin({ left: 3 })
                    }
                  }.height(42).padding({ left: 16, right: 16 }).justifyContent(FlexAlign.Center)
                    .backgroundColor(this.darkMode ? (this.thanked ? '#5A2634' : '#26313D') : (this.thanked ? '#FFF0F3' : '#F3F6FA')).borderRadius(21)
                    .onClick(() => this.action('thank'))
                }
                Row() {
                  Text('▲').fontSize(15).fontColor(this.voteState === 1 ? themeAccentText(this.themeColor, this.darkMode) : themeSecondaryText(this.darkMode))
                  if (this.topic.votes !== undefined && this.topic.votes > 0) {
                    Text(`${this.topic.votes}`).fontSize(13).fontColor(this.voteState === 1 ? themeAccentText(this.themeColor, this.darkMode) : themeSecondaryText(this.darkMode)).margin({ left: 3 })
                  }
                }.height(42).padding({ left: 16, right: 16 }).justifyContent(FlexAlign.Center)
                  .backgroundColor(this.darkMode ? (this.voteState === 1 ? '#243C58' : '#26313D') : (this.voteState === 1 ? '#EAF3FF' : '#F3F6FA')).borderRadius(21)
                  .onClick(async () => {
                    await this.action('up');
                  })
                Row() {
                  Text('▼').fontSize(15).fontColor(this.voteState === -1 ? themeSecondaryText(this.darkMode) : themeMutedText(this.darkMode))
                }.height(42).padding({ left: 16, right: 16 }).justifyContent(FlexAlign.Center)
                  .backgroundColor(this.darkMode ? (this.voteState === -1 ? '#36404B' : '#26313D') : (this.voteState === -1 ? '#E9EDF2' : '#F3F6FA')).borderRadius(21)
                  .onClick(async () => {
                    await this.action('down');
                  })
              }.width('100%').margin({ top: 18 })
              if (this.actionStatus.length > 0) Text(this.actionStatus).fontSize(12).fontColor(themeAccentText(this.themeColor, this.darkMode)).margin({ top: 8 })
            }.width('100%').alignItems(HorizontalAlign.Start).padding(20).backgroundColor(this.surface())
            Row() {
              Text(`回复（${Math.max(this.topic.replies, this.replies.length)}）`).fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.primaryText())
              Blank()
              Text(this.replyOrder === 0 ? '默认排序' : '最新在前').fontSize(13).fontColor(themeSecondaryText(this.darkMode))
                .onClick(() => this.replyOrder = this.replyOrder === 0 ? 1 : 0)
            }.width('100%').padding({ left: 18, right: 18, top: 20, bottom: 12 })
            ForEach(this.orderedReplies(), (reply: V2exReply, index: number) => {
              Column() {
                Row() {
                  Stack() {
                    Text((reply.member?.username ?? '?').substring(0, 1).toUpperCase()).fontSize(12).fontColor(Color.White)
                      .width(28).height(28).textAlign(TextAlign.Center).backgroundColor(this.darkMode ? '#435466' : '#B7C4D2').borderRadius(14)
                    if (reply.member?.avatar_large) Image(reply.member.avatar_large).width(28).height(28).borderRadius(14).objectFit(ImageFit.Cover)
                  }.onClick(() => { if (reply.member?.username) router.pushUrl({ url: 'pages/Profile', params: { username: reply.member.username } }); })
                  Text(reply.member?.username ?? '匿名').fontSize(14).fontWeight(FontWeight.Medium).fontColor(themeAccentText(this.themeColor, this.darkMode))
                    .margin({ left: 12 })
                    .onClick(() => { if (reply.member?.username) router.pushUrl({ url: 'pages/Profile', params: { username: reply.member.username } }); })
                  if (reply.mod === true) {
                    Text('MOD').fontSize(10).fontColor(Color.White).padding({ left: 5, right: 5, top: 1, bottom: 1 })
                      .backgroundColor(this.themeColor).borderRadius(3).margin({ left: 6 })
                  }
                  if (reply.op === true) {
                    Text('OP').fontSize(10).fontColor(themeAccentText(this.themeColor, this.darkMode)).padding({ left: 5, right: 5, top: 1, bottom: 1 })
                      .border({ width: 1, color: themeAccentText(this.themeColor, this.darkMode) }).borderRadius(3).margin({ left: 4 })
                  }
                  Blank()
                  Text(`#${this.replyFloor(reply, index)}`).fontSize(12).fontColor(themeMutedText(this.darkMode)).margin({ right: 10 })
                  if (reply.createdLabel && reply.createdLabel.length > 0) {
                    Text(reply.createdLabel).fontSize(12).fontColor(themeMutedText(this.darkMode))
                  } else if (reply.created > 0) {
                    Text(new Date(reply.created * 1000).toLocaleDateString()).fontSize(12).fontColor(themeMutedText(this.darkMode))
                  }
                }.width('100%')
                if (this.editingReplyId === reply.id) {
                  TextArea({ placeholder: '编辑回复', text: this.editingReplyText }).width('100%').height(130).fontSize(15).fontColor(this.primaryText())
                    .onChange((value: string) => this.editingReplyText = value)
                  Row() {
                    if (this.editingReplyStatus.length > 0) Text(this.editingReplyStatus).fontSize(12).fontColor(themeAccentText(this.themeColor, this.darkMode))
                    Blank()
                    Text('取消').fontSize(13).fontColor(themeSecondaryText(this.darkMode)).margin({ right: 16 }).onClick(() => this.editingReplyId = 0)
                    Button('保存').fontSize(13).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor)).onClick(() => this.saveReplyEdit())
                  }.width('100%').margin({ top: 8 })
                } else {
                  ForEach(replyDetailParts(reply.content), (part: DetailPart) => {
                    if (part.kind === 'code') {
                      Text(part.value).fontSize(13).fontColor(this.bodyText()).lineHeight(20).fontFamily('monospace')
                        .width('100%').padding(10).backgroundColor(this.darkMode ? '#18212B' : '#F3F5F7')
                        .borderRadius(5).margin({ top: 8 }).copyOption(CopyOptions.LocalDevice)
                        .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE).editMenuOptions(this.selectionMenu(part.value))
                    } else if (part.kind === 'table' && part.table) {
                      Column({ space: 1 }) {
                        Row() {
                          ForEach(part.table.headers, (cell: string, cellIndex: number) => Text(plainMarkdown(cell)).fontSize(13)
                            .fontWeight(FontWeight.Medium).fontColor(this.primaryText()).layoutWeight(1)
                            .padding({ left: 7, right: 7, top: 7, bottom: 7 }).backgroundColor(this.darkMode ? '#26313D' : '#EAF1F8')
                            .copyOption(CopyOptions.LocalDevice).textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
                            .editMenuOptions(this.selectionMenu(plainMarkdown(cell))),
                            (cell: string, cellIndex: number) => `reply-table-header-${reply.id}-${cellIndex}`)
                        }.width('100%')
                        ForEach(part.table.rows, (row: string[], rowIndex: number) => Row() {
                          ForEach(part.table?.headers ?? [], (header: string, cellIndex: number) => Text(plainMarkdown(row[cellIndex] ?? ''))
                            .fontSize(13).fontColor(this.bodyText()).layoutWeight(1)
                            .padding({ left: 7, right: 7, top: 7, bottom: 7 })
                            .backgroundColor(rowIndex % 2 === 0 ? this.surface() : (this.darkMode ? '#202A35' : '#F7F9FB'))
                            .copyOption(CopyOptions.LocalDevice).textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
                            .editMenuOptions(this.selectionMenu(plainMarkdown(row[cellIndex] ?? ''))),
                            (header: string, cellIndex: number) => `reply-table-cell-${reply.id}-${rowIndex}-${cellIndex}`)
                        }.width('100%'), (row: string[], rowIndex: number) => `reply-table-row-${reply.id}-${rowIndex}`)
                      }.width('100%').border({ width: 1, color: this.darkMode ? '#3A4858' : '#D7E0EA' })
                        .margin({ top: 10, bottom: 2 })
                    } else if (part.kind === 'image') {
                      if (isInlineEmojiImage(part.value)) {
                        Image(this.contentUrl(part.value)).width(18).height(18).objectFit(ImageFit.Contain)
                          .margin({ top: 8 }).onClick(() => this.openLink(part.value))
                      } else {
                        Image(this.contentUrl(part.value)).constraintSize({ maxWidth: '100%', maxHeight: 360 }).objectFit(ImageFit.Contain).margin({ top: 10 })
                          .onClick(() => this.openLink(part.value))
                      }
                    } else if (part.kind === 'mention') {
                      Text(`@${part.value}`).fontSize(15).fontColor(themeAccentText(this.themeColor, this.darkMode)).lineHeight(23).margin({ top: 8 })
                        .maxLines(1).wordBreak(WordBreak.BREAK_WORD).flexShrink(0)
                        .decoration({ type: TextDecorationType.Underline, color: themeAccentText(this.themeColor, this.darkMode) })
                        .copyOption(CopyOptions.LocalDevice).textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
                        .editMenuOptions(this.selectionMenu(`@${part.value}`)).onClick(() => router.pushUrl({ url: 'pages/Profile', params: { username: part.value } }))
                    } else if (part.kind === 'link') {
                      Text(part.label ?? part.value).fontSize(15).fontColor(themeAccentText(this.themeColor, this.darkMode)).lineHeight(23).margin({ top: 8 })
                        .decoration({ type: TextDecorationType.Underline, color: themeAccentText(this.themeColor, this.darkMode) })
                        .copyOption(CopyOptions.LocalDevice).textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
                        .editMenuOptions(this.selectionMenu(part.label ?? part.value)).onClick(() => this.openLink(part.value))
                    } else {
                      Flex({ wrap: FlexWrap.Wrap }) {
                        ForEach(replyTextParts(plainMarkdown(part.value)), (fragment: ReplyTextPart) => {
                          Text(fragment.kind === 'mention' ? `@${fragment.value}` : fragment.value)
                            // Keep an @mention together like the web renderer;
                            // otherwise ArkUI may break after the @ glyph when
                            // the flex row wraps. Emoji stay in the normal text
                            // node so they use the same line box as surrounding content.
                            .fontSize(15).fontColor(fragment.kind === 'mention' ? themeAccentText(this.themeColor, this.darkMode) : this.bodyText()).lineHeight(23)
                            .maxLines(fragment.kind === 'mention' ? 1 : 100)
                            .wordBreak(WordBreak.BREAK_WORD)
                            .flexShrink(fragment.kind === 'mention' ? 0 : 1)
                            .decoration({ type: fragment.kind === 'mention' ? TextDecorationType.Underline : TextDecorationType.None, color: themeAccentText(this.themeColor, this.darkMode) })
                            .copyOption(CopyOptions.LocalDevice).textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
                            .editMenuOptions(this.selectionMenu(fragment.kind === 'mention' ? `@${fragment.value}` : fragment.value))
                            .onClick(() => {
                              if (fragment.kind === 'mention') router.pushUrl({ url: 'pages/Profile', params: { username: fragment.value } });
                            });
                        }, (fragment: ReplyTextPart, fragmentIndex: number) => `reply-text-${reply.id}-${fragmentIndex}`)
                      }.width('100%').margin({ top: 8 })
                    }
                  }, (part: DetailPart, partIndex: number) => `reply-part-${reply.id}-${part.kind}-${partIndex}`)
                  if (this.base64Result.length > 0 && this.base64Source.length > 0 && plainMarkdown(reply.content).indexOf(this.base64Source) >= 0) this.base64Card()
                  Row() {
                    if (!this.isSelf(reply.member?.username) || (reply.thanks ?? 0) > 0) {
                      Row() {
                        Image($r('app.media.ic_heart')).width(17).height(17)
                          .fillColor(this.thankedReplies.indexOf(reply.id) >= 0 || reply.thanked === true ? '#D05A73' : themeSecondaryText(this.darkMode))
                        Text(`${reply.thanks ?? 0}`).fontSize(13).fontColor(this.thankedReplies.indexOf(reply.id) >= 0 || reply.thanked === true ? '#D05A73' : themeSecondaryText(this.darkMode)).margin({ left: 4 })
                      }.padding({ left: 8, right: 8, top: 5, bottom: 5 })
                        .onClick(() => { if (!this.isSelf(reply.member?.username)) this.thankReply(reply.id); })
                    }
                    Text('回复').fontSize(13).fontColor(themeSecondaryText(this.darkMode)).margin({ left: 16 }).onClick(() => {
                      if (reply.member?.username) {
                        this.replyText = `@${reply.member.username} `;
                        this.replyComposerOpen = true;
                      }
                    })
                    Text('分享').fontSize(13).fontColor(themeSecondaryText(this.darkMode)).margin({ left: 16 })
                      .onClick(() => this.shareLink(this.replyShareUrl(reply), reply.content))
                    if (hasReplyReferences(reply.content)) {
                      Text('查看评论').fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode)).margin({ left: 16 })
                        .onClick(() => router.pushUrl({ url: 'pages/RelatedReplies', params: { topicId: this.topicId, replyId: reply.id } }))
                    }
                    Blank()
                    if (!this.isSelf(reply.member?.username)) {
                      Text('隐藏').fontSize(13).fontColor(themeMutedText(this.darkMode)).margin({ right: 16 }).onClick(() => this.ignoreReply(reply.id))
                    }
                    if (this.canEditReply(reply)) {
                      Text('编辑').fontSize(13).fontColor(themeSecondaryText(this.darkMode)).onClick(() => this.beginEditReply(reply))
                    }
                  }.width('100%').margin({ top: 10 })
                }
              }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 16, bottom: 16 })
                .backgroundColor(this.surface()).margin({ bottom: 1 })
            }, (reply: V2exReply) => `${reply.id}`)
            if (this.replies.length > 0) {
              Row() {
                if (this.replyMoreStatus.length > 0) Text(this.replyMoreStatus).fontSize(13).fontColor(themeMutedText(this.darkMode))
                if (!this.noMoreReplies) Button(this.loadingMoreReplies ? '加载中…' : '加载更多回复').fontSize(13).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor))
                  .onClick(() => this.loadMoreReplies())
              }.width('100%').padding(18).justifyContent(FlexAlign.Center)
            }
          }.width('100%').constraintSize({ minHeight: '100%' })
          }.layoutWeight(1).width('100%').onReachEnd(() => this.loadMoreReplies())
          if (this.replyComposerOpen) {
            Column() {
              TextArea({ placeholder: '发送你的评论', text: this.replyText }).width('100%').height(72).fontSize(15)
                .fontColor(this.primaryText()).textAlign(TextAlign.Start)
                .backgroundColor(this.pageBackground()).borderRadius(10)
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .onChange((value: string) => this.replyText = value)
              Row() {
                if (this.replyStatus.length > 0) Text(this.replyStatus).fontSize(12).fontColor(themeAccentText(this.themeColor, this.darkMode)).maxLines(1)
                Blank()
                Text('@ 回复对象').fontSize(13).fontColor(themeAccentText(this.themeColor, this.darkMode)).margin({ right: 14 })
                  .onClick(() => router.pushUrl({ url: 'pages/SearchReplyMember', params: { topicId: this.topicId } }))
                Text('取消').fontSize(13).fontColor(themeSecondaryText(this.darkMode)).margin({ right: 14 })
                  .onClick(() => { if (!this.replying) this.replyComposerOpen = false; })
                Button(this.replying ? '发送中' : '发送').height(36).backgroundColor(this.themeColor).fontColor(themeOnColor(this.themeColor))
                  .fontSize(13).onClick(() => this.submitReply())
              }.width('100%').height(40).margin({ top: 4 })
            }.width('100%').padding({ left: 12, right: 12, top: 8, bottom: 8 }).backgroundColor(this.surface())
          } else {
            Row() {
              Text(this.replyStatus.length > 0 ? this.replyStatus : '写下你的回复…').fontSize(14)
                .fontColor(this.replyStatus.length > 0 ? themeAccentText(this.themeColor, this.darkMode) : themeMutedText(this.darkMode)).layoutWeight(1).maxLines(1)
              Text('回复').fontSize(14).fontWeight(FontWeight.Medium).fontColor(themeAccentText(this.themeColor, this.darkMode))
            }.width('100%').height(48).padding({ left: 18, right: 18 }).backgroundColor(this.surface())
              .onClick(() => this.replyComposerOpen = true)
          }
        }.layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%').padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom }).backgroundColor(this.pageBackground())
  }
}
