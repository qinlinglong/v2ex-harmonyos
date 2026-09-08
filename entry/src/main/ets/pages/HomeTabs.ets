import { router } from '@kit.ArkUI';

interface HomeTabOption {
  title: string;
  key: string;
  type: string;
}

const ALL_HOME_TABS: HomeTabOption[] = [
  { title: '最近', key: 'latest', type: 'latest' },
  { title: '最热', key: 'hot', type: 'hot' },
  { title: '技术', key: 'tech', type: 'tab' },
  { title: '创意', key: 'creative', type: 'tab' },
  { title: '好玩', key: 'play', type: 'tab' },
  { title: 'Apple', key: 'apple', type: 'tab' },
  { title: '酷工作', key: 'jobs', type: 'tab' },
  { title: '交易', key: 'deals', type: 'tab' },
  { title: '城市', key: 'city', type: 'tab' },
  { title: '问与答', key: 'qna', type: 'tab' },
  { title: '全部', key: 'all', type: 'tab' },
  { title: 'R2', key: 'r2', type: 'tab' },
  { title: 'VXNA', key: 'xna', type: 'xna' },
  { title: '节点', key: 'nodes', type: 'nodes' },
  { title: '关注', key: 'members', type: 'node' },
  { title: '刚更新', key: 'changes', type: 'tab' }
];

const DEFAULT_HOME_TABS: HomeTabOption[] = [
  ALL_HOME_TABS[0], ALL_HOME_TABS[1], ALL_HOME_TABS[2], ALL_HOME_TABS[3],
  ALL_HOME_TABS[4], ALL_HOME_TABS[5], ALL_HOME_TABS[6], ALL_HOME_TABS[7],
  ALL_HOME_TABS[8], ALL_HOME_TABS[9], ALL_HOME_TABS[10], ALL_HOME_TABS[11],
  ALL_HOME_TABS[12], ALL_HOME_TABS[13], ALL_HOME_TABS[14]
];

@Entry
@Component
struct HomeTabs {
  @StorageLink('v2exTheme') themeColor: string = '#4F7CAC';
  @StorageLink('v2exHomeTabs') tabsJson: string = JSON.stringify(DEFAULT_HOME_TABS);
  @State selected: HomeTabOption[] = [];
  @State editing: boolean = false;

  aboutToAppear(): void { this.readTabs(); }

  private readTabs(): void {
    try {
      const parsed: HomeTabOption[] = JSON.parse(this.tabsJson) as HomeTabOption[];
      this.selected = parsed.filter((item: HomeTabOption) => item && item.key && item.title);
    } catch (_) { this.selected = DEFAULT_HOME_TABS.slice(); }
    if (this.selected.length === 0) this.selected = DEFAULT_HOME_TABS.slice();
  }

  private save(): void {
    if (this.selected.length === 0) return;
    this.tabsJson = JSON.stringify(this.selected);
  }

  private contains(key: string): boolean { return this.selected.some((item: HomeTabOption) => item.key === key); }

  private toggle(item: HomeTabOption): void {
    if (this.contains(item.key)) {
      if (this.selected.length <= 1) return;
      this.selected = this.selected.filter((entry: HomeTabOption) => entry.key !== item.key);
    } else {
      this.selected = [...this.selected, item];
    }
    this.save();
  }

  private move(index: number, delta: number): void {
    const next: number = index + delta;
    if (next < 0 || next >= this.selected.length) return;
    const items: HomeTabOption[] = this.selected.slice();
    const current: HomeTabOption = items[index];
    items[index] = items[next];
    items[next] = current;
    this.selected = items;
    this.save();
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(34).fontColor(this.themeColor).width(42).textAlign(TextAlign.Center)
          .onClick(() => router.back())
        Text('首页板块').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#202124')
        Blank()
        Text(this.editing ? '完成' : '编辑').fontSize(15).fontColor(this.themeColor)
          .onClick(() => this.editing = !this.editing)
      }.height(60).width('100%').padding({ left: 8, right: 16 }).backgroundColor(Color.White)
      Scroll() {
        Column() {
          Text(this.editing ? '点击板块可添加或移除，使用箭头调整顺序' : '点击板块进入对应内容')
            .fontSize(13).fontColor('#8A97A6').width('100%').margin({ bottom: 12 })
          ForEach(ALL_HOME_TABS, (item: HomeTabOption) => {
            Row() {
              Text(item.title).fontSize(16).fontColor(this.contains(item.key) ? '#202124' : '#9AA3AD').layoutWeight(1)
              if (this.editing && this.contains(item.key)) {
                Button('↑').fontSize(12).width(42).height(32).margin({ right: 6 })
                  .onClick(() => this.move(this.selected.findIndex((entry: HomeTabOption) => entry.key === item.key), -1))
                Button('↓').fontSize(12).width(42).height(32).margin({ right: 6 })
                  .onClick(() => this.move(this.selected.findIndex((entry: HomeTabOption) => entry.key === item.key), 1))
              }
              Button(this.contains(item.key) ? (this.editing ? '移除' : '已添加') : '添加').fontSize(12).enabled(this.editing)
                .onClick(() => this.toggle(item))
            }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor(Color.White).margin({ bottom: 1 })
          }, (item: HomeTabOption) => item.key)
          Text('至少保留一个首页板块。设置会保存在本机。').fontSize(12).fontColor('#8A97A6').margin({ top: 16 })
        }.width('100%').padding(16)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding({ top: AppStorage.get<number>('v2exSafeAreaTop') ?? 0, bottom: AppStorage.get<number>('v2exSafeAreaBottom') ?? 0 }).backgroundColor('#F5F7FA')
  }
}
