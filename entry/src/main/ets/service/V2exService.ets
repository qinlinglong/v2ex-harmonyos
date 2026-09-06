import { http } from '@kit.NetworkKit';
import { V2exReply, V2exTopic } from '../model/V2exModels';

const API_BASE: string = 'https://www.v2ex.com';

export class V2exService {
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
    const clean = (value: string): string => value.replace(/<br\s*\/?>(\r?\n)?/gi, '\n')
      .replace(/<[^>]+>/g, '').replace(/&nbsp;/gi, ' ').replace(/&amp;/gi, '&')
      .replace(/&lt;/gi, '<').replace(/&gt;/gi, '>').trim();
    return { id, title: clean(titleMatch[1]), content: clean(bodyMatch?.[1] ?? ''), replies: 0, last_modified: 0, last_touched: 0 };
  }

  static async replies(id: number): Promise<V2exReply[]> {
    const data: V2exReply[] = JSON.parse(await V2exService.get(`/api/replies/show.json?topic_id=${id}&page_size=100`)) as V2exReply[];
    return data ?? [];
  }
}
