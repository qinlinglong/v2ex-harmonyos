# V2EX HarmonyOS

V2EX 的 HarmonyOS 原生客户端项目，使用 ArkTS、ArkUI 和 DevEco CLI 构建。

## 当前状态

当前为可运行的原生首页基础版本，包含首页、最新、节点、我的导航，以及主题列表和刷新状态展示。网络接口、登录、主题详情和评论功能将在后续迭代中接入。

## 构建

需要 HarmonyOS API 24+ SDK 和 `devecocli`：

```bash
devecocli build --modules entry@default --product default --build-mode debug
```

构建产物位于 `entry/build/default/outputs/default/`。

## 项目标识

- Bundle：`io.github.qinlinglong.v2ex`
- 初始版本：`1.0.0`
- 项目目录：`code/v2ex-harmonyos`
