# 公库任务脱敏检查清单（能跑 / 不能跑）

每条都给了理由与替代位置。判定原则：**能在陌生人 fork 后原样跑、且不接触任何凭据与私有路径**，才进公开仓库。

## 能跑（公开仓库）

| # | 任务 | 理由 | 落点 |
|---|---|---|---|
| 1 | 拉公共开源 release 的 Windows x64 资产，用 API `digest` 校验 sha256 | 只读公共 CDN，无凭据，输出是公开哈希 | `tools-mirror.yml` |
| 2 | 生成 `manifest.tsv` 并以 artifact 交付（14 天） | artifact 只含公开文件的哈希，不含路径/凭据 | `tools-mirror.yml` |
| 3 | 静态站可达性巡检（HTTP 状态 + 耗时） | 只 GET 一个公开 URL | `site-check.yml` |
| 4 | 秘密扫描（工作树 + 全历史 + 植入样本自检） | 只读本仓库内容，回显已 `<redacted>` | `secret-guard.yml` |
| 5 | Markdown/HTML 链接检查、拼写检查、格式 lint | 无网络副作用或仅 GET 公开链接 | 可新增 |
| 6 | 纯前端构建（静态站点打包）与 Pages 部署 | 产物是公开 HTML，唯一写入是本仓库 Pages | `pages.yml` |
| 7 | 单元测试/静态分析（Rust/Go/JS 无凭据项目） | 不需要任何 secret | 可新增 |
| 8 | 定时（每日/每周）低频率巡检 | 频率可控，单次 < 2 min | 各巡检 workflow |
| 9 | 跨仓库复用同一守卫脚本（`workflow_call` / 二次 checkout） | 被复用脚本本身已过守卫，取的是公开文件 | `blog/.github/workflows/guard.yml` |

## 不能跑（公开仓库）

| # | 任务 | 理由 | 替代 |
|---|---|---|---|
| 1 | 任何携带 token / API key / cookie 的调用 | 公开仓库的 `secrets` 会被所有 fork 触发面看见，且一旦误打印即永久留在公开日志 | 私库 `dsh-cloud`，或本机执行 |
| 2 | 读写私库 `dsh-cloud` 的 manifest / release | 会在公开日志里留下私库名与内部结构 | 私库内部 workflow |
| 3 | 需要 `contents: write` / `packages: write` 的步骤 | 公开仓库写权限等于把写入口暴露给 fork PR 的攻击面 | 私库 |
| 4 | 用 `secrets.GITHUB_TOKEN` 之外的 PAT | PAT 泄露即账号级风险 | 私库 secret 或本机 |
| 5 | 代理节点/订阅探测、出口 IP 探测、翻墙链路测试 | 直接触碰「公库绝不放代理节点」死命令 | 本机，不入任何仓库 |
| 6 | 对外部第三方站点做扫描/爆破/漏洞探测 | 违规任务，且会以我的账号作为发起方 | 不做 |
| 7 | 分钟级 cron、无界循环、重复 dispatch 刷额度 | 违反额度红线；公开仓库不限时长也不等于可滥用 | 拒绝 |
| 8 | 打印 `env` / 全部 `secrets` 上下文 / 家目录结构 | 输出即泄露 | 只打印白名单字段 |
| 9 | 处理含真实姓名、私人邮箱、手机号、住址的数据 | 违反「公库无隐私」死命令 | 私库或本机 |
| 10 | 上传含本机绝对路径、主机名、内网 IP 的 artifact | artifact 是公开可下载的 | 先脱敏或改私库 |
| 11 | 在公开仓库里跑 `self-hosted` runner | 会把内网机器暴露给公开 workflow | 禁止 |
| 12 | 任何「把私有产物推到公开 release/Pages」的动作 | 误发即不可逆（含历史与缓存） | 私库 release |

## 判定流程（新增 workflow 时照抄）

1. 先跑 `bash guard/scan-secrets.sh --worktree`（本地）。
2. 过一遍上表；命中任何「不能跑」→ 改写或换仓库。
3. 推上去后看 `secret-guard` 是否 `RESULT=CLEAN`；不是就回滚。
4. 记一行额度：单次耗时 × 触发次数/月，写进 commit message 或 PR 描述。
