import { http } from '@kit.NetworkKit';
import { webview } from '@kit.ArkWeb';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { V2exMember, V2exMemberRelations, V2exNode, V2exNotification, V2exReply, V2exTopic, V2exTopicStats } from '../model/V2exModels';

const API_BASE: string = 'https://www.v2ex.com';

export interface V2exSigninInfo {
  captchaUrl: string;
  once: string;
  usernameField: string;
  passwordField: string;
  codeField: string;
  limited: boolean;
}

export interface V2exSigninResult {
  success: boolean;
  twoFactor: boolean;
  once: string;
  member?: V2exMember;
}

export class V2exService {
  // Node metadata is shared by the home page, node navigation and hot-topic
  // pages. Keep a short-lived in-memory copy and coalesce concurrent requests
  // so opening several menu entries does not trigger duplicate full downloads.
  private static nodesMemory: V2exNode[] = [];
  private static nodesLoadedAt: number = 0;
  private static nodesRequest: Promise<V2exNode[]> | undefined = undefined;

  private static base(): string {
    try {
      const configured: string = (AppStorage.get<string>('v2exDomain') ?? '').trim().replace(/\/$/, '');
      if (/^https?:\/\//i.test(configured)) return configured;
    } catch (_) { /* use default domain */ }
    return API_BASE;
  }

  private static assetUrl(value: string): string {
    const raw: string = value.trim();
    if (raw.startsWith('//')) return `https:${raw}`;
    if (raw.startsWith('/')) return `${V2exService.base().replace(/\/$/, '')}${raw}`;
    return raw;
  }

  private static normalizeMember(member: V2exMember | undefined): void {
    if (member?.avatar_large) member.avatar_large = V2exService.assetUrl(member.avatar_large);
  }

  private static normalizeTopic(topic: V2exTopic): void {
    V2exService.normalizeMember(topic.member);
    if (topic.node?.avatar_large) topic.node.avatar_large = V2exService.assetUrl(topic.node.avatar_large);
  }

  private static cookie(): string {
    let webCookie: string = '';
    try { webCookie = webview.WebCookieManager.fetchCookieSync(V2exService.base()) || ''; } catch (_) { webCookie = ''; }
    let nativeCookie: string = '';
    try { nativeCookie = AppStorage.get<string>('v2exNativeCookie') ?? ''; } catch (_) { nativeCookie = ''; }
    return V2exService.mergeCookieHeaders(webCookie, nativeCookie);
  }

  /** Return the current session cookie for native image requests. */
  static sessionCookie(): string { return V2exService.cookie(); }

  private static mergeCookieHeaders(...headers: string[]): string {
    const values: string[] = [];
    const names: string[] = [];
    headers.forEach((header: string) => {
      header.split(';').forEach((part: string) => {
        const value: string = part.trim();
        const separator: number = value.indexOf('=');
        if (separator <= 0) return;
        const name: string = value.substring(0, separator).trim();
        if (names.indexOf(name) >= 0) {
          const index: number = names.indexOf(name);
          values[index] = value;
        } else {
          names.push(name);
          values.push(value);
        }
      });
    });
    return values.join('; ');
  }

  private static rememberResponseCookies(response: http.HttpResponse): void {
    let raw: string = '';
    try { raw = String(response.cookies ?? ''); } catch (_) { raw = ''; }
    try {
      const header: Record<string, Object> = response.header as Record<string, Object>;
      raw = `${raw};${String(header['set-cookie'] ?? header['Set-Cookie'] ?? '')}`;
    } catch (_) { /* cookie headers are optional on some API levels */ }
    if (raw.trim().length === 0) return;
    const cookies: string[] = raw.split(/,(?=[^;,\s]+=)/g).map((item: string) => item.trim()).filter((item: string) => item.indexOf('=') > 0);
    const cookiePairs: string = cookies.map((item: string) => item.split(';')[0].trim()).filter((item: string) => item.indexOf('=') > 0).join('; ');
    let current: string = '';
    try { current = AppStorage.get<string>('v2exNativeCookie') ?? ''; } catch (_) { current = ''; }
    const cookieHeader: string = V2exService.mergeCookieHeaders(current, cookiePairs);
    try { AppStorage.setOrCreate('v2exNativeCookie', cookieHeader); } catch (_) { /* storage may be unavailable during startup */ }
    // Keep the Web component session in sync for links opened after a native login.
    if (cookiePairs.length > 0) {
      try { webview.WebCookieManager.configCookieSync(V2exService.base(), cookiePairs); } catch (_) { /* native HTTP remains the source of truth */ }
    }
    try { webview.WebCookieManager.saveCookieAsync(); } catch (_) { /* best effort */ }
  }

  private static formInputName(html: string, label: string, fallback: string): string {
    const inputs: RegExpMatchArray | null = html.match(/<input\b[^>]*>/gi);
    const hint: RegExp = new RegExp(`(?:${label})`, 'i');
    if (inputs) {
      for (const input of inputs) {
        const name: RegExpMatchArray | null = input.match(/\bname=["']([^"']+)["']/i);
        if (name?.[1] && hint.test(input)) return name[1];
      }
    }
    // Some deployments render labels outside the input tag. Keep a row-level
    // fallback for those pages while still limiting the match to one form row.
    const row: RegExpMatchArray | null = html.match(new RegExp(`${label}[\\s\\S]{0,900}?<input[^>]+name=["']([^"']+)["']`, 'i'));
    return row?.[1] ?? fallback;
  }

  private static formHiddenValue(html: string, name: string): string {
    const match: RegExpMatchArray | null = html.match(new RegExp(`<input[^>]+name=["']${name}["'][^>]*value=["']([^"']+)["']`, 'i'))
      ?? html.match(new RegExp(`<input[^>]+value=["']([^"']+)["'][^>]*name=["']${name}["']`, 'i'));
    return match?.[1] ?? '';
  }

  private static signinProblem(html: string): string {
    const match: RegExpMatchArray | null = html.match(/class=["'][^"']*problem[^"']*["'][^>]*>[\s\S]*?<li[^>]*>([\s\S]*?)<\/li>/i);
    return V2exService.cleanHtml(match?.[1] ?? '');
  }

  private static formValue(value: string): string {
    return encodeURIComponent(value).replace(/%20/g, '+');
  }

  private static cleanHtml(value: string): string {
    return value.replace(/<br\s*\/?>(\r?\n)?/gi, '\n').replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/gi, ' ').replace(/&amp;/gi, '&').replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>').replace(/&#39;/gi, "'").trim();
  }
  private static htmlContentToMarkdown(value: string): string {
    return V2exService.cleanHtml(value
      .replace(/<img[^>]+src=["']([^"']+)["'][^>]*>/gi, '\n![图片]($1)\n')
      .replace(/<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi, '[$2]($1)')
      .replace(/<\/p>|<br\s*\/?>(\r?\n)?/gi, '\n'));
  }
  private static signedInHtml(html: string): boolean {
    return html.indexOf('/logout') >= 0 || html.indexOf('/member/') >= 0;
  }
  private static mutationSucceeded(response: http.HttpResponse): boolean {
    if (response.responseCode < 200 || response.responseCode >= 400) return false;
    const body: string = typeof response.result === 'string' ? response.result : '';
    if (body.length === 0) return true;
    if (/class=["'][^"']*problem|操作失败|请先登录|登录失败|验证码错误/i.test(body)) return false;
    if (body.indexOf('/signin') >= 0 && !V2exService.signedInHtml(body)) return false;
    return true;
  }

  /** Return the rendered H5 block for one reply only. */
  private static replyBlock(html: string, replyId: number): string {
    const match: RegExpMatchArray | null = html.match(new RegExp(`id=["']r_${replyId}["'][\\s\\S]*?(?=id=["']r_\\d+["']|$)`, 'i'));
    return match?.[0] ?? '';
  }

  /** V2EX places edit links in each reply's own block. Never inspect the full page. */
  private static replyIsEditable(html: string, replyId: number): boolean {
    const block: string = V2exService.replyBlock(html, replyId);
    return block.length > 0 && new RegExp(`/edit/reply/${replyId}(?:[?"'\\s])`, 'i').test(block);
  }

  private static replyNo(block: string): number | undefined {
    const match: RegExpMatchArray | null = block.match(/class=["'][^"']*\bno\b[^"']*["'][^>]*>\s*#?(\d+)/i);
    const value: number = Number(match?.[1] ?? 0);
    return value > 0 ? value : undefined;
  }

  private static replyCreatedLabel(block: string): string | undefined {
    const match: RegExpMatchArray | null = block.match(/class=["'][^"']*\bago\b[^"']*["'][^>]*>([\s\S]*?)<\/[^>]+>/i);
    const value: string = V2exService.cleanHtml(match?.[1] ?? '');
    return value.length > 0 ? value : undefined;
  }
  private static replyThanks(block: string): number | undefined {
    const match: RegExpMatchArray | null = block.match(/class=["'][^"']*\bsmall\b[^"']*\bfade\b[^"']*["'][^>]*>([\s\S]*?)<\/[^>]+>/i);
    const value: string = V2exService.cleanHtml(match?.[1] ?? '');
    const count: RegExpMatchArray | null = value.match(/([\d,]+)\s*感谢/);
    return count ? Number(count[1].replace(/,/g, '')) : undefined;
  }
  private static async get(path: string, authenticated: boolean = false): Promise<string> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const url: string = path.startsWith('http') ? path : `${V2exService.base()}${path}`;
      const headers: Record<string, string> = {
        'Accept': 'application/json',
        'User-Agent': 'V2EX-HarmonyOS/1.0'
      };
      if (authenticated) headers['Cookie'] = V2exService.cookie();
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`网络请求失败 ${response.responseCode}`);
      }
      return response.result as string;
    } finally {
      request.destroy();
    }
  }

  static async topics(kind: 'latest' | 'hot' = 'latest', page: number = 1): Promise<V2exTopic[]> {
    const normalizedPage: number = Math.max(1, page);
    const path: string = normalizedPage === 1
      ? (kind === 'hot' ? '/api/topics/hot.json?limit=100' : '/api/topics/latest.json?limit=100')
      : (kind === 'hot' ? `/?tab=hot&p=${normalizedPage}` : `/recent?p=${normalizedPage}`);
    try {
      const parsed: V2exTopic[] = JSON.parse(await V2exService.get(path)) as V2exTopic[];
      if (!Array.isArray(parsed)) throw new Error('主题接口响应格式错误');
      parsed.forEach((item: V2exTopic) => {
        if (item.replies === undefined) item.replies = 0;
        if (item.content === undefined) item.content = '';
        V2exService.normalizeTopic(item);
      });
      return parsed;
    } catch (_) {
      // The public JSON feed can be rate-limited. Keep the home tab useful by
      // falling back to the same rendered pages used by the reference client.
      const htmlPath: string = kind === 'hot' ? `/?tab=hot${normalizedPage > 1 ? `&p=${normalizedPage}` : ''}` : `/recent${normalizedPage > 1 ? `?p=${normalizedPage}` : ''}`;
      return V2exService.parseRichTopicItems(await V2exService.get(htmlPath));
    }
  }

  /**
   * V2EX home board feeds (`?tab=tech`, `?tab=all`, `/changes`, ...). These
   * are rendered on the site home page rather than exposed through the public
   * JSON API, so parse the same HTML cells used by the reference client.
   */
  static async topicsForTab(tab: string, page: number = 1): Promise<V2exTopic[]> {
    const normalizedPage: number = Math.max(1, page);
    const path: string = tab === 'changes'
      ? `/changes${normalizedPage > 1 ? `?p=${normalizedPage}` : ''}`
      : `/?tab=${encodeURIComponent(tab)}${normalizedPage > 1 ? `&p=${normalizedPage}` : ''}`;
    const authenticated: boolean = tab === 'members';
    const html: string = await V2exService.get(path, authenticated);
    if (authenticated && !V2exService.signedInHtml(html)) throw new Error('请先登录');
    return V2exService.parseRichTopicItems(html);
  }

  static async searchTopics(query: string): Promise<V2exTopic[]> {
    const sort: string = AppStorage.get<string>('v2exSearchSort') ?? 'created';
    const order: string = AppStorage.get<string>('v2exSearchOrder') ?? '0';
    const gte: string = AppStorage.get<string>('v2exSearchGte') ?? '';
    const lte: string = AppStorage.get<string>('v2exSearchLte') ?? '';
    const dateParams: string = `${gte.length > 0 ? `&gte=${encodeURIComponent(gte)}` : ''}${lte.length > 0 ? `&lte=${encodeURIComponent(lte)}` : ''}`;
    const raw: Object = JSON.parse(await V2exService.get(`https://www.sov2ex.com/api/search?q=${encodeURIComponent(query)}&size=50&from=0&sort=${encodeURIComponent(sort)}&order=${encodeURIComponent(order)}${dateParams}`)) as Object;
    const payload: Record<string, Object> = raw as Record<string, Object>;
    const hits: Object[] = (payload['hits'] as Object[] | undefined) ?? [];
    const allNodes: V2exNode[] = await V2exService.nodes();
    const nodeMap: Map<number, V2exNode> = new Map<number, V2exNode>();
    allNodes.forEach((node: V2exNode) => { if (node.id !== undefined) nodeMap.set(node.id, node); });
    return hits.map((hit: Object) => {
      const source: Record<string, Object> = (hit as Record<string, Object>)['_source'] as Record<string, Object>;
      const nodeId: number = Number(source['node'] ?? 0);
      return {
        id: Number(source['id'] ?? 0), title: String(source['title'] ?? ''), content: String(source['content'] ?? ''),
        replies: Number(source['replies'] ?? 0), last_modified: 0,
        last_touched: Math.floor(Date.parse(String(source['created'] ?? '')) / 1000),
        node: nodeMap.get(nodeId), member: { username: String(source['member'] ?? '') }
      } as V2exTopic;
    });
  }

  static async searchMembers(query: string): Promise<V2exMember[]> {
    const raw: Object = JSON.parse(await V2exService.get(`https://www.sov2ex.com/api/search?username=${encodeURIComponent(query)}&size=50&from=0&sort=created&order=0`)) as Object;
    const payload: Record<string, Object> = raw as Record<string, Object>;
    const hits: Object[] = (payload['hits'] as Object[] | undefined) ?? [];
    const result: V2exMember[] = [];
    hits.forEach((hit: Object) => {
      const source: Record<string, Object> = (hit as Record<string, Object>)['_source'] as Record<string, Object>;
      const username: string = String(source['member'] ?? source['username'] ?? '');
      if (username.length > 0 && result.findIndex((item: V2exMember) => item.username === username) < 0) {
        result.push({ username });
      }
    });
    return result;
  }

  static async uploadImage(uri: string, clientId: string): Promise<string> {
    if (clientId.trim().length === 0) throw new Error('请先配置 Imgur Client ID');
    const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const size: number = fileIo.statSync(file.fd).size;
      if (size <= 0 || size > 15 * 1024 * 1024) throw new Error('图片大小需在 15MB 以内');
      const buffer: ArrayBuffer = new ArrayBuffer(size);
      fileIo.readSync(file.fd, buffer);
      const encoded: string = new util.Base64Helper().encodeToStringSync(new Uint8Array(buffer));
      const request: http.HttpRequest = http.createHttp();
      try {
        const response: http.HttpResponse = await request.request('https://api.imgur.com/3/image', {
          method: http.RequestMethod.POST,
          header: { 'Authorization': `Client-ID ${clientId}`, 'Content-Type': 'application/x-www-form-urlencoded' },
          extraData: `type=base64&image=${V2exService.formValue(encoded)}`,
          connectTimeout: 12000,
          readTimeout: 30000,
          expectDataType: http.HttpDataType.STRING
        });
        if (response.responseCode < 200 || response.responseCode >= 300) throw new Error(`上传失败 ${response.responseCode}`);
        const payload: Record<string, Object> = JSON.parse(response.result as string) as Record<string, Object>;
        const data: Record<string, Object> = payload['data'] as Record<string, Object>;
        const link: string = String(data?.['link'] ?? '');
        if (link.length === 0) throw new Error('图床没有返回图片地址');
        return link;
      } finally { request.destroy(); }
    } finally { fileIo.closeSync(file.fd); }
  }

  static async nodes(): Promise<V2exNode[]> {
    const now: number = Date.now();
    if (V2exService.nodesMemory.length > 0 && now - V2exService.nodesLoadedAt < 15 * 60 * 1000) {
      return V2exService.nodesMemory;
    }
    if (V2exService.nodesRequest) return V2exService.nodesRequest;
    V2exService.nodesRequest = (async (): Promise<V2exNode[]> => {
      const data: V2exNode[] = JSON.parse(await V2exService.get('/api/nodes/all.json')) as V2exNode[];
      (data ?? []).forEach((item: V2exNode) => { if (item.avatar_large) item.avatar_large = V2exService.assetUrl(item.avatar_large); });
      const result: V2exNode[] = data ?? [];
      if (result.length > 0) {
        V2exService.nodesMemory = result;
        V2exService.nodesLoadedAt = Date.now();
      }
      return result;
    })();
    try {
      return await V2exService.nodesRequest;
    } finally {
      V2exService.nodesRequest = undefined;
    }
  }

  static async topicsForNode(name: string): Promise<V2exTopic[]> {
    const path: string = `/api/topics/show.json?node_name=${encodeURIComponent(name)}&page_size=100`;
    try {
      const data: V2exTopic[] = JSON.parse(await V2exService.get(path)) as V2exTopic[];
      if (!Array.isArray(data)) throw new Error('节点主题响应格式错误');
      data.forEach((item: V2exTopic) => V2exService.normalizeTopic(item));
      return data;
    } catch (_) {
      // The public node API can be rate-limited independently of the home feed.
      // Use the rendered node page as a resilient fallback so the native page
      // remains useful instead of getting stuck on an error state.
      const html: string = await V2exService.get(`/go/${encodeURIComponent(name)}`);
      return V2exService.parseRichTopicItems(html);
    }
  }

  static async topicsForNodePage(name: string, page: number): Promise<V2exTopic[]> {
    if (page === 1) return V2exService.topicsForNode(name);
    const html: string = await V2exService.get(`/go/${encodeURIComponent(name)}?p=${page}`);
    return V2exService.parseRichTopicItems(html);
  }

  static async xnaTopics(): Promise<V2exTopic[]> {
    const html: string = await V2exService.get('/xna');
    return V2exService.parseXnaItems(html);
  }

  static async member(username: string): Promise<V2exMember> {
    const parsed: Object = JSON.parse(await V2exService.get(`/api/members/show.json?username=${encodeURIComponent(username)}`)) as Object;
    if (Array.isArray(parsed)) {
      const list: V2exMember[] = parsed as V2exMember[];
      if (list.length === 0) throw new Error('用户不存在');
      V2exService.normalizeMember(list[0]);
      return list[0];
    }
    const member: V2exMember = parsed as V2exMember;
    V2exService.normalizeMember(member);
    return member;
  }

  static async memberTopics(username: string): Promise<V2exTopic[]> {
    const data: V2exTopic[] = JSON.parse(await V2exService.get(`/api/topics/show.json?username=${encodeURIComponent(username)}&page_size=100`)) as V2exTopic[];
    (data ?? []).forEach((item: V2exTopic) => V2exService.normalizeTopic(item));
    return data ?? [];
  }

  static async memberReplies(username: string): Promise<V2exReply[]> {
    try {
      const data: V2exReply[] = JSON.parse(await V2exService.get(`/api/replies/show.json?username=${encodeURIComponent(username)}&page_size=100`)) as V2exReply[];
      (data ?? []).forEach((item: V2exReply) => V2exService.normalizeMember(item.member));
      if (Array.isArray(data) && data.length > 0) return data;
    } catch (_) { /* the public replies endpoint is unavailable on some V2EX deployments */ }
    // V2EX currently renders recent replies on the member page even when the
    // JSON endpoint returns an empty array. Parse that rendered fallback so
    // the native profile's “回复” tab does not appear mysteriously empty.
    const html: string = await V2exService.get(`/member/${encodeURIComponent(username)}`);
    const result: V2exReply[] = [];
    const usedIds: number[] = [];
    const pattern: RegExp = /<div\s+class=["']dock_area["']>([\s\S]*?)<\/div>\s*<div\s+class=["']inner["']>[\s\S]*?<div\s+class=["']reply_content["'][^>]*>([\s\S]*?)<\/div>/gi;
    let index: number = 0;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      const anchor: RegExpMatchArray | null = match[1].match(/href=["']\/t\/(\d+)(?:#reply(\d+))?["'][^>]*>([\s\S]*?)<\/a>/i);
      if (anchor) {
        const topicId: number = Number(anchor[1]);
        const timeMatch: RegExpMatchArray | null = match[1].match(/<span\s+class=["']fade["']\s+title=["']([^"']+)["']/i);
        const parsedTime: number = timeMatch ? new Date(timeMatch[1]).getTime() : 0;
        let replyId: number = Number(anchor[2] ?? 0) || (topicId * 1000 + index);
        // A single V2EX reply can contain several rendered reply blocks with
        // the same reply number. Keep every block visible in ArkUI's ForEach.
        if (usedIds.indexOf(replyId) >= 0) replyId = topicId * 100000 + index;
        usedIds.push(replyId);
        result.push({
          id: replyId,
          topic_id: topicId,
          topic_title: V2exService.cleanHtml(anchor[3]),
          content: V2exService.htmlContentToMarkdown(match[2]),
          created: parsedTime > 0 ? Math.floor(parsedTime / 1000) : 0,
          member: { username }
        });
        index += 1;
      }
      match = pattern.exec(html);
    }
    return result;
  }

  static async memberRelations(username: string): Promise<V2exMemberRelations> {
    try {
      const html: string = await V2exService.get(`/member/${encodeURIComponent(username)}`, true);
      return {
        followed: /\/unfollow\/member\//i.test(html),
        blocked: /\/unblock\/member\//i.test(html)
      };
    } catch (_) { return { followed: false, blocked: false }; }
  }

  static async currentMember(): Promise<V2exMember | undefined> {
    const html: string = await V2exService.get('/settings', true);
    if (html.indexOf('/signin') >= 0 && html.indexOf('/logout') < 0) return undefined;
    const match: RegExpMatchArray | null = html.match(/href=["']\/member\/([^"']+)["']/i);
    if (!match) return undefined;
    const username: string = decodeURIComponent(match[1]);
    try { return await V2exService.member(username); }
    catch (_) { return { username }; }
  }

  static async signinInfo(): Promise<V2exSigninInfo> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/signin?now=${Date.now()}`, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'text/html,application/xhtml+xml',
          'User-Agent': 'Mozilla/5.0 (HarmonyOS; Mobile) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36'
        },
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      V2exService.rememberResponseCookies(response);
      if (response.responseCode < 200 || response.responseCode >= 400) throw new Error(`登录页请求失败 (${response.responseCode})`);
      const html: string = String(response.result ?? '');
      const captchaMatch: RegExpMatchArray | null = html.match(/<img[^>]+(?:id|name)=["']captcha-image["'][^>]+src=["']([^"']+)["']/i)
        ?? html.match(/<img[^>]+src=["']([^"']+)["'][^>]*(?:id|name)=["']captcha-image["']/i);
      const captchaPath: string = captchaMatch?.[1] ?? '';
      const captchaUrl: string = captchaPath.length > 0
        ? (captchaPath.startsWith('http') ? captchaPath : `${V2exService.base()}${captchaPath.startsWith('/') ? captchaPath : `/${captchaPath}`}`) + (captchaPath.indexOf('?') >= 0 ? `&now=${Date.now()}` : `?now=${Date.now()}`)
        : '';
      const once: string = V2exService.formHiddenValue(html, 'once');
      const usernameField: string = V2exService.formInputName(html, '用户名|username|email', 'u');
      const passwordField: string = V2exService.formInputName(html, '密码|password', 'p');
      const codeField: string = V2exService.formInputName(html, '验证码|captcha|code|机器', 'code');
      return { captchaUrl, once, usernameField, passwordField, codeField, limited: captchaUrl.length === 0 };
    } finally { request.destroy(); }
  }

  /** Download the CAPTCHA with the native session and return an ArkUI image source. */
  static async signinCaptcha(url: string): Promise<string> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'image/png,image/*',
          'Cookie': V2exService.cookie(),
          'Referer': `${V2exService.base()}/signin`
        },
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      // Some V2EX deployments refresh PB3_SESSION while issuing the image.
      // Keep that session paired with the challenge used by the subsequent POST.
      V2exService.rememberResponseCookies(response);
      if (response.responseCode < 200 || response.responseCode >= 400) throw new Error(`验证码请求失败 (${response.responseCode})`);
      const bytes: Uint8Array = new Uint8Array(response.result as ArrayBuffer);
      if (bytes.length === 0) throw new Error('验证码为空');
      let mime: string = 'image/png';
      try {
        const headers: Record<string, Object> = response.header as Record<string, Object>;
        const contentType: string = String(headers['content-type'] ?? headers['Content-Type'] ?? '').split(';')[0].trim();
        if (contentType.startsWith('image/')) mime = contentType;
      } catch (_) { /* use the PNG default */ }
      const encoded: string = new util.Base64Helper().encodeToStringSync(bytes);
      return `data:${mime};base64,${encoded}`;
    } finally { request.destroy(); }
  }

  static async signin(info: V2exSigninInfo, username: string, password: string, code: string): Promise<V2exSigninResult> {
    // Keep the native POST identical to the reference H5 form. The field
    // names are deployment-specific hashes; the H5 client submits only those
    // fields and the hidden nonce (the username is stripped before posting).
    const values: string = `${V2exService.formValue(info.usernameField)}=${V2exService.formValue(username)}&${V2exService.formValue(info.passwordField)}=${V2exService.formValue(password.trim())}&${V2exService.formValue(info.codeField)}=${V2exService.formValue(code.trim())}&once=${V2exService.formValue(info.once)}`;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/signin`, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': V2exService.cookie(),
          'Referer': `${V2exService.base()}/signin`,
          'Origin': V2exService.base(),
          'User-Agent': 'Mozilla/5.0 (HarmonyOS; Mobile) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36'
        },
        extraData: values,
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      V2exService.rememberResponseCookies(response);
      const html: string = String(response.result ?? '');
      const otp: RegExpMatchArray | null = html.match(/id=["']otp_code["'][\s\S]*?<input[^>]+name=["']once["'][^>]+value=["']([^"']+)["']/i)
        ?? html.match(/<input[^>]+name=["']once["'][^>]+value=["']([^"']+)["'][\s\S]*id=["']otp_code["']/i);
      if (otp) return { success: false, twoFactor: true, once: otp[1] };
      const problem: string = V2exService.signinProblem(html);
      if (problem.length > 0) throw new Error(problem);
      const member: V2exMember | undefined = await V2exService.currentMember();
      if (member) return { success: true, twoFactor: false, once: '', member };
      if (response.responseCode >= 200 && response.responseCode < 400 && html.length === 0 && V2exService.cookie().length > 0) {
        return { success: true, twoFactor: false, once: '' };
      }
      throw new Error('登录失败，请检查用户名、密码和验证码');
    } finally { request.destroy(); }
  }

  static async signinTwoFactor(once: string, code: string): Promise<V2exMember | undefined> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/2fa`, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': V2exService.cookie(),
          'Referer': `${V2exService.base()}/2fa`,
          'Origin': V2exService.base(),
          'User-Agent': 'Mozilla/5.0 (HarmonyOS; Mobile) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36'
        },
        extraData: `code=${V2exService.formValue(code)}&once=${V2exService.formValue(once)}`,
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      V2exService.rememberResponseCookies(response);
      const html: string = String(response.result ?? '');
      const problem: string = V2exService.signinProblem(html);
      if (problem.length > 0) throw new Error(problem);
      const member: V2exMember | undefined = await V2exService.currentMember();
      if (member) return member;
      throw new Error('两步验证码错误或已过期');
    } finally { request.destroy(); }
  }

  static async checkin(): Promise<boolean> {
    const html: string = await V2exService.get('/mission/daily', true);
    if (!V2exService.signedInHtml(html)) return false;
    const redeem: RegExpMatchArray | null = html.match(/\/mission\/daily\/redeem\?once=\d+/i);
    if (!redeem) return true;
    const result: string = await V2exService.get(redeem[0], true);
    return /ok-sign|fa-check|每日登录|领取成功/i.test(result);
  }

  static async myTopics(page: number = 1): Promise<V2exTopic[]> {
    const html: string = await V2exService.get(`/my/topics?p=${Math.max(1, page)}`, true);
    if (!V2exService.signedInHtml(html)) throw new Error('请先登录');
    return V2exService.parseRichTopicItems(html);
  }

  static async myFavorites(page: number = 1): Promise<V2exTopic[]> {
    // V2EX calls the bookmarked-topic feed `/my/topics`; `/my/favorites`
    // redirects to a non-authenticated page and made a valid session look
    // signed out in the native favorites screen.
    const html: string = await V2exService.get(`/my/topics?p=${Math.max(1, page)}`, true);
    if (!V2exService.signedInHtml(html)) throw new Error('请先登录');
    return V2exService.parseRichTopicItems(html);
  }

  static async notifications(page: number = 1): Promise<V2exNotification[]> {
    const html: string = await V2exService.get(`/notifications?p=${Math.max(1, page)}`, true);
    if (!V2exService.signedInHtml(html)) throw new Error('请先登录');
    const result: V2exNotification[] = [];
    const pattern: RegExp = /id=["']n_(\d+)["']([\s\S]*?)(?=id=["']n_\d+["']|$)/gi;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      const block: string = match[2];
      const avatarMatch: RegExpMatchArray | null = block.match(/<img[^>]+src=["']([^"']+)["'][^>]*alt=["']([^"']+)["']/i);
      const topicMatch: RegExpMatchArray | null = block.match(/<a[^>]+href=["']\/t\/(\d+)[^"']*["'][^>]*>([\s\S]*?)<\/a>/i);
      if (avatarMatch && topicMatch) {
        const deleteMatch: RegExpMatchArray | null = block.match(/href=["']\/delete\/notification\/\d+\?once=([^"']+)["']/i)
          ?? block.match(/href=["'][^"']*\/delete\/notification\/\d+\?once=([^"']+)["']/i)
          ?? block.match(/onclick=["'][^"']*,\s*([\w-]+)\s*\)["']/i);
        const createdMatch: RegExpMatchArray | null = block.match(/class=["'][^"']*\b(?:snow|fade)\b[^"']*["'][^>]*>([\s\S]*?)<\//i);
        result.push({
          id: Number(match[1]), once: deleteMatch?.[1], avatar: V2exService.assetUrl(avatarMatch[1]), username: avatarMatch[2],
          topicId: Number(topicMatch[1]), topicTitle: V2exService.cleanHtml(topicMatch[2]),
          created: createdMatch ? V2exService.cleanHtml(createdMatch[1]) : undefined
        });
      }
      match = pattern.exec(html);
    }
    return result;
  }

  static async followingTopics(page: number = 1): Promise<V2exTopic[]> {
    const html: string = await V2exService.get(`/my/following?p=${Math.max(1, page)}`, true);
    if (!V2exService.signedInHtml(html)) throw new Error('请先登录');
    return V2exService.parseRichTopicItems(html);
  }

  static async hotestTopics(date: string): Promise<V2exTopic[]> {
    const raw: Object = JSON.parse(await V2exService.get(`https://v2exday.com/api.php?date=${encodeURIComponent(date)}`)) as Object;
    if (!Array.isArray(raw)) return [];
    const allNodes: V2exNode[] = await V2exService.nodes();
    const topics: V2exTopic[] = await Promise.all((raw as Object[]).map(async (item: Object): Promise<V2exTopic> => {
      const value: Record<string, Object> = item as Record<string, Object>;
      const url: string = String(value['url'] ?? '');
      const idMatch: RegExpMatchArray | null = url.match(/\/t\/(\d+)/);
      const nodeTitle: string = String(value['node'] ?? '');
      const topic: V2exTopic = {
        id: Number(idMatch?.[1] ?? 0), title: String(value['title'] ?? ''), content: '',
        replies: 0, last_modified: 0, last_touched: 0,
        node: allNodes.find((node: V2exNode) => node.title === nodeTitle),
        member: { username: String(value['user'] ?? '') }
      } as V2exTopic;
      // v2exday does not include the reply count. Enrich each ranked topic
      // from the public topic API so the historical list shows the same count
      // as the topic detail page instead of displaying zero for every row.
      if (topic.id > 0) {
        try {
          const parsed: V2exTopic[] = JSON.parse(await V2exService.get(`/api/topics/show.json?id=${topic.id}`)) as V2exTopic[];
          if (Array.isArray(parsed) && parsed.length > 0) {
            const remote: V2exTopic = parsed[0];
            V2exService.normalizeTopic(remote);
            topic.replies = remote.replies ?? 0;
            topic.node = remote.node ?? topic.node;
            topic.member = remote.member ?? topic.member;
          }
        } catch (_) { /* keep the ranked item visible if enrichment is rate-limited */ }
      }
      return topic;
    }));
    return topics.filter((topic: V2exTopic) => topic.id > 0);
  }

  static async topMembers(kind: 'rich' | 'player' = 'rich'): Promise<V2exMember[]> {
    const html: string = await V2exService.get(`/top/${kind}`);
    const result: V2exMember[] = [];
    const seen: string[] = [];
    const pattern: RegExp = /href=["']\/member\/([^"']+)["'][\s\S]*?<img[^>]+src=["']([^"']+)["'][\s\S]*?class=["'][^"']*top_name[^"']*["'][^>]*>([^<]*)</gi;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      const username: string = V2exService.cleanHtml(match[3]);
      if (username.length > 0 && seen.indexOf(username) < 0) {
        seen.push(username);
        result.push({ username, avatar_large: V2exService.assetUrl(match[2]) });
      }
      match = pattern.exec(html);
    }
    return result;
  }

  static async myNodes(): Promise<V2exNode[]> {
    const html: string = await V2exService.get('/my/nodes', true);
    if (!V2exService.signedInHtml(html)) throw new Error('请先登录');
    const all: V2exNode[] = await V2exService.nodes();
    const result: V2exNode[] = [];
    const pattern: RegExp = /href=["']\/go\/([^"']+)["'][\s\S]*?<\/a>/gi;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      const found: V2exNode | undefined = all.find((node: V2exNode) => node.name === match![1]);
      if (found && result.findIndex((node: V2exNode) => node.name === found.name) < 0) result.push(found);
      match = pattern.exec(html);
    }
    return result;
  }

  private static parseTopicItems(html: string): V2exTopic[] {
    const result: V2exTopic[] = [];
    const pattern: RegExp = /<a[^>]*(?:class=["'][^"']*item_title[^"']*["'][^>]*href=["']\/t\/(\d+)["']|href=["']\/t\/(\d+)["'][^>]*class=["'][^"']*item_title[^"']*["'])[^>]*>([\s\S]*?)<\/a>/gi;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      result.push({ id: Number(match[1] ?? match[2]), title: V2exService.cleanHtml(match[3]), content: '', replies: 0, last_modified: 0, last_touched: 0 });
      match = pattern.exec(html);
    }
    if (result.length === 0) {
      const fallback: RegExp = /href=["']\/t\/(\d+)(?:#[^"']*)?["'][^>]*>([\s\S]*?)<\/a>/gi;
      let generic: RegExpExecArray | null = fallback.exec(html);
      while (generic !== null) {
        const title: string = V2exService.cleanHtml(generic[2]);
        if (title.length > 1 && !title.includes('V2EX')) {
          const id: number = Number(generic[1]);
          if (result.findIndex((item: V2exTopic) => item.id === id) < 0) {
            result.push({ id, title, content: '', replies: 0, last_modified: 0, last_touched: 0 });
          }
        }
        generic = fallback.exec(html);
      }
    }
    return result;
  }

  /** Parse V2EX rendered list rows with member, node and reply metadata. */
  private static parseRichTopicItems(html: string): V2exTopic[] {
    const result: V2exTopic[] = [];
    const seen: number[] = [];
    // Current H5 pages use cells such as `cell from_123 t_456` and put the
    // topic link inside a `span.item_title`; older pages used `cell item`.
    // Parse the topic anchors first, then read metadata from their containing
    // cell so both layouts keep working.
    const pattern: RegExp = /<a\s+href=["']\/t\/(\d+)(?:#[^"']+)?["'][^>]*>([\s\S]*?)<\/a>/gi;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      const prefix: string = html.substring(Math.max(0, match.index - 180), match.index);
      const anchor: string = match[0];
      if (anchor.indexOf('topic-link') < 0 && prefix.indexOf('item_title') < 0) {
        match = pattern.exec(html);
        continue;
      }
      const id: number = Number(match[1]);
      if (id > 0 && seen.indexOf(id) < 0) {
        seen.push(id);
        const cellStartMatch: RegExpMatchArray | null = html.substring(0, match.index).match(/<div\s+class=["']cell\b[^"']*["'][^>]*>/gi);
        const cellStart: number = cellStartMatch && cellStartMatch.length > 0
          ? (html.substring(0, match.index).lastIndexOf(cellStartMatch[cellStartMatch.length - 1]))
          : Math.max(0, match.index - 2200);
        const nextCell: number = html.indexOf('<div class="cell', match.index + match[0].length);
        const context: string = html.substring(cellStart >= 0 ? cellStart : Math.max(0, match.index - 2200), nextCell > 0 ? nextCell : Math.min(html.length, match.index + 2600));
        const memberMatch: RegExpMatchArray | null = context.match(/href=["']\/member\/([^"']+)["'][\s\S]{0,500}?<img[^>]+alt=["']([^"']+)["']/i);
        const avatarMatch: RegExpMatchArray | null = context.match(/<img[^>]+src=["']([^"']+)["'][^>]*alt=["'][^"']+["']/i);
        const nodeMatch: RegExpMatchArray | null = context.match(/class=["'][^"']*\bnode\b[^"']*["'][^>]*href=["']\/go\/([^"']+)["'][^>]*>([\s\S]*?)<\/a>/i)
          ?? context.match(/href=["']\/go\/([^"']+)["'][^>]*class=["'][^"']*\bnode\b[^"']*["'][^>]*>([\s\S]*?)<\/a>/i);
        const countMatch: RegExpMatchArray | null = context.match(/class=["'][^"']*\bcount_(?:livid|orange)\b[^"']*["'][^>]*>([\d,]+)<\/a>/i);
        const timeMatch: RegExpMatchArray | null = context.match(/<span[^>]+title=["']([^"']+)["'][^>]*>([^<]*(?:ago|前)[^<]*)<\/span>/i);
        const parsedTouched: number = timeMatch ? Math.floor(Date.parse(timeMatch[1]) / 1000) : 0;
        const topic: V2exTopic = {
          id,
          title: V2exService.cleanHtml(match[2]),
          content: '',
          replies: countMatch ? Number(countMatch[1].replace(/,/g, '')) : 0,
          last_modified: 0,
          last_touched: parsedTouched > 0 ? parsedTouched : 0,
          lastTouchedLabel: timeMatch ? V2exService.cleanHtml(timeMatch[2]) : undefined,
          member: memberMatch ? { username: V2exService.cleanHtml(memberMatch[2]), avatar_large: V2exService.assetUrl(avatarMatch?.[1] ?? '') } : undefined,
          node: nodeMatch ? { name: V2exService.cleanHtml(nodeMatch[1]), title: V2exService.cleanHtml(nodeMatch[2]) } : undefined
        } as V2exTopic;
        V2exService.normalizeTopic(topic);
        result.push(topic);
      }
      match = pattern.exec(html);
    }
    if (result.length > 0) return result;
    return V2exService.parseTopicItems(html);
  }

  /** Parse the external blog entries on V2EX's VXNA page. */
  private static parseXnaItems(html: string): V2exTopic[] {
    const result: V2exTopic[] = [];
    const pattern: RegExp = /<div\s+class=["']xna-entry[^"']*["'][\s\S]*?<a\s+href=["']([^"']+)["'][^>]*class=["']topic-link["'][^>]*>([\s\S]*?)<\/a>[\s\S]*?<a\s+href=["']([^"']+)["'][^>]*class=["']node["'][^>]*>([\s\S]*?)<\/a>[\s\S]*?<a\s+href=["']\/member\/([^"']+)["'][^>]*>/gi;
    let offset: number = 0;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      result.push({
        id: 900000000 + offset,
        title: V2exService.cleanHtml(match[2]),
        content: '',
        url: match[1],
        replies: 0,
        last_modified: 0,
        last_touched: 0,
        node: { name: 'xna', title: V2exService.cleanHtml(match[4]) },
        member: { username: V2exService.cleanHtml(match[5]) }
      });
      offset += 1;
      match = pattern.exec(html);
    }
    // VXNA markup has changed class names over time. Keep a small generic
    // fallback that still extracts the first external article link from each
    // entry when the legacy topic-link/node/member classes are absent.
    if (result.length === 0) {
      const entryPattern: RegExp = /<div\s+class=["'][^"']*xna-entry[^"']*["'][\s\S]*?<\/div>/gi;
      let entry: RegExpExecArray | null = entryPattern.exec(html);
      let fallbackId: number = 900000000;
      while (entry !== null && result.length < 20) {
        const block: string = entry[0];
        const linkPattern: RegExp = /<a\s+href=["'](https?:\/\/[^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
        const link: RegExpExecArray | null = linkPattern.exec(block);
        if (link !== null) {
          const memberMatch: RegExpMatchArray | null = block.match(/href=["']\/member\/([^"']+)["']/i);
          result.push({
            id: fallbackId,
            title: V2exService.cleanHtml(link[2]),
            content: '',
            url: link[1],
            replies: 0,
            last_modified: 0,
            last_touched: 0,
            node: { name: 'xna', title: 'VXNA' },
            member: { username: memberMatch ? V2exService.cleanHtml(memberMatch[1]) : 'VXNA' }
          });
          fallbackId += 1;
        }
        entry = entryPattern.exec(html);
      }
    }
    // Keep the initial native render bounded while retaining a useful feed.
    return result.slice(0, 20);
  }

  private static parseTopicStats(html: string): V2exTopicStats {
    const statsMatch: RegExpMatchArray | null = html.match(/class=["'][^"']*topic_stats[^"']*["'][^>]*>([\s\S]*?)<\/[^>]+>/i);
    if (!statsMatch) return { views: undefined, likes: undefined, thanks: undefined } as V2exTopicStats;
    const text: string = V2exService.cleanHtml(statsMatch[1]);
    const views: RegExpMatchArray | null = text.match(/([\d,]+)\s*点击/);
    const likes: RegExpMatchArray | null = text.match(/([\d,]+)\s*收藏/);
    const thanks: RegExpMatchArray | null = text.match(/([\d,]+)\s*感谢/);
    return {
      views: views ? Number(views[1].replace(/,/g, '')) : undefined,
      likes: likes ? Number(likes[1].replace(/,/g, '')) : undefined,
      thanks: thanks ? Number(thanks[1].replace(/,/g, '')) : undefined
    };
  }

  static async topic(id: number): Promise<V2exTopic> {
    try {
      const parsed: Object = JSON.parse(await V2exService.get(`/api/topics/show.json?id=${id}`)) as Object;
      if (Array.isArray(parsed) && (parsed as V2exTopic[]).length > 0) {
        const topic: V2exTopic = (parsed as V2exTopic[])[0];
        V2exService.normalizeTopic(topic);
        try {
          const html: string = await V2exService.get(`/t/${id}`, true);
          topic.editable = html.indexOf(`/edit/topic/${id}`) >= 0;
          topic.appendable = html.indexOf(`/append/topic/${id}`) >= 0;
          topic.favorited = html.indexOf('/unfavorite/topic/') >= 0;
          topic.thanked = /topic_thanked/i.test(html);
          topic.ignored = html.indexOf('/unignore/topic/') >= 0;
          const stats = V2exService.parseTopicStats(html);
          if (stats.views !== undefined) topic.views = stats.views;
          if (stats.likes !== undefined) topic.likes = stats.likes;
          if (stats.thanks !== undefined) topic.thanks = stats.thanks;
        } catch (_) { /* public JSON is still usable when HTML metadata is unavailable */ }
        V2exService.normalizeTopic(topic);
        return topic;
      }
    } catch (_) { /* fall back to the HTML page */ }
    // The public JSON detail endpoint may return [] when the server applies
    // its anonymous rate limit. Fall back to the same HTML detail page used
    // by the reference client so a topic never opens as a blank screen.
    const html: string = await V2exService.get(`/t/${id}`);
    const titleMatch: RegExpMatchArray | null = html.match(/<title>([\s\S]*?)\s+-\s+V2EX<\/title>/i);
    const bodyMatch: RegExpMatchArray | null = html.match(/class=["'][^"']*topic_content[^"']*["'][^>]*>([\s\S]*?)<\/div>/i);
    if (!titleMatch) throw new Error('主题不存在');
    const stats = V2exService.parseTopicStats(html);
    const fallbackTopic: V2exTopic = {
      id, title: V2exService.cleanHtml(titleMatch[1]), content: V2exService.htmlContentToMarkdown(bodyMatch?.[1] ?? ''), replies: 0,
      last_modified: 0, last_touched: 0,
      views: stats.views, likes: stats.likes, thanks: stats.thanks,
      editable: html.indexOf(`/edit/topic/${id}`) >= 0,
      appendable: html.indexOf(`/append/topic/${id}`) >= 0,
      favorited: html.indexOf('/unfavorite/topic/') >= 0,
      thanked: /topic_thanked/i.test(html),
      ignored: html.indexOf('/unignore/topic/') >= 0
    } as V2exTopic;
    V2exService.normalizeTopic(fallbackTopic);
    return fallbackTopic;
  }

  private static parseReplyItems(html: string): V2exReply[] {
    const result: V2exReply[] = [];
    // H5 keeps each reply in its own `#r_ID` cell. Match the content first,
    // then resolve the surrounding cell for floor, author and permissions.
    const pattern: RegExp = /id=["']r_(\d+)["'][\s\S]*?<div\s+class=["'][^"']*\breply_content\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/gi;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      const replyId: number = Number(match[1]);
      const blockMatch: RegExpMatchArray | null = html.match(new RegExp(`id=["']r_${replyId}["']([\\s\\S]*?)(?=id=["']r_\\d+["']|$)`, 'i'));
      const block: string = blockMatch?.[1] ?? '';
      const memberMatch: RegExpMatchArray | null = block.match(/<strong>[\s\S]*?href=["']\/member\/([^"']+)["'][^>]*>([\s\S]*?)<\/a>/i)
        ?? block.match(/<img[^>]+alt=["']([^"']+)["']/i);
      const avatarMatch: RegExpMatchArray | null = block.match(/<img[^>]+src=["']([^"']+)["'][^>]*alt=["'][^"']+["']/i);
      const username: string = memberMatch ? V2exService.cleanHtml(memberMatch[2] ?? memberMatch[1]) : '匿名';
      result.push({
        id: replyId,
        content: V2exService.htmlContentToMarkdown(match[2]),
        created: 0,
        member: { username, avatar_large: V2exService.assetUrl(avatarMatch?.[1] ?? '') },
        no: V2exService.replyNo(block) ?? result.length + 1,
        createdLabel: V2exService.replyCreatedLabel(block),
        thanks: V2exService.replyThanks(block),
        editable: V2exService.replyIsEditable(html, replyId),
        thanked: /class=["'][^"']*thanked/i.test(block),
        op: /class=["'][^"']*badge[^"']*op/i.test(block),
        mod: /class=["'][^"']*badge[^"']*mod/i.test(block)
      });
      match = pattern.exec(html);
    }
    return result;
  }

  static async replies(id: number): Promise<V2exReply[]> {
    // The public replies API does not expose viewer-specific permissions.
    // Fetch the authenticated H5 page as well so editing is shown only while
    // V2EX itself exposes an /edit/reply/:id action for that exact reply.
    // Start the HTML and JSON requests together. The HTML is only needed for
    // viewer-specific flags (editable/thanks/op/mod), while the JSON carries
    // the reply list itself; doing them serially doubled the cold-load time.
    const pageRequest: Promise<string> = V2exService.get(`/t/${id}`, true).catch(() => '');
    const repliesRequest: Promise<string> = V2exService.get(`/api/replies/show.json?topic_id=${id}&page_size=100`);
    const pageHtml: string = await pageRequest;
    try {
      const parsed: Object = JSON.parse(await repliesRequest) as Object;
      if (Array.isArray(parsed) && (parsed as V2exReply[]).length > 0) {
        const replies: V2exReply[] = parsed as V2exReply[];
        replies.forEach((reply: V2exReply, index: number) => {
          V2exService.normalizeMember(reply.member);
          reply.editable = V2exService.replyIsEditable(pageHtml, reply.id);
          const block: string = V2exService.replyBlock(pageHtml, reply.id);
          // The JSON endpoint omits the floor. Keep the original API order as
          // the fallback so reversing the display order never renumbers rows.
          reply.no = V2exService.replyNo(block) ?? reply.no ?? index + 1;
          reply.createdLabel = V2exService.replyCreatedLabel(block) ?? reply.createdLabel;
          reply.thanks = V2exService.replyThanks(block) ?? reply.thanks;
          reply.thanked = /class=["'][^"']*thanked/i.test(block);
          reply.op = /class=["'][^"']*badge[^"']*op/i.test(block);
          reply.mod = /class=["'][^"']*badge[^"']*mod/i.test(block);
        });
        return replies;
      }
    } catch (_) { /* fall back to the HTML page */ }
    const html: string = pageHtml.length > 0 ? pageHtml : await V2exService.get(`/t/${id}`, true);
    return V2exService.parseReplyItems(html);
  }

  /** Fetch a later H5 reply page, preserving the floor numbers rendered by V2EX. */
  static async repliesPage(id: number, page: number): Promise<V2exReply[]> {
    if (page <= 1) return V2exService.replies(id);
    const html: string = await V2exService.get(`/t/${id}?p=${Math.max(1, page)}`, true);
    return V2exService.parseReplyItems(html);
  }

  static async reply(topicId: number, content: string): Promise<boolean> {
    const html: string = await V2exService.get(`/t/${topicId}`, true);
    const onceMatch: RegExpMatchArray | null = html.match(/(?:name|value)=["']once["'][^>]*value=["']([^"']+)["']/i) || html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i);
    if (!onceMatch) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/t/${topicId}`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/x-www-form-urlencoded', 'Cookie': V2exService.cookie(), 'Referer': `${V2exService.base()}/t/${topicId}` },
        extraData: `content=${V2exService.formValue(content)}&once=${V2exService.formValue(onceMatch[1])}`,
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      return V2exService.mutationSucceeded(response);
    } finally { request.destroy(); }
  }

  static async replyAction(topicId: number, replyId: number, action: 'thank' | 'ignore'): Promise<boolean> {
    const html: string = await V2exService.get(`/t/${topicId}`, true);
    const onceMatch: RegExpMatchArray | null = html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i);
    if (!onceMatch) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/${action}/reply/${replyId}?once=${V2exService.formValue(onceMatch[1])}`, {
        method: http.RequestMethod.POST,
        header: { 'Cookie': V2exService.cookie(), 'Referer': `${V2exService.base()}/t/${topicId}` },
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      return V2exService.mutationSucceeded(response);
    } finally { request.destroy(); }
  }

  static async editReply(replyId: number, content: string): Promise<boolean> {
    const html: string = await V2exService.get(`/edit/reply/${replyId}`, true);
    const onceMatch: RegExpMatchArray | null = html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i);
    if (!onceMatch) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/edit/reply/${replyId}`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/x-www-form-urlencoded', 'Cookie': V2exService.cookie(), 'Referer': `${V2exService.base()}/edit/reply/${replyId}` },
        extraData: `content=${V2exService.formValue(content)}&once=${V2exService.formValue(onceMatch[1])}`,
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      return V2exService.mutationSucceeded(response);
    } finally { request.destroy(); }
  }

  static async appendTopic(topicId: number, content: string): Promise<boolean> {
    const html: string = await V2exService.get(`/t/${topicId}`, true);
    const onceMatch: RegExpMatchArray | null = html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i);
    if (!onceMatch) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/append/topic/${topicId}`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/x-www-form-urlencoded', 'Cookie': V2exService.cookie(), 'Referer': `${V2exService.base()}/t/${topicId}` },
        extraData: `content=${V2exService.formValue(content)}&syntax=default&once=${V2exService.formValue(onceMatch[1])}`,
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      return V2exService.mutationSucceeded(response);
    } finally { request.destroy(); }
  }

  static async writeTopic(title: string, content: string, nodeName: string): Promise<boolean> {
    const html: string = await V2exService.get('/write', true);
    const onceMatch: RegExpMatchArray | null = html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i);
    if (!onceMatch) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/write`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/x-www-form-urlencoded', 'Cookie': V2exService.cookie(), 'Referer': `${V2exService.base()}/write` },
        extraData: `title=${V2exService.formValue(title)}&content=${V2exService.formValue(content)}&node_name=${V2exService.formValue(nodeName)}&syntax=default&once=${V2exService.formValue(onceMatch[1])}`,
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      return V2exService.mutationSucceeded(response);
    } finally { request.destroy(); }
  }

  static async editTopic(id: number, title: string, content: string, syntax: string = 'default', nodeName: string = ''): Promise<boolean> {
    const html: string = await V2exService.get(`/edit/topic/${id}`, true);
    const onceMatch: RegExpMatchArray | null = html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i);
    if (!onceMatch) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/edit/topic/${id}`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/x-www-form-urlencoded', 'Cookie': V2exService.cookie(), 'Referer': `${V2exService.base()}/edit/topic/${id}` },
        extraData: `title=${V2exService.formValue(title)}&content=${V2exService.formValue(content)}&syntax=${V2exService.formValue(syntax)}&once=${V2exService.formValue(onceMatch[1])}`,
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      let ok: boolean = V2exService.mutationSucceeded(response);
      // V2EX keeps node moves as a separate operation. Match the reference
      // client by submitting it after the title/body update when the editor
      // supplied a different node.
      const nodeValue: string = nodeName.trim();
      if (ok && nodeValue.length > 0 && html.indexOf(`value="${nodeValue}"`) < 0 && html.indexOf(`value='${nodeValue}'`) < 0) {
        const moveRequest: http.HttpRequest = http.createHttp();
        try {
          const moveResponse: http.HttpResponse = await moveRequest.request(`${V2exService.base()}/move/topic/${id}`, {
            method: http.RequestMethod.POST,
            header: { 'Content-Type': 'application/x-www-form-urlencoded', 'Cookie': V2exService.cookie(), 'Referer': `${V2exService.base()}/edit/topic/${id}` },
            extraData: `destination=${V2exService.formValue(nodeValue)}`,
            connectTimeout: 8000,
            readTimeout: 12000,
            expectDataType: http.HttpDataType.STRING
          });
          ok = V2exService.mutationSucceeded(moveResponse);
        } finally { moveRequest.destroy(); }
      }
      return ok;
    } finally { request.destroy(); }
  }

  static async topicAction(id: number, action: 'favorite' | 'unfavorite' | 'thank' | 'up' | 'down' | 'ignore' | 'unignore' | 'report'): Promise<boolean> {
    const html: string = await V2exService.get(`/t/${id}`, true);
    const onceMatch: RegExpMatchArray | null = html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i);
    if (!onceMatch) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const method: http.RequestMethod = action === 'thank' || action === 'up' || action === 'down' ? http.RequestMethod.POST : http.RequestMethod.GET;
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/${action}/topic/${id}?once=${V2exService.formValue(onceMatch[1])}`, {
        method,
        header: { 'Cookie': V2exService.cookie(), 'Referer': `${V2exService.base()}/t/${id}` },
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      return V2exService.mutationSucceeded(response);
    } finally { request.destroy(); }
  }

  static async memberAction(username: string, action: 'follow' | 'unfollow' | 'block' | 'unblock'): Promise<boolean> {
    const html: string = await V2exService.get(`/member/${encodeURIComponent(username)}`, true);
    const onceMatch: RegExpMatchArray | null = html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i);
    if (!onceMatch) return false;
    let memberId: number = 0;
    try {
      const member: V2exMember = await V2exService.member(username);
      memberId = Number(member.id ?? 0);
    } catch (_) { memberId = 0; }
    if (memberId <= 0) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/${action}/member/${memberId}?once=${V2exService.formValue(onceMatch[1])}`, {
        method: http.RequestMethod.GET,
        header: { 'Cookie': V2exService.cookie(), 'Referer': `${V2exService.base()}/member/${encodeURIComponent(username)}` },
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      return V2exService.mutationSucceeded(response);
    } finally { request.destroy(); }
  }

  static async notificationAction(notificationId: number, action: 'delete', once: string = ''): Promise<boolean> {
    const html: string = await V2exService.get('/notifications', true);
    let onceValue: string = once;
    if (onceValue.length === 0) {
      const onceMatch: RegExpMatchArray | null = html.match(new RegExp(`/delete/notification/${notificationId}\\?once=([^"']+)`, 'i'))
        ?? html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i);
      onceValue = onceMatch?.[1] ?? '';
    }
    if (onceValue.length === 0) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/${action}/notification/${notificationId}?once=${V2exService.formValue(onceValue)}`, {
        method: http.RequestMethod.POST,
        extraData: '',
        header: { 'Content-Type': 'application/x-www-form-urlencoded', 'Cookie': V2exService.cookie(), 'Referer': `${V2exService.base()}/notifications` },
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      return V2exService.mutationSucceeded(response);
    } finally { request.destroy(); }
  }

  static async nodeAction(name: string, action: 'favorite' | 'unfavorite'): Promise<boolean> {
    const html: string = await V2exService.get(`/go/${encodeURIComponent(name)}`, true);
    const linkPattern: RegExpMatchArray | null = html.match(/href=["']\/((?:un)?favorite\/node\/\d+\?once=[^"']+)["']/i);
    if (!linkPattern) return false;
    const target: string = linkPattern[1].replace(/^(?:un)?favorite/, action);
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/${target}`, {
        method: http.RequestMethod.GET,
        header: { 'Cookie': V2exService.cookie(), 'Referer': `${V2exService.base()}/go/${name}` },
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      return V2exService.mutationSucceeded(response);
    } finally { request.destroy(); }
  }

  static async nodeFavorited(name: string): Promise<boolean> {
    try {
      const html: string = await V2exService.get(`/go/${encodeURIComponent(name)}`, true);
      return /\/unfavorite\/node\//i.test(html);
    } catch (_) { return false; }
  }

  private static async settingsOnce(): Promise<string> {
    const html: string = await V2exService.get('/settings', true);
    const match: RegExpMatchArray | null = html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i)
      ?? html.match(/value=["']([^"']+)["'][^>]*name=["']once["']/i);
    return match?.[1] ?? '';
  }

  /** Invalidate the server session before local cookies are removed. */
  static async signout(): Promise<boolean> {
    let once: string = '';
    try { once = await V2exService.settingsOnce(); } catch (_) { return false; }
    if (once.length === 0) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/signout?once=${V2exService.formValue(once)}`, {
        method: http.RequestMethod.GET,
        header: { 'Cookie': V2exService.cookie(), 'Referer': `${V2exService.base()}/settings` },
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      return response.responseCode >= 200 && response.responseCode < 400;
    } finally { request.destroy(); }
  }

  static async resetBlocked(): Promise<boolean> {
    const once: string = await V2exService.settingsOnce();
    if (once.length === 0) return false;
    const html: string = await V2exService.get(`/settings/reset/blocked?once=${V2exService.formValue(once)}`, true);
    return !/请先登录|登录后才能/i.test(html) && html.indexOf('/signin') < 0;
  }

  static async resetIgnoredTopics(): Promise<boolean> {
    const once: string = await V2exService.settingsOnce();
    if (once.length === 0) return false;
    const html: string = await V2exService.get(`/settings/reset/ignored_topics?once=${V2exService.formValue(once)}`, true);
    return !/请先登录|登录后才能/i.test(html) && html.indexOf('/signin') < 0;
  }
}
