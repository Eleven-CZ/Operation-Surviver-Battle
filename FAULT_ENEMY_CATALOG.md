# iT-BATTLE 故障敌人图鉴与像素标签规范

> 版本：v0.1  
> 日期：2026-07-19  
> 状态：官方术语调研完成；用于 M1 Golden Sample 与后续敌人生产  
> 说明：下文“普通 / 精英 / Boss”是游戏分级，不是协议或厂商定义的严重度

## 0. 核心决定

故障码不是悬浮在怪物头上的说明文字，而是敌人的身份、身体结构与行为规则。

每一种故障敌人必须同时拥有三层识别：

1. **代码层**：`404`、`502`、`ENOSPC`、`40P01`、`XID 79` 等短像素标签。
2. **轮廓层**：缺页、双头网关、膨胀硬盘、互锁事务、脱落 GPU 等独立剪影。
3. **行为层**：消失、限流、阻塞、循环重启、占地、断链、复制退化等可预测机制。

最终运行时标签由 Godot 的位图字体和图标层绘制，不把 GPT Image 2 生成的文字直接作为正式 UI。GPT Image 2 负责怪物母版、标签牌造型和概念样张；准确拼写、字号、语言切换、描边和闪烁状态由引擎保证。

## 1. 先把不同类型的“错误词”分清

| 类型 | 例子 | 游戏中的使用方式 |
|---|---|---|
| 标准协议状态 | `404`、`429`、`502`、`NXDOMAIN`、TLS `certificate_expired` | 可直接作为跨产品的故障本体 |
| 系统符号与信号 | `EIO`、`ENOSPC`、`ECONNREFUSED`、`SIGSEGV` | 作为 Linux / 主机故障家族的额头或胸口铭牌 |
| 产品或平台状态 | `CrashLoopBackOff`、`PG_DEGRADED`、`CLUSTERDOWN`、`XID 79` | 使用产品族外观与短标签；长名称只给精英或 Boss |
| 日志严重度 | `WARN`、`ERROR`、`FATAL`、NGINX `crit / alert / emerg` | 作为精英冠标、阶段升级或 Boss 危险等级，不单独冒充根因 |
| 游戏合成事故 | `INCIDENT CORE`、`ISR COLLAPSE`、`REPLICA LAG` | 用于把多个真实故障组织成一场事故；图鉴注明它是归一化名称 |

`502 / 503 / 504` 是标准 HTTP 状态，并非 NGINX 专属。NGINX `error_log` 的官方等级为 `debug / info / notice / warn / error / crit / alert / emerg`，没有 `fatal`。因此：

