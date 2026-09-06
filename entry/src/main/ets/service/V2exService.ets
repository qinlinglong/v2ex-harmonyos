import { http } from '@kit.NetworkKit';
import { webview } from '@kit.ArkWeb';
import { V2exMember, V2exNode, V2exNotification, V2exReply, V2exTopic } from '../model/V2exModels';

const API_BASE: string = 'https://www.v2ex.com';

export class V2exService {
  private static cookie(): string {
    try { return webview.WebCookieManager.fetchCookieSync(API_BASE) || ''; } catch (_) { return ''; }
  }

  private static formValue(value: string): string {
    return encodeURIComponent(value).replace(/%20/g, '+');
  }

  private static cleanHtml(value: string): string {
    return value.replace(/<br\s*\/?>(\r?\n)?/gi, '\n').replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/gi, ' ').replace(/&amp;/gi, '&').replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>').replace(/&#39;/gi, "'").trim();
  }
  private static async get(path: string, authenticated: boolean = false): Promise<string> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const url: string = path.startsWith('http') ? path : `${API_BASE}${path}`;
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
        last_touched: Math.floor(new Date(String(source['created'] ?? '')).getTime() / 1000),
        node: nodeMap.get(nodeId), member: { username: String(source['member'] ?? '') }
      } as V2exTopic;
    });
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

  static async myTopics(): Promise<V2exTopic[]> {
    const html: string = await V2exService.get('/my/topics', true);
    if (html.indexOf('/signin') >= 0 && html.indexOf('item_title') < 0) throw new Error('请先登录');
    return V2exService.parseTopicItems(html);
  }

  static async myFavorites(): Promise<V2exTopic[]> {
    const html: string = await V2exService.get('/my/favorites', true);
    if (html.indexOf('/signin') >= 0 && html.indexOf('item_title') < 0) throw new Error('请先登录');
    return V2exService.parseTopicItems(html);
  }

  static async notifications(): Promise<V2exNotification[]> {
    const html: string = await V2exService.get('/notifications', true);
    if (html.indexOf('/signin') >= 0 && html.indexOf('id="n_') < 0) throw new Error('请先登录');
    const result: V2exNotification[] = [];
    const pattern: RegExp = /id=["']n_(\d+)["'][\s\S]*?<img[^>]+src=["']([^"']+)["'][^>]*alt=["']([^"']+)["'][\s\S]*?<a[^>]+href=["']\/t\/(\d+)[^"']*["'][^>]*>([\s\S]*?)<\/a>/gi;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      result.push({ id: Number(match[1]), avatar: match[2], username: match[3], topicId: Number(match[4]), topicTitle: V2exService.cleanHtml(match[5]) });
      match = pattern.exec(html);
    }
    return result;
  }

  static async myNodes(): Promise<V2exNode[]> {
    const html: string = await V2exService.get('/my/nodes', true);
    if (html.indexOf('/signin') >= 0 && html.indexOf('my-nodes') < 0) throw new Error('请先登录');
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
    return result;
  }

  static async topic(id: number): Promise<V2exTopic> {
    const data: V2exTopic[] = JSON.parse(await V2exService.get(`/api/topics/show.json?id=${id}`)) as V2exTopic[];
    if (data.length > 0) return data[0];
    // The public JSON detail endpoint may return [] when the server applies
    // its anonymous rate limit. Fall back to the same HTML detail page used
    // by the reference client so a topic never opens as a blank screen.
    const html: string = await V2exService.get(`/t/${id}`);
    const titleMatch: RegExpMatchArray | null = html.match(/<title>([\s\S]*?)\s+-\s+V2EX<\/title>/i);
    const bodyMatch: RegExpMatchArray | null = html.match(/class=["'][^"']*topic_content[^"']*["'][^>]*>([\s\S]*?)<\/div>/i);
    if (!titleMatch) throw new Error('主题不存在');
    return { id, title: V2exService.cleanHtml(titleMatch[1]), content: V2exService.cleanHtml(bodyMatch?.[1] ?? ''), replies: 0, last_modified: 0, last_touched: 0 };
  }

  static async replies(id: number): Promise<V2exReply[]> {
    const data: V2exReply[] = JSON.parse(await V2exService.get(`/api/replies/show.json?topic_id=${id}&page_size=100`)) as V2exReply[];
    if (data.length > 0) return data;
    const html: string = await V2exService.get(`/t/${id}`);
    const result: V2exReply[] = [];
    const pattern: RegExp = /id=["']r_(\d+)["'][\s\S]*?<img[^>]+src=["']([^"']+)["'][^>]*alt=["']([^"']+)["'][\s\S]*?<div class=["']reply_content["']>([\s\S]*?)<\/div>/gi;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      result.push({ id: Number(match[1]), content: V2exService.cleanHtml(match[4]), created: 0, member: { username: match[3], avatar_large: match[2] } });
      match = pattern.exec(html);
    }
    return result;
  }

  static async reply(topicId: number, content: string): Promise<boolean> {
    const html: string = await V2exService.get(`/t/${topicId}`);
    const onceMatch: RegExpMatchArray | null = html.match(/(?:name|value)=["']once["'][^>]*value=["']([^"']+)["']/i) || html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i);
    if (!onceMatch) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${API_BASE}/t/${topicId}`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/x-www-form-urlencoded', 'Cookie': V2exService.cookie(), 'Referer': `${API_BASE}/t/${topicId}` },
        extraData: `content=${V2exService.formValue(content)}&once=${V2exService.formValue(onceMatch[1])}`,
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      return response.responseCode >= 200 && response.responseCode < 400;
    } finally { request.destroy(); }
  }

  static async writeTopic(title: string, content: string, nodeName: string): Promise<boolean> {
    const html: string = await V2exService.get('/write');
    const onceMatch: RegExpMatchArray | null = html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i);
    if (!onceMatch) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${API_BASE}/write`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/x-www-form-urlencoded', 'Cookie': V2exService.cookie(), 'Referer': `${API_BASE}/write` },
        extraData: `title=${V2exService.formValue(title)}&content=${V2exService.formValue(content)}&node_name=${V2exService.formValue(nodeName)}&syntax=default&once=${V2exService.formValue(onceMatch[1])}`,
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      return response.responseCode >= 200 && response.responseCode < 400;
    } finally { request.destroy(); }
  }

  static async topicAction(id: number, action: 'favorite' | 'unfavorite' | 'thank' | 'up' | 'down'): Promise<boolean> {
    const html: string = await V2exService.get(`/t/${id}`);
    const onceMatch: RegExpMatchArray | null = html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i);
    if (!onceMatch) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const method: http.RequestMethod = action === 'thank' || action === 'up' || action === 'down' ? http.RequestMethod.POST : http.RequestMethod.GET;
      const response: http.HttpResponse = await request.request(`${API_BASE}/${action}/topic/${id}?once=${V2exService.formValue(onceMatch[1])}`, {
        method,
        header: { 'Cookie': V2exService.cookie(), 'Referer': `${API_BASE}/t/${id}` },
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      return response.responseCode >= 200 && response.responseCode < 400;
    } finally { request.destroy(); }
  }

  static async memberAction(username: string, action: 'follow' | 'unfollow'): Promise<boolean> {
    const html: string = await V2exService.get(`/member/${encodeURIComponent(username)}`);
    const onceMatch: RegExpMatchArray | null = html.match(/name=["']once["'][^>]*value=["']([^"']+)["']/i);
    if (!onceMatch) return false;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${API_BASE}/${action}/member/${encodeURIComponent(username)}?once=${V2exService.formValue(onceMatch[1])}`, {
        method: http.RequestMethod.GET,
        header: { 'Cookie': V2exService.cookie(), 'Referer': `${API_BASE}/member/${username}` },
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      return response.responseCode >= 200 && response.responseCode < 400;
    } finally { request.destroy(); }
  }
}
