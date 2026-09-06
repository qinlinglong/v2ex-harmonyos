import { http } from '@kit.NetworkKit';
import { webview } from '@kit.ArkWeb';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { V2exMember, V2exMemberRelations, V2exNode, V2exNotification, V2exReply, V2exTopic } from '../model/V2exModels';

const API_BASE: string = 'https://www.v2ex.com';

export class V2exService {
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

  private static cookie(): string {
    try { return webview.WebCookieManager.fetchCookieSync(V2exService.base()) || ''; } catch (_) { return ''; }
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

  static async topics(kind: 'latest' | 'hot' = 'latest'): Promise<V2exTopic[]> {
    const path: string = kind === 'hot' ? '/api/topics/hot.json?limit=100' : '/api/topics/latest.json?limit=100';
    const parsed: V2exTopic[] = JSON.parse(await V2exService.get(path)) as V2exTopic[];
    parsed.forEach((item: V2exTopic) => {
      if (item.replies === undefined) item.replies = 0;
      if (item.content === undefined) item.content = '';
    });
    return parsed;
  }

  static async searchTopics(query: string): Promise<V2exTopic[]> {
    const raw: Object = JSON.parse(await V2exService.get(`https://www.sov2ex.com/api/search?q=${encodeURIComponent(query)}&size=50&from=0&sort=created&order=0`)) as Object;
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
    const data: V2exNode[] = JSON.parse(await V2exService.get('/api/nodes/all.json')) as V2exNode[];
    return data ?? [];
  }

  static async topicsForNode(name: string): Promise<V2exTopic[]> {
    const path: string = `/api/topics/show.json?node_name=${encodeURIComponent(name)}&page_size=100`;
    const data: V2exTopic[] = JSON.parse(await V2exService.get(path)) as V2exTopic[];
    return data ?? [];
  }

  static async topicsForNodePage(name: string, page: number): Promise<V2exTopic[]> {
    if (page === 1) return V2exService.topicsForNode(name);
    const html: string = await V2exService.get(`/go/${encodeURIComponent(name)}?p=${page}`);
    return V2exService.parseTopicItems(html);
  }

  static async xnaTopics(): Promise<V2exTopic[]> {
    const html: string = await V2exService.get('/xna');
    return V2exService.parseTopicItems(html);
  }

  static async member(username: string): Promise<V2exMember> {
    const parsed: Object = JSON.parse(await V2exService.get(`/api/members/show.json?username=${encodeURIComponent(username)}`)) as Object;
    if (Array.isArray(parsed)) {
      const list: V2exMember[] = parsed as V2exMember[];
      if (list.length === 0) throw new Error('用户不存在');
      return list[0];
    }
    return parsed as V2exMember;
  }

  static async memberTopics(username: string): Promise<V2exTopic[]> {
    const data: V2exTopic[] = JSON.parse(await V2exService.get(`/api/topics/show.json?username=${encodeURIComponent(username)}&page_size=100`)) as V2exTopic[];
    return data ?? [];
  }

  static async memberReplies(username: string): Promise<V2exReply[]> {
    const data: V2exReply[] = JSON.parse(await V2exService.get(`/api/replies/show.json?username=${encodeURIComponent(username)}&page_size=100`)) as V2exReply[];
    return data ?? [];
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
    return V2exService.parseTopicItems(html);
  }

  static async myFavorites(page: number = 1): Promise<V2exTopic[]> {
    const html: string = await V2exService.get(`/my/favorites?p=${Math.max(1, page)}`, true);
    if (!V2exService.signedInHtml(html)) throw new Error('请先登录');
    return V2exService.parseTopicItems(html);
  }

  static async notifications(page: number = 1): Promise<V2exNotification[]> {
    const html: string = await V2exService.get(`/notifications?p=${Math.max(1, page)}`, true);
    if (!V2exService.signedInHtml(html)) throw new Error('请先登录');
    const result: V2exNotification[] = [];
    const pattern: RegExp = /id=["']n_(\d+)["'][\s\S]*?<img[^>]+src=["']([^"']+)["'][^>]*alt=["']([^"']+)["'][\s\S]*?<a[^>]+href=["']\/t\/(\d+)[^"']*["'][^>]*>([\s\S]*?)<\/a>/gi;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      result.push({ id: Number(match[1]), avatar: V2exService.assetUrl(match[2]), username: match[3], topicId: Number(match[4]), topicTitle: V2exService.cleanHtml(match[5]) });
      match = pattern.exec(html);
    }
    return result;
  }

  static async followingTopics(page: number = 1): Promise<V2exTopic[]> {
    const html: string = await V2exService.get(`/my/following?p=${Math.max(1, page)}`, true);
    if (!V2exService.signedInHtml(html)) throw new Error('请先登录');
    return V2exService.parseTopicItems(html);
  }

  static async hotestTopics(date: string): Promise<V2exTopic[]> {
    const raw: Object = JSON.parse(await V2exService.get(`https://v2exday.com/api.php?date=${encodeURIComponent(date)}`)) as Object;
    if (!Array.isArray(raw)) return [];
    const allNodes: V2exNode[] = await V2exService.nodes();
    return (raw as Object[]).map((item: Object) => {
      const value: Record<string, Object> = item as Record<string, Object>;
      const url: string = String(value['url'] ?? '');
      const idMatch: RegExpMatchArray | null = url.match(/\/t\/(\d+)/);
      const replyMatch: RegExpMatchArray | null = url.match(/reply(\d+)/);
      const nodeTitle: string = String(value['node'] ?? '');
      return {
        id: Number(idMatch?.[1] ?? 0), title: String(value['title'] ?? ''), content: '',
        replies: Number(replyMatch?.[1] ?? 0), last_modified: 0, last_touched: 0,
        node: allNodes.find((node: V2exNode) => node.title === nodeTitle),
        member: { username: String(value['user'] ?? '') }
      } as V2exTopic;
    }).filter((topic: V2exTopic) => topic.id > 0);
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

  static async topic(id: number): Promise<V2exTopic> {
    try {
      const parsed: Object = JSON.parse(await V2exService.get(`/api/topics/show.json?id=${id}`)) as Object;
      if (Array.isArray(parsed) && (parsed as V2exTopic[]).length > 0) {
        const topic: V2exTopic = (parsed as V2exTopic[])[0];
        try {
          const html: string = await V2exService.get(`/t/${id}`, true);
          topic.editable = html.indexOf(`/edit/topic/${id}`) >= 0;
          topic.appendable = html.indexOf(`/append/topic/${id}`) >= 0;
          topic.favorited = html.indexOf('/unfavorite/topic/') >= 0;
          topic.thanked = /topic_thanked/i.test(html);
          topic.ignored = html.indexOf('/unignore/topic/') >= 0;
        } catch (_) { /* public JSON is still usable when HTML metadata is unavailable */ }
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
    return {
      id, title: V2exService.cleanHtml(titleMatch[1]), content: V2exService.htmlContentToMarkdown(bodyMatch?.[1] ?? ''), replies: 0,
      last_modified: 0, last_touched: 0,
      editable: html.indexOf(`/edit/topic/${id}`) >= 0,
      appendable: html.indexOf(`/append/topic/${id}`) >= 0,
      favorited: html.indexOf('/unfavorite/topic/') >= 0,
      thanked: /topic_thanked/i.test(html),
      ignored: html.indexOf('/unignore/topic/') >= 0
    } as V2exTopic;
  }

  static async replies(id: number): Promise<V2exReply[]> {
    try {
      const parsed: Object = JSON.parse(await V2exService.get(`/api/replies/show.json?topic_id=${id}&page_size=100`)) as Object;
      if (Array.isArray(parsed) && (parsed as V2exReply[]).length > 0) return parsed as V2exReply[];
    } catch (_) { /* fall back to the HTML page */ }
    const html: string = await V2exService.get(`/t/${id}`);
    const result: V2exReply[] = [];
    const pattern: RegExp = /id=["']r_(\d+)["'][\s\S]*?<img[^>]+src=["']([^"']+)["'][^>]*alt=["']([^"']+)["'][\s\S]*?<div class=["']reply_content["']>([\s\S]*?)<\/div>/gi;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      result.push({ id: Number(match[1]), content: V2exService.cleanHtml(match[4]), created: 0, member: { username: match[3], avatar_large: V2exService.assetUrl(match[2]) } });
      match = pattern.exec(html);
    }
    return result;
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

  static async notificationAction(notificationId: number, action: 'delete'): Promise<boolean> {
    const html: string = await V2exService.get('/notifications', true);
    const onceMatch: RegExpMatchArray | null = html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i);
    if (!onceMatch) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${V2exService.base()}/${action}/notification/${notificationId}?once=${V2exService.formValue(onceMatch[1])}`, {
        method: http.RequestMethod.GET,
        header: { 'Cookie': V2exService.cookie(), 'Referer': `${V2exService.base()}/notifications` },
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
