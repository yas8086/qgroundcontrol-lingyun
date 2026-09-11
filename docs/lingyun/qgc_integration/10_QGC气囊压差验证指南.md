# QGC 气囊压差数据验证指南 — 灵云01号

| 项目 | 内容 |
|------|------|
| 文档目的 | 指导操作员在 QGC 中验证气囊压差数据链（接收→解析→显示）是否正常工作 |
| 适用固件 | cuav_x25-evo（2026-09-05 烧录版本，含气囊压差支持） |
| 数据链路 | LoRa压力传感器x4 → 树莓派(10.41.10.100) → uXRCE-DDS(UDP8888, domain5) → 飞控 → QGC |
| 编写日期 | 2026-09-05 |

---

## 0. 数据链路全景（30秒理解）

```
[LoRa传感器x4]──485──▶[树莓派 bladder_bridge_node]──DDS──▶[飞控client]──uORB──▶[ballast_control]
 槽位: 左副囊/左主囊/        0.5Hz发布(消息流永不停)         语义解析         质量校正+告警
      右主囊/右副囊                                                                        │
                                                                                         ▼
                                                                              QGC显示(bal_p0~bal_p3)
```

**关键认知：消息以 0.5Hz 永续发布，断链时内容变为沿用值/NaN，消息流不会停。** 所以验证的不是"有没有数据"，而是"数据是否新鲜、真实"。

---

## 1. 前置条件确认（2分钟）

| # | 检查项 | 位置 | 预期 |
|---|--------|------|------|
| 1 | 飞控与树莓派网线连接 | 交换机 | 物理连通，同网段 10.41.10.0/24 |
| 2 | DDS Agent 运行 | 树莓派（操作员无需操作，开机自启） | 树莓派侧自启+崩溃自愈 |
| 3 | LoRa 传感器供电 | 台架 | 4 路传感器上电（若未装可跳过，看 NaN 属正常） |

---

## 2. 第一步：验证 client 链路连通（QGC MAVLink Console）

打开 QGC → **分析工具(Analyze Tools)** → **MAVLink Console**，输入：

```
uxrce_dds_client status
```

**预期输出（通过）：**
```
running
agent: 10.41.10.100:8888
domain ID: 5
...
```

**异常排查：**

| 现象 | 原因 | 处置 |
|------|------|------|
| `not running` | client 未启动 | 检查参数 UXRCE_DDS_CFG=2（Ethernet），重启飞控 |
| running 但连不上 agent | 网线/IP 不通 | 树莓派侧 `ping 10.41.10.2`，检查交换机 |
| 连上但收不到数据 | DOM_ID 不一致 | QGC 参数页查 `UXRCE_DDS_DOM_ID` 必须 = 5 |

---

## 3. 第二步：验证 uORB 数据到达（QGC MAVLink Console）

同 Console 输入（收 5 条，约 10 秒）：

```
listener airship_bladder_pressure 5
```

**预期输出（通过，传感器正常时）：**
```
TOPIC: airship_bladder_pressure
 timestamp: xxx
 timestamp_sample: xxx
 pressure_delta_pa: [1250.3, 1310.5, 1298.2, 1205.8]   ← 四囊压差(Pa), 有符号
 temperature_c: [25.1, 25.3, 25.2, 24.9]                ← 传感器温度
 valid: [1, 1, 1, 1]                                    ← 全1=本轮真实测量
 stale: [0, 0, 0, 0]                                    ← 全0=无沿用值
```

**字段解读速查：**

| 字段 | 含义 | 正常值 |
|------|------|--------|
| pressure_delta_pa | 四囊相对大气压的压差 | 正常充压后 0~5000 Pa；台架未装舱 -30~-60 Pa 零漂属正常 |
| valid | 本轮是否真实测量 | [1,1,1,1] |
| stale | 是否沿用历史值 | [0,0,0,0]；传感器离线时逐渐变 [1,1,1,1] |
| 温度 | 传感器自带温度 | 环境温度附近 |

**语义判定铁律：`valid=1 && stale=0` 才是本轮实测。** stale=1 时数值可用但已过期（非本轮实测）。

---

## 4. 第三步：验证解析与消费（飞控侧日志）

Console 中输入：

```
ballast_control status
```

观察 `mass=` 字段（四囊空气质量估计，kg）。数据链正常时：
- 质量估计会被实测压差校正（每轮吸收 5% 偏差，缓慢收敛）
- 超压时输出 `ballast: PRESSURE x.x kPa near limit` 告警

