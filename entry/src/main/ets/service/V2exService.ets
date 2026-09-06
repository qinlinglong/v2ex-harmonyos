import { http } from '@kit.NetworkKit';
import { webview } from '@kit.ArkWeb';
import { V2exNode, V2exReply, V2exTopic } from '../model/V2exModels';

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
  private static async get(path: string): Promise<string> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${API_BASE}${path}`, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json',
          'User-Agent': 'V2EX-HarmonyOS/1.0'
        },
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
    const path: string = kind === 'hot' ? '/api/topics/hot.json' : '/api/topics/latest.json';
    const parsed: V2exTopic[] = JSON.parse(await V2exService.get(path)) as V2exTopic[];
    parsed.forEach((item: V2exTopic) => {
      if (item.replies === undefined) item.replies = 0;
      if (item.content === undefined) item.content = '';
    });
    return parsed;
  }

  static async nodes(): Promise<V2exNode[]> {
    const data: V2exNode[] = JSON.parse(await V2exService.get('/api/nodes/all.json')) as V2exNode[];
    return data ?? [];
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
    const pattern: RegExp = /id=["']r_(\d+)["'][\s\S]*?<a href=["']\/member\/([^"']+)["'][^>]*>[\s\S]*?<\/a>[\s\S]*?<div class=["']reply_content["']>([\s\S]*?)<\/div>/gi;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      result.push({ id: Number(match[1]), content: V2exService.cleanHtml(match[3]), created: 0, member: { username: match[2] } });
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
}
