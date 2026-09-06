# V2EX HarmonyOS

V2EX 的 HarmonyOS 原生客户端项目，使用 ArkTS、ArkUI 和 DevEco CLI 构建。

## 当前状态

当前为原生 ArkUI 客户端首个可运行版本，参考 `liaoliao666/v2ex` 的首页、最新、节点、我的信息架构，已接入 V2EX 公开 API。

已实现的原生流程包括：首页/最新主题、下拉刷新、横向 Tab 切换、节点列表及节点主题、主题搜索、主题详情与 Markdown 图片、回复、收藏/感谢/点赞、作者资料（主题/回复 Tab）、关注、登录 WebView、发布主题、通知/我的主题/我的节点/收藏入口和主题颜色设置。

## 构建

需要 HarmonyOS API 24+ SDK 和 `devecocli`：

```bash
devecocli build --modules entry@default --product default --build-mode debug
```

构建产物位于 `entry/build/default/outputs/default/`。

连接真机后可使用：

```bash
devecocli signature generate --product default
devecocli build --modules entry@default --product default --build-mode debug
devecocli run --module entry@default --device <device-serial> --product default --build-mode debug --skip-build
```

`signature generate` 会写入本机签名配置，仅用于本地安装测试；不要将生成的证书、私钥或签名密码提交到仓库。

## 项目标识

- Bundle：`qinlinglong.github.io`
- 初始版本：`1.0.0`
- 项目目录：`code/v2ex-harmonyos`