**链路异常的飞控侧表现（Console/消息页面）：**

| 告警信息 | 含义 |
|---------|------|
| `bladder pressure link timeout (>10s)` | 10 秒无新鲜数据，质量校正已停用（回退纯积分，安全） |
| `bladder imbalance x.xx kPa` | 四囊压差>0.5kPa 不平衡（传感器或结构异常） |

---

## 5. 第四步：QGC 实时数据显示（Bal_p 透出通道）

飞控以 NAMED_VALUE_FLOAT 消息向 QGC 轮流透出 9 个调试量，其中气囊压差 4 个。

### 5.1 官方 QGC 仪表方式（无需开发）

**方法 A — MAVLink Inspector（推荐）：**

1. QGC → **分析工具** → **MAVLink Inspector**
2. 消息列表找 **NAMED_VALUE_FLOAT**，点击展开
3. 观察随时间刷新的 `key`/`value` 对，其中：
   - `bal_p0` = 左副囊实测表压（kPa）
   - `bal_p1` = 左主囊实测表压（kPa）
   - `bal_p2` = 右主囊实测表压（kPa）
   - `bal_p3` = 右副囊实测表压（kPa）
4. 每 5.6Hz 轮询一次每字段（9 字段轮询，约 1.6 秒每字段刷新一轮）

**方法 B — 实时绘图：**

MAVLink Inspector 中 NAMED_VALUE_FLOAT 右侧 "Start" 开启曲线图，可同时观察数值随时间变化（如充放气时压差爬升）。

**其余透出字段（对照参考）：**

| key | 含义 |
|-----|------|
| buoy | 净浮力调整量 (N) |
| alt_err | 高度误差 (m) |
| b_mass | 左主囊质量估计 (kg) |
| blower / valve | 风机/阀门输出 |

### 5.2 数值含义

| bal_p 值 | 状态 |
|----------|------|
| 0.0~5.0（kPa） | 正常工作区间（5.0 为最大表压） |
| > 4.75 | 接近超压限（飞控同时输出告警） |
| -0.03~-0.06 | 台架未充压零漂（正常） |
| NaN（QGC 显示空/0） | 该囊传感器从未有效（查传感器供电/LoRa链路） |

---

## 6. 端到端验收清单（逐项打勾）

| # | 验证点 | 操作 | 通过标准 |
|---|--------|------|---------|
| 1 | client 连接 | `uxrce_dds_client status` | running + agent 10.41.10.100:8888 |
| 2 | 数据到达 | `listener airship_bladder_pressure 5` | 每 ~2s 一条 |
| 3 | 数据真实 | 同上 | valid=[1,1,1,1], stale=[0,0,0,0] |
| 4 | 数值合理 | 同上 | 充压后正值/台架零漂小负值 |
| 5 | QGC 显示 | MAVLink Inspector → NAMED_VALUE_FLOAT | bal_p0~p3 数值与 listener 一致 |
| 6 | 校正生效 | `ballast_control status` | mass 缓慢趋向实测反推值 |
| 7 | 断链降级 | 拔树莓派 LoRa 串口 | 消息仍0.5Hz，stale 变1，>10s 后 timeout 告警一次 |
| 8 | 恢复 | 重新接上 | stale 回 0，校正自动恢复 |

---

## 7. 常见问题速查

| 症状 | 原因 | 处置 |
|------|------|------|
| listener 无输出，client 已连 | DOM_ID≠5 | 参数页改 UXRCE_DDS_DOM_ID=5，重启 |
| bal_p 全 NaN | LoRa 传感器未上电/断链 | 查传感器供电、树莓派侧数据 |
| bal_p 数值跳变大 | 单帧野值（已自动剔除，不影响） | 观察是否持续；持续则查传感器 |
| 四囊差值大告警 | 压差>0.5kPa | 查充放气是否同步、传感器安装 |
| 重启飞控后链路断 | 参数未保存 | 参数为 airframe 默认值，检查是否被手动恢复出厂 |

---

## 8. 附：槽位与物理位置对照表

| 槽位 | key | LoRa node_id | 物理位置 |
|------|-----|--------------|---------|
| 0 | bal_p0 | 6 | 左副囊 |
| 1 | bal_p1 | 13 | 左主囊 |
| 2 | bal_p2 | 14 | 右主囊 |
| 3 | bal_p3 | 15 | 右副囊 |
