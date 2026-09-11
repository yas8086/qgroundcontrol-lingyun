# 浮力 NAMED_VALUE_FLOAT 四囊独立广播契约升级（QGC → PX4 侧需求）

> **文档目的**: QGC 侧"气囊浮力监控"面板已按**四囊独立执行器**契约完成升级（15 字段），
> 需 PX4 侧 `ballast_control` 模块的 NAMED_VALUE_FLOAT 轮转广播同步升级，
> 否则 QGC 面板的**风机/阀门两行显示为 "—"（数据缺失）**。
>
> **提出方**: QGC 项目（2026-09-09）
> **影响模块**: PX4 `ballast_control`（仅广播部分，控制逻辑不变）
> **关联文档**:
> - `qgc_integration/03_interfaces.md` §5（当前实发的 9 字段契约，升级后需同步更新为 15 字段）
> - `qgc_integration/05_hardware.md` §4.2（四囊布线契约：囊1左副/囊2左主/囊3右主/囊4右副）
> - `10_QGC气囊压差验证指南.md`（bal_p0-3 既有先例）

---

## 1. 现状对照

| key | 固件当前实发 | QGC 期待 | 状态 |
|-----|-------------|----------|------|
| buoy | ✅ 净浮力 N | buoy | ✅ 一致 |
| alt_err | ✅ 高度误差 m | alt_err | ✅ 一致 |
| b_mass | ✅ 单囊空气质量 kg | b_mass | ✅ 一致 |
| bal_p0~p3 | ✅ 四囊压差 kPa | bal_p0~p3 | ✅ 一致（2026-09-06 实机数据已通）|
| **blower** | ✅ 单数，四囊同步值 0-255 | ❌ **blower0~blower3**（每囊独立 0-100%）| ❌ 不一致 → QGC 显示 "—" |
| **valve** | ✅ 单数，四囊同步值 0/255 | ❌ **valve0~valve3**（每囊独立 0=关/100=开）| ❌ 不一致 → QGC 显示 "—" |

**QGC 侧证据**: tlog 解析（2026-09-06/08 连接）实测固件发送 key 集合 = `{buoy, alt_err, b_mass, bal_p0-3, blower, valve, pc_bv, pc_mode}`，无 blower0-3/valve0-3。

## 2. 升级需求（ballast_control 广播部分）

### 2.1 key 拆分

将四囊同步的 `blower`/`valve` 两个 key，按囊序号拆分为独立广播：

| 旧 key（删除） | 新 key（新增） | 囊序号 | 囊名称 | 物理输出 |
|---------------|---------------|--------|--------|----------|
| blower | **blower0** | 0 | 左副囊 | blower0（占空比）|
| blower | **blower1** | 1 | 左主囊 | blower1 |
| blower | **blower2** | 2 | 右主囊 | blower2 |
| blower | **blower3** | 3 | 右副囊 | blower3 |
| valve | **valve0** | 0 | 左副囊 | valve0（PWM 模拟开关量）|
| valve | **valve1** | 1 | 左主囊 | valve1 |
| valve | **valve2** | 2 | 右主囊 | valve2 |
| valve | **valve3** | 3 | 右副囊 | valve3 |

囊序号与 `bal_p0~bal_p3` 的对应关系保持一致（bal_p0=左副囊同 blower0/valve0）。

### 2.2 单位定义（⚠️ 与旧契约不同，注意）

| key | 单位 | 范围 | 说明 |
|-----|------|------|------|
| blower0~3 | **%**（占空比百分比）| 0 ~ 100 | 旧 blower 为 0-255 原始占空比；新契约直接发百分比，避免 GCS 换算 |
| valve0~3 | 开关量 | **0 = 关 / 100 = 开** | 旧 valve 为 0/255；新契约统一为 0/100 |

（若 ballast_control 内部仍以 0-255 存储，发布处换算：`value_percent = raw * 100 / 255`，四舍五入取整。）

### 2.3 key 总数与轮转频率影响

- 升级后 key 总数：**9 → 15**（buoy/alt_err/b_mass + bal_p0-3 + blower0-3 + valve0-3）
- 消息率维持 QGC 请求的 2Hz（SET_MESSAGE_INTERVAL）不变，15 key 轮转下 **每 key 约 0.13Hz**（升级前 9 key 约 0.2Hz）
- 浮力物理量为秒~分钟级变化，0.13Hz 更新率足够（压差噪声值跳动仍可判活）
- 发布机制不变：仍为 50Hz 内部轮转发布 `debug_key_value` → MAVLink NAMED_VALUE_FLOAT，受流表/SET_MESSAGE_INTERVAL 门控

### 2.4 广播轮转表（建议实现）

```
轮转序列（15 key）:
buoy → alt_err → b_mass → bal_p0 → bal_p1 → bal_p2 → bal_p3
→ blower0 → blower1 → blower2 → blower3
→ valve0 → valve1 → valve2 → valve3 → (回到 buoy)
```

每囊的 blower/valve 相邻广播（blower0 紧跟 valve0），便于 QGC 侧按囊聚合验证数据一致性。

## 3. 兼容性说明

- **QGC 侧**: 已完全按 15 字段新契约实现（解析/单位/单位无效时显示 "—"/四囊独立卡片），升级后无需任何 QGC 改动
- **旧 key 移除无兼容负担**: QGC 对未知 key 直接忽略（handleMessage 白名单机制），不存在混发需求；建议直接替换而非叠加
- **其他 GCS/工具**: 若有依赖旧 `blower`/`valve` key 的脚本（如台架测试脚本），需同步更新 key 名

## 4. 验收标准

1. MAVLink Inspector（或 tlog 解析）可见完整 15 个 key 轮转
2. blower0~3 数值范围 0-100，与各囊实际风机占空比一致（台架拨动测试）
3. valve0~3 数值 0/100，与各囊阀门开关状态一致
4. QGC"气囊浮力监控"面板四囊卡片的**风机/阀门两行显示实际数值**（不再是 "—"）
5. 消息率维持 2Hz（15 key 轮转），浮力面板全字段更新正常

## 5. QGC 侧已就绪清单（无需 PX4 关注，仅备案）

- [x] AirshipBallastFactGroup 15 字段解析（blower0-3/valve0-3/bladderPressure0-3/buoy/alt_err/b_mass）
- [x] FactMetaData 单位定义（blower %、valve 开关量、压差 kPa）
- [x] 四囊独立监控卡片 UI（压差+风机+阀门，按物理位置 2x2 排布）
- [x] 超压告警（>4.75 kPa 变红）、四囊不平衡告警（>0.5 kPa）
- [x] NAMED_VALUE_FLOAT 2Hz 流请求（Vehicle::_parametersReady 中，解决 USB_MAV_MODE=0 下数据冻结）
- [x] 面板参数名旁标注协议字段名（bal_pN/blowerN/valveN），便于联调对照

---

*QGC 侧契约版本: v2（15 字段四囊独立, 2026-09-09）*
