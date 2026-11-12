# 仓库用途划分与判定规则

本文件是公开侧（`dsh-build-lab`、`blog`）与私密侧（`dsh-cloud`）的**唯一判定依据**。
判定顺序：先看「内容类型」，再看「是否可逆」，最后看「额度归属」。三关任一不过，一律留在私密仓库。

## 1. 三类仓库

| 仓库 | 可见性 | 额度 | 定位 |
|---|---|---|---|
| `dsh-build-lab` | public | 公开仓库 Actions 免费不限时长 | 脱敏后公开的构建/校验/镜像/巡检流水线；任何人 fork 都能跑 |
| `blog` | public | 公开仓库 Actions 免费不限时长 | 纯静态站（Pages），只放文字与 HTML |
| `dsh-cloud` | private | 2,000 分钟/月（免费额度） | 需要凭据、私密路径、私有清单、唯一真相（manifest）的一切 |

## 2. 只能进私密仓库的内容（公开侧一律禁止）

1. 任何凭据：token、API key、cookie、私钥、`.env`、`credentials`、`.netrc`、`id_rsa*`。
2. 任何代理/隧道材料：节点地址、订阅链接、协议链接、端口与出口信息。
3. 任何身份信息：真实姓名、私人邮箱域名、手机号、住址、公司名、证件号。
4. 任何本机指纹：主机名、用户名、本机绝对路径（Windows 盘符路径、Unix 家目录路径）、内网 IP、私库名。
5. 任何「跑起来会调用我的账号」的东西：带 `GH_TOKEN` 但作用域超出 `contents:read` 的步骤、私库 release 上传、私有 runner。
6. 任何「输出泄漏路径」的东西：把 `env`/`secrets` 直接打印、把 checkout 目录结构上传成 artifact。

## 3. 可以进公开仓库的内容（判定通过后）

- 纯静态文本、HTML/CSS/JS、无凭据的脚本。
- 只用 `GITHUB_TOKEN` 且 `permissions: contents: read` 的校验类 workflow。
- 从**公共开源项目**发布的 release 取资产、校验 `digest`、打包成 artifact 的镜像流水线（不写回任何私有位置）。
- 站点可达性巡检、链接检查、格式检查、lint、单元测试。

## 4. 判定问答（每次新增 workflow 前逐条过）

1. 这条 workflow 里有没有硬编码凭据？→ 有 = 私密。
2. 它会不会把 `secrets.*` 透出到日志/artifact？→ 会 = 不做，改成脱敏输出。
3. 它引用的是私库路径/私库清单/私库 release？→ 是 = 私密。
4. 它是否需要写权限（`contents: write`、`packages: write`、`actions: write`）？→ 需要 = 私密。
5. 它是否可由任何陌生人 fork 后原样运行且不产生副作用？→ 否 = 私密。
6. 它的输出里是否可能出现主机名、用户名、家目录、节点地址？→ 可能 = 加过滤或改私密。
7. 它是否高频触发（分钟级 cron、无界循环、重复 dispatch）？→ 是 = 拒绝，不因仓库可见性而放宽。

全部答「否/不需要」→ 可进公开仓库；任一命中 → 进私密仓库或不做。

## 5. 共享守卫

公开仓库的 push/PR/每日定时都会跑 `guard/scan-secrets.sh`（本仓库）或跨库调用同一脚本（`blog`）。
守卫命中即 `RESULT=VIOLATION` 且 workflow 失败，等于**合并被物理阻断**，不依赖人工 review。
规则表见 `guard/scan-secrets.sh`，命中回显一律 `<redacted>`。