- 通用 Boss 可以使用 `FATAL` 作为应用日志严重度冠标；Apache Log4j 将其列为预定义日志级别之一：[Log4j Levels](https://logging.apache.org/log4j/2.x/manual/customloglevels.html)。
- NGINX 怪应写成 `nginx [error] UPSTREAM TIMEOUT`、`nginx [crit] INVALID HEADER` 或 `nginx [emerg] CONFIG ERROR`，不写 `nginx [fatal]`：[NGINX error_log](https://nginx.org/en/docs/ngx_core_module.html#error_log)。
- 概念样张可以出现 `NGINX ERROR` 作为一眼能懂的主题牌，但正式资产应换成真实的代码与原因组合。

## 2. 像素标签与体型规则

### 2.1 三档层级

| 层级 | 体型 | 主标签 | 副标签 | 必须具备的视觉差异 |
|---|---:|---|---|---|
| 普通怪 | 玩家 0.35—0.60 倍 | 3—7 字符，如 `404`、`EIO`、`NXDOM` | 无或仅图标 | 24—32px 有效轮廓；标签嵌入脸、胸口或背壳 |
| 精英 | 普通怪 1.8—2.5 倍 | 标准码或短状态，如 `502`、`137`、`40P01` | 最多 12 字符，如 `UPSTREAM`、`OOMKILLED` | 独立肢体、光环、地面预警和进场动作 |
| Boss | 玩家 4—7 倍 | `FATAL`、`NO QUORUM`、`XID 79` 等阶段牌 | 子系统与根因条 | 多部位、阶段变形、占据明显屏幕面积 |

### 2.2 标签应该长在怪物身上

- HTTP：断裂网页、网关门、Header 横条、状态码 LED 面板。
- DNS：缺失域名铭牌、解析器球体、权威王冠、签名印章。
- TLS / 安全：证书卷、锁链、断开的握手、过期沙漏。
- Linux：终端黑块、`errno` 胸牌、内存页、磁盘磁头、文件描述符扇面。
- Kubernetes：Pod 方块、循环箭头、拉取链、节点心跳、驱逐弹杆。
- 数据库：圆柱、锁链、WAL / binlog 卷轴、连接插排、复制三角。
- 缓存 / 消息队列：Key 方块、Slot 扇区、日志卷、Partition 王冠、Offset 刻度。
- AI Infra：GPU 散热片、显存格、NVLink 桥、PCIe 王座、Xid 七段数码牌。

移动器官遵循一条硬规则：普通故障体默认无腿。缺页、状态码、DNS 球、磁盘、Pod、证书、连接和日志等通过漂浮、滑行、滚动、脉冲跳跃或数据位移移动；只有命名与轮廓明确表达 `BUG / 虫群 / 爬虫` 隐喻的敌人可以长腿。精英或 Boss 若需要机械支撑结构，必须服务于其独特轮廓，不能让所有故障都变成小机器人。

### 2.3 可读性约束

- 战斗内只保证一个主标签清楚；完整英文说明放在图鉴、暂停页或精英入场条。
- 标签使用项目自制 8×8 或 8×12 单色位图字体，最细笔画不得小于 1 个运行时像素。
- 普通怪不烘焙长词。`CrashLoopBackOff` 在场上显示为 `CRASHLOOP`，图鉴保留全称。
- 精英标签先显示代码，再显示原因：`502` 大、`UPSTREAM` 小；不能反过来。
- `FATAL` 是红色严重度冠标，不取代根因；Boss 同时还要显示 `XID 79`、`NO QUORUM` 或 `KERNEL PANIC`。
- 颜色不能是唯一通道；灰度画面中仍须靠轮廓、体积、运动和预警形状区分。
- 避免满屏文字噪声：同屏重复小怪只让距离玩家最近的 20—30% 显示标签，其余保留代码图标或身体刻字。

## 3. 官方故障词汇与敌人设计

### 3.1 HTTP / 网关 / NGINX

HTTP 语义依据 [RFC 9110 状态码章节](https://www.rfc-editor.org/rfc/rfc9110.html#section-15)；`429 / 431 / 511` 依据 [RFC 6585](https://www.rfc-editor.org/rfc/rfc6585.html)。

| 标签 | 真实含义 | 分级 | 轮廓与行为 |
|---|---|---:|---|
| `400` | 请求语法、消息分帧或路由有问题 | 普通 | 字段错位的请求纸片；折线移动 |
| `401` | 缺少有效认证凭据 | 精英 | 钥匙孔面罩；周期吸走玩家凭据 Buff |
| `403` | 服务器理解请求但拒绝执行 | 精英 | 横向巨盾；正面减伤、侧后方脆弱 |
| `404` | 找不到资源或不愿透露其存在 | 普通 | 中空缺页幽灵；短距离消隐与闪现 |
| `408` | 等待期间未收到完整请求 | 普通 | 无腿漂浮沙漏；蓄力超时后留下减速圈 |
| `409` | 请求与资源当前状态冲突 | 精英 | 两个镜像身体互相穿插；同步受击才解除护盾 |
| `413` | 请求内容过大 | 精英 | 膨胀数据包；缓慢冲撞并挤开小怪 |
| `429` | 一段时间内请求过多，即限流 | 精英 / 群怪队长 | 令牌桶蜈蚣；为附近小怪施加突发冲锋与冷却 |
| `431` | 请求头字段过大 | 精英 | 头顶堆叠 Header 横条；扩大自身碰撞宽度 |
| `500` | 服务器遇到意外情况，无法完成请求 | 精英 | 裂开的服务器核心；随机切换攻击模式 |
| `502` | 网关或代理从上游收到无效响应 | Boss / 大精英 | 双头断裂网关；一头收请求、一头吐乱码；切断上游线后破防 |
| `503` | 临时过载或维护导致无法处理 | Boss / 大精英 | 过热机柜坦克；召唤排队小怪并进入维护护盾 |
| `504` | 网关或代理未及时收到上游响应 | Boss | 巨型钟盘网关；延迟玩家技能与投射物 |
| `507` | WebDAV 操作因存储不足无法保存状态 | 精英 | 塞满文件的磁盘坦克；占据地面写入区 |
| `508` | WebDAV 操作检测到无限循环 | Boss | 首尾相咬的网线蛇；环绕并复制路线 |
| `511` | 客户端需先认证才能获得网络访问 | 精英 | Wi-Fi 登录笼；封锁地图出口直到完成交互 |

NGINX 上游状态依据 [proxy_next_upstream](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream) 与 [upstream server](https://nginx.org/en/docs/http/ngx_http_upstream_module.html#server)：

| 标签 | 分级 | 轮廓与行为 |
|---|---:|---|
| `UPSTREAM ERROR` | 普通 / 精英 | 三段管线中随机一段爆裂；被关闭后暴露真正上游怪 |
| `UPSTREAM TIMEOUT` | 精英 | 长颈时钟连接小型上游塔；持续拖慢周围单位 |
| `INVALID HEADER` | 精英 | 多层 Header 舌头错位；制造假预警条 |
| `CONN REFUSED` | 普通 / 精英 | 端口门把 SYN 小怪弹回；锥形击退 |
| `UPSTREAM DOWN` | 精英 / Boss 部件 | 熄灭机柜；作为 503 的可破坏肢体 |

### 3.2 DNS / TLS

DNS RCODE 依据 [IANA DNS Parameters](https://www.iana.org/assignments/dns-parameters/dns-parameters.xhtml)，扩展诊断依据 [RFC 8914](https://www.rfc-editor.org/rfc/rfc8914.html)，TLS alert 依据 [RFC 8446 §6.2](https://www.rfc-editor.org/rfc/rfc8446.html#section-6.2)。

| 标签 | 真实含义 | 分级 | 轮廓与行为 |
|---|---|---:|---|
| `FORMERR` | DNS 消息格式错误 | 普通 | 点号错位的域名符文；不规则折返 |
| `NXDOMAIN` | 查询的域名不存在 | 普通 | 空心地球与缺名牌；闪现到空网格 |
| `SERVFAIL` | DNS 服务器失败，单凭该码不能确定原因 | 精英 | 裂开的解析器球；制造多个假地址 |
| `REFUSED` | DNS 服务器拒绝处理查询 | 精英 | 域名拒绝盾；反弹一次工具攻击 |
| `DNSSEC BOGUS` | DNSSEC 验证处于 Bogus 状态 | Boss | 多层伪签名王冠；先拆假印章再打核心 |
| `SIG EXPIRED` | 当前没有有效签名，且签名已过期 | 精英 | 沙漏穿过签名印章；周期失效爆发 |
| `NO AUTHORITY` | 无法联系任何权威服务器或未获回复 | Boss | 无头王冠连接数座熄灭 DNS 塔 |
| `HANDSHAKE FAIL` | 无法协商双方接受的安全参数 | Boss | 两只握不到一起的巨手；中间断裂电弧 |
| `BAD CERT` | 证书损坏或签名无法正确验证等 | 精英 | 撕裂水晶证书；投射错误印章 |
| `CERT EXPIRED` | 证书不在有效期 | 精英 | 证书骑士与大沙漏；倒计时结束后狂暴 |
| `UNKNOWN CA` | 找不到可信 CA 或信任锚 | 精英 | 没有底座的锁链；召唤问号证书 |
| `DECRYPT ERROR` | 握手密码学验证失败 | 精英 / Boss | 黑色密文核，折断钥匙作为弱点 |

### 3.3 Linux / 主机 / 网络

`errno` 语义依据 Linux man-pages 的 [errno(3)](https://man7.org/linux/man-pages/man3/errno.3.html)，进程与信号依据 [signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html)。

| 标签 | 真实含义 | 分级 | 轮廓与行为 |
|---|---|---:|---|
| `ENOEXEC` | 可执行文件格式无法识别或架构不匹配 | 普通 | 插反 CPU 与撕裂 `#!` 纸条；动作卡帧 |
| `EMFILE` | 单进程达到打开文件描述符上限 | 普通 | 文件页扇面；不断展开并增加碰撞宽度 |
| `EROFS` | 对只读文件系统执行写入 | 普通 | 挂锁磁盘甲壳与折断铅笔；正面硬壳 |
| `ECONNREFUSED` | 连接被目标拒绝 | 普通 | 合拢端口钳；把投射物弹回一次 |
| `ECONNRESET` | 连接被对端重置 | 普通 | 突然断裂的网线鞭；打断蓄力 |
| `ETIMEDOUT` | 连接或操作超时 | 普通 | 无腿漂浮计时器；移动时留下延迟带 |
| `ENETUNREACH` | 网络不可达 | 普通 / 精英 | 断路路牌；临时改变敌群寻路流向 |
| `ENOSPC` | 设备没有剩余空间 | 精英 | 过度膨胀硬盘与 `100%` 腰带；扩张占地区 |
| `EIO` | 输入 / 输出操作失败 | 精英 | 破裂盘片与超长磁头；扇形电弧攻击 |
| `SIGSEGV` | 非法内存访问，默认终止进程并产生 core dump | 精英 | 错位内存页与 `0x????` 黑洞；断层闪现 |
| `HOST OOM` | 内存耗尽后由 OOM killer 选择任务回收内存 | 精英 | RAM 镰刀收割者；随机标记附近一个单位 |
| `SERVICE FAILED` | systemd unit 进入 failed 状态 | 精英 | 断裂启动拉杆的服务塔；召唤重启小怪 |
| `KERNEL PANIC` | 内核遇到不可恢复错误 | Boss | 终端巨像、堆栈肋骨、冻结光标；阶段性停转全场 |

### 3.4 Kubernetes / 容器

状态依据 Kubernetes 官方的 [Pod lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)、[Images](https://kubernetes.io/docs/concepts/containers/images/#imagepullbackoff)、[Node-pressure Eviction](https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/) 与 [Node Status](https://kubernetes.io/docs/reference/node/node-status/#conditions)。

| 标签 | 真实含义 | 分级 | 轮廓与行为 |
|---|---|---:|---|
| `PENDING` / `FAILED SCHED` | Pod 无法被调度到合适节点 | 普通 | Pod 方块被调度网格挡在门外；占据出生点 |
| `IMAGE PULL` | `ImagePullBackOff`，镜像拉取失败并递增延迟重试 | 普通 | 容器拖着卡死下载链；周期尝试拉取小箱子 |
| `OOM 137` | 容器超过内存限制后被 OOM 终止 | 精英 | 透明内存囊包住 Pod；爆裂后留下 `137` 核心 |
| `CRASHLOOP` | 容器反复启动、崩溃并指数退避 | 精英 | `START → CRASH → WAIT` 三段衔尾蛇；关闭后可重组 |
| `EVICTED` | 节点压力等原因触发 Pod 驱逐 | 精英 | 被弹出杆踢离节点的倾斜 Pod；冲撞位移 |
| `DISK PRESSURE` | 节点磁盘容量不足 | 精英 | 巨型液压盘压住一群 Pod；压缩安全区域 |
| `NODE NOTREADY` | 节点不健康、无法接收 Pod 或心跳丢失 | Boss | 倒塌服务器塔与断线心跳；携带多个 Pod 部件 |

### 3.5 数据库

PostgreSQL 状态依据 [SQLSTATE 错误码附录](https://www.postgresql.org/docs/current/errcodes-appendix.html)，MySQL 状态依据 [MySQL Server Error Reference](https://dev.mysql.com/doc/mysql-errors/8.4/en/server-error-reference.html)。

| 标签 | 真实含义 | 分级 | 轮廓与行为 |
|---|---|---:|---|
| `PG 25006 / RO` | 只读事务或只读节点拒绝写入 | 普通 | 数据库盾兵；背面是写入弱点 |
| `PG 40P01` | 检测到事务死锁 | 精英 | 两只数据库甲虫以交叉锁链互咬；需断链或同步关闭 |
| `PG 53300` | 数据库连接耗尽 | 精英 | 插满红色网线的宽圆柱；召唤连接小体 |
| `PG 53100` | 磁盘空间不足 | 精英 | `100%` 数据库桶；掉落磁盘障碍 |
| `PG REPLAY LAG` | Standby 的 WAL 写入、刷盘或回放落后 | 精英 | 主库拖着延迟副本与不断变长的 WAL 卷 |
| `PG 57P02 / 57P03` | 崩溃关闭后恢复，暂时不能连接 | Boss | 倾倒数据库塔沿 WAL 轨道两阶段重建 |
| `MYSQL 1205` | 锁等待超时 | 普通 | 背沙漏的锁头怪；超时后释放冲击波 |
| `MYSQL 1213` | InnoDB 检测到死锁 | 精英 | 双事务旋转结构；回滚其中一体后破防 |
| `MYSQL 1040` | 全局连接上限达到 | 精英 | 插满所有孔的巨型端口插排 |
| `MYSQL REPLICA LAG` | 副本接收或应用线程停止、进度落后 | 精英 | 双层复制列车与积压 binlog 方块 |
| `MYSQL NO QUORUM` | 集群失去多数派，无法继续写入 | Boss | 三头投票王；击破错误少数派恢复共识 |

### 3.6 Ceph / 存储

Ceph 状态依据官方 [Health Checks](https://docs.ceph.com/en/latest/rados/operations/health-checks/) 与 [Monitor Troubleshooting](https://docs.ceph.com/en/latest/rados/troubleshooting/troubleshooting-mon/)。

| 标签 | 真实含义 | 分级 | 轮廓与行为 |
|---|---|---:|---|
| `OSD NEARFULL` | OSD 超过 nearfull 阈值 | 普通 | 几乎闭合的容量扇区；逼近时继续膨胀 |
| `SLOW OPS` | OSD 或 Monitor 请求处理过慢 | 精英 | 多臂磁盘拖着不同长度沙漏；范围减速 |
| `OSD DOWN` | OSD daemon、主机或网络故障导致 OSD down | 精英 | 倾倒磁盘碑与断线心跳；为附近存储怪加压 |
| `PG DEGRADED` | 数据副本或纠删码片段不足 | 精英 | 三角复制晶体缺一角；补齐副本后破防 |
| `MON NETSPLIT` | Monitors 之间发生持续网络分区 | 精英 | 两座相背塔被裂谷分开；必须连接两侧攻击 |
| `OSD FULL` | OSD 超过 full 阈值，无法继续写入 | Boss | 完全闭合容量环的存储堡垒；文件块喷发 |
| `PG AVAILABILITY` | 部分 PG 无法处理读写请求 | Boss | 分片核心围绕 I/O 黑洞；多部位 Boss |
| `NO QUORUM` | 可用 Monitor 不足多数，无法形成 quorum | Boss | 三头或五头 Monitor 王冠，仅少数眼睛亮起 |
| `PG DAMAGED` | scrub 发现不一致或损坏 | Boss | 每一面校验值不同的数据晶核；逐面修复 |

### 3.7 Redis / Kafka

Redis 依据 [官方错误处理](https://redis.io/docs/latest/develop/clients/error-handling/) 与 [Cluster specification](https://redis.io/docs/latest/operate/oss_and_stack/reference/cluster-spec/)；Kafka 依据 [Kafka 4.1 协议错误码](https://kafka.apache.org/41/design/protocol/#protocol_error_codes)。

| 标签 | 真实含义 | 分级 | 轮廓与行为 |
|---|---|---:|---|
| `REDIS LOADING` | Redis 正把持久化数据载入内存 | 普通 | 半透明方块与上涨进度条；完成前减伤 |
| `REDIS READONLY` | 写请求发给默认只读的 Replica | 普通 | `RO` 盾与 Replica 头盔；反射写入型工具 |
| `CROSSSLOT` | 多 Key 不属于同一个 Hash Slot | 普通 | 两个不同 Slot 方块与撕裂链条；成对出现 |
| `MOVED / ASK` | Slot 长期转移或迁移期间临时转向 | 普通变体 | 固定或旋转路牌；重定向敌群路径 |
| `REDIS OOM` | 超过 maxmemory，写入被拒绝或触发淘汰 | 精英 | 塞满 Key 的膨胀内存块；吐出 `EVICT` 小怪 |
| `PFAIL → FAIL` | 单节点怀疑不可达，经多数确认后升级失败 | 两阶段精英 | 黄灯节点被投票线包围，过半后变红黑 |
| `CLUSTERDOWN` | Slot 或多数 Primary 可达性异常，集群失败 | Boss | 16 个 Slot 扇区组成的大圆盘与缺失黑洞 |
| `OFFSET OOR [1]` | Kafka Offset 不在当前保留范围 | 普通 | 指针滑出刻度末端的日志卷 |
| `NOT LEADER [6]` | Broker 不是当前请求所需 Leader / Replica | 普通 | 戴错王冠的小 Broker；王冠在单位间交换 |
| `TIMEOUT [7]` | Kafka 请求超时 | 普通 | 沙漏包裹网络包；留下断线区 |
| `MSG TOO LARGE [10]` | 消息超过 Broker 接受大小 | 精英 | 2.5 倍体积的巨型消息包；缓慢冲撞 |
| `REBALANCE [27]` | Consumer Group 正在重新分配分区 | 精英 | 多臂调度圆盘不断交换 Partition 小怪 |
| `NOT ENOUGH REPLICA [19/20]` | ISR 数量低于写入要求 | 精英 | 三联 Broker 只剩一颗核心发光 |
| `ISR COLLAPSE` | 游戏归一化的多分区复制事故 | Boss | 日志塔、熄灭 Leader 王冠与逐个脱落的 Replica 环 |

### 3.8 AI Infra / GPU

NVIDIA Xid 依据官方 [Xid Errors](https://docs.nvidia.com/deploy/xid-errors/latest/index.html) 与 [Xid Catalog](https://docs.nvidia.com/deploy/xid-errors/analyzing-xid-catalog.html)，NCCL 依据 [NCCL Troubleshooting](https://docs.nvidia.com/deeplearning/nccl/user-guide/docs/troubleshooting.html)。

| 标签 | 真实含义 | 分级 | 轮廓与行为 |
|---|---|---:|---|
| `CUDA OOM` | CUDA 无法分配足够显存或所需资源 | 精英 | GPU 卡槽塞满 Tensor 方块；爆裂显存区 |
| `NCCL SYSTEM ERROR` | NCCL 调用外部 CUDA 或系统组件失败 | 普通 | 通信包围绕 GPU 节点突进 |
| `NCCL MISMATCH` | Rank 的 collective 次数或参数不一致 | 精英 | 多头通信环中一头落后；拖慢整个环 |
| `XID 13` | 常见为应用越界、非法指令或寄存器错误 | 精英 | 越界指针长矛穿出内存格 |
| `XID 48 / DBE` | GPU 发现不可纠正的双比特 ECC 错误 | 精英 | 双损坏显存晶体与 ECC 爆炸 |
| `XID 74 / NVLINK` | GPU 与 GPU / NVSwitch 的 NVLink 连接异常 | 精英 | 两颗 GPU 核心由断裂链桥连接 |
| `XID 79` | GPU 通过 PCIe 已不可达，即 fallen off the bus | Boss | GPU 从 PCIe 王座脱落；巨大身体缺口吞噬投射物 |
| `XID 94` | 错误被限制在单个应用 | 精英 | ECC 核被六边形隔离罩包住 |
| `XID 95` | 错误影响多个应用，需要 Reset GPU | Boss | 隔离罩碎裂，ECC 污染向全场扩散 |
| `XID 119/120` | GSP RPC 超时或错误 | Boss | GSP 核向四周发送冻结 RPC 光束 |
| `THERMAL SLOWDOWN` | GPU 因温度过高发生软件或硬件降频 | 两阶段精英 | GPU 熔炉与巨型风扇；黄灯减速、红灯喷发 |

## 4. 内容候选池与 M1 冻结范围

本节的长表是后续版本候选池，不代表 M1 全量制作。M1 用最少资产验证“代码、轮廓、行为”是否成立。

### 4.1 普通怪候选

| 标签 | 战斗职责 | 识别锚点 |
|---|---|---|
| `404` | 闪现干扰 | 中空缺页 |
| `408` | 延迟减速 | 无腿漂浮沙漏 |
| `NXDOMAIN` | 幻影 / 假目标 | 缺名地球 |
| `ECONNREFUSED` | 短程击退 | 端口钳 |
| `EMFILE` | 扩宽蜂群 | 文件扇 |
| `EROFS` | 正面盾兵 | 锁盘甲壳 |
| `IMAGE PULL` | 拉取 / 召唤 | 卡死下载链 |
| `CROSSSLOT` | 成对链接 | 两个不同 Slot 方块 |
| `ENOSPC` | 扩张占地 | 无腿容量圆盘与 `100%` 缺口 |
| `BUG` | 快速爬行 | 唯一允许长腿的橙色软件虫 |

### 4.2 精英候选

| 标签 | 战斗职责 | 识别锚点 |
|---|---|---|
| `429` | 群怪队长 | 溢出令牌桶 |
| `502 / UPSTREAM` | 链路精英 | 双头网关 |
| `503 / OVERLOAD` | 重型坦克 | 过热机柜 |
| `OOM / 137` | 爆裂占地 | 内存气囊 |
| `CRASHLOOP` | 复活循环 | 三段衔尾蛇 |
| `PG 40P01` | 双体链接 | 交叉锁链 |
| `PG DEGRADED` | 部件修复 | 缺角复制三角 |

### 4.3 Boss 候选

| 标签 | 章节定位 | 阶段结构 |
|---|---|---|
| `FATAL / INCIDENT CORE` | 通用事故核心 | 轮换挂载当前关卡的 3 个真实根因；`FATAL` 只是冠标 |
| `KERNEL PANIC` | 主机与系统章节 | 进程冻结 → 堆栈喷发 → 恢复模式 |
| `NO QUORUM` | 数据与存储章节 | 失联节点 → 少数派冲突 → 重建多数派 |
| `XID 79` | AI Infra 章节 | PCIe 断链 → GPU 脱落 → 节点迁移 |

### 4.4 M1 正式冻结：5 + 2 + 1

| 层级 | 冻结内容 | 验证目标 |
|---|---|---|
| 普通怪 5 种 | `404`、`NXDOMAIN`、`ENOSPC`、`BUG`、`408` | 漂浮、滑行、滚动、爬行、蓄力五种移动与剪影 |
| 精英 2 种 | `502 UPSTREAM`、`OOM 137` | 宽型双头与圆型膨胀体的极端轮廓差 |
| Boss 1 个 | `FATAL / INCIDENT CORE` | 多部位、阶段冠标与根因挂载 |

## 5. 事故波次不再随机拼盘

故障应以因果链组成波次，让懂行玩家从敌群中“读出事故”：

| 事故链 | 波次组合 | 玩家读到的故事 |
|---|---|---|
| 上游雪崩 | `ECONNREFUSED` → `502 UPSTREAM` → `503 OVERLOAD` | 上游拒绝连接，网关报错，重试进一步压垮服务 |
| 慢请求风暴 | `408` → `504` → `429` | 请求积压与超时，最终触发限流 |
| 容器内存事故 | `OOM 137` → `CRASHLOOP` → `NODE NOTREADY` | 容器 OOM 后持续重启，节点压力扩大 |
| 数据库锁事故 | `PG 40P01` + `PG 53300` + `REPLAY LAG` | 死锁、连接堆积和副本延迟互相放大 |
| 存储退化 | `OSD DOWN` → `PG DEGRADED` → `NO QUORUM` | 设备掉线、冗余下降、最终失去共识 |
| DNS / 证书事故 | `NXDOMAIN` + `SERVFAIL` → `CERT EXPIRED` | 解析与证书问题叠加，客户端表现相似但根因不同 |
| AI 集群事故 | `NCCL MISMATCH` → `XID 74` → `XID 79` | 通信异常扩大为链路故障，最终 GPU 不可达 |

## 6. Golden Sample 的资产要求

普通怪先制作单体造型板，不直接扩成大量战斗图：

- 第一板：`404`、`NXDOMAIN`、`ENOSPC`、`BUG`。
- 第二板补齐：`408`，并把五种普通怪放进同一比例测试。
- 精英板：`502 UPSTREAM`、`OOM 137`。
- Boss 板：`FATAL` 冠标 + `INCIDENT CORE` 根因条。

每种普通怪的造型板必须包含：

- 1 张完整上色的高俯视 3/4 游戏视图，以及实际 1× 与整数倍放大检查。
- 上、下、侧三向 1-bit 剪影；概念通过后再上色，不做八方向。
- 标签层开 / 关和独立代码牌插槽；正式代码由 Godot 绘制。
- 4 帧移动关键姿势；非 `BUG` 怪零腿零脚，浮游锚点使用影子中心。
- 受击、攻击预警、关闭各 1 个状态。
- 25 / 50 / 100 只密度图；最终使用正式图集再测 200 / 500 / 1000 单位。

## 7. 生产验收清单

- [ ] 32×32 黑色剪影下仍能区分普通怪家族。
- [ ] 不看文字，测试者也能把 502、503、OOM、Deadlock 的视觉和行为配对。
- [ ] 精英在 0.3 秒内可凭体型、预警和轮廓识别。
- [ ] 标签拼写、大小写和代码由 Godot 运行时绘制并通过自动截图测试。
- [ ] `FATAL` 始终与真实根因同时出现，不把严重度当根因。
- [ ] NGINX 不使用不存在的 `[fatal]` 日志等级。
- [ ] 不用颜色作为唯一识别通道；灰度与色弱模拟下仍能区分。
- [ ] 产品名与商标只在确有题材价值时出现；通用敌人优先使用标准码与通用原因。
- [ ] 每个新标签都记录官方来源、语义、内部 ID、轮廓和战斗职责。
