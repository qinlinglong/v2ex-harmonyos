# V2EX HarmonyOS

V2EX 的 HarmonyOS 原生客户端项目，使用 ArkTS、ArkUI 和 DevEco CLI 构建。

## 当前状态

当前为原生 ArkUI 客户端首个可运行版本，参考 `liaoliao666/v2ex` 的首页、最新、节点、我的信息架构，已接入 V2EX 公开 API，支持主题列表刷新、节点/作者元数据和主题详情/回复展示。

## 构建

需要 HarmonyOS API 24+ SDK 和 `devecocli`：

```bash
devecocli build --modules entry@default --product default --build-mode debug
```

构建产物位于 `entry/build/default/outputs/default/`。

## 项目标识

- Bundle：`qinlinglong.github.io`
- 初始版本：`1.0.0`
- 项目目录：`code/v2ex-harmonyos`
