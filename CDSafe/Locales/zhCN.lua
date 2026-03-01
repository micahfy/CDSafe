CDSafeLocaleDB = CDSafeLocaleDB or {}

CDSafeLocaleDB["zhCN"] = {
    text = {
        STATUS_LOCKED = "已锁定",
        STATUS_OPEN = "未锁定",
        STATUS_UNKNOWN = "未知",
        UNKNOWN = "未知",
        YOU = "你",
        PLAYER = "玩家",
        LEADER = "团长",
        LEADER_DATA_SOURCE_LOCAL = "团长数据来源：本地",
        LEADER_SYNC_TIME = "团长同步时间",
        WAITING_FOR_SYNC = "等待同步...",
        NOT_IN_RAID = "不在团队中",
        PANEL_TITLE = "CDSafe - 团队副本CD状态",
        HEADER_RAID = "副本",
        HEADER_RESET = "重置",
        RESET_FMT_DAY_HOUR = "%d天%dH",
        RESET_FMT_HOUR_MIN = "%dH%dM",
        HEADER_LEADER = "团长",
        HEADER_YOU = "你",
        TOOLTIP_TOGGLE_PANEL = "左键：打开/关闭面板",
        TOOLTIP_TOGGLE_MUTE_ZONE = "右键：本区域静音（聊天+中央）",
        TOOLTIP_MOVE_ICON = "右键拖动：移动图标",
        HELP_MINIMAP = "小地图图标：鼠标右键点击可临时关闭当前区域告警。",
        MUTE_ZONE_ON = "已开启本区域静音：聊天框和中央提醒已关闭。",
        MUTE_ZONE_OFF = "已关闭本区域静音。",
        MUTE_ZONE_AUTO_OFF = "已离开静音区域：提醒自动恢复。",
        WARNING_LEADER_FALLBACK = "团长",
        WARNING_TEXT_TEMPLATE = "团长[%s]在[%s]已有CD，请勿进入以免被锁定。",
        WARNING_LEADER_UNKNOWN = "提醒：团长在[%s]的副本进度未能获取，请主动咨询团长进度情况。",
        WARNING_LEADER_SELF_TEMPLATE = "你在[%s]已有CD，带团前请确认，避免锁定团员CD。",
        INFO_SAFE_ENTER_TEMPLATE = "提示：团长在[%s]无CD，可以进入。",
        LEADER_SYNC_TIMEOUT_TEXT = "未收到团长同步信息（可能未安装插件）",
        LEADER_SYNC_RECEIVED = "团长进度已获取，点插件按钮或输入/cds查看",
        RETRY = "重试",
        RAID_REPORT_TEMPLATE = "[CDSafe] %s | 团长(%s)：%s | 你(%s)：%s",
        RAID_REPORT_LEADER_ONLY_TEMPLATE = "[CDSafe] %s | 团长(%s)：%s",
        RESET_MINIMAP = "小地图图标位置已重置。",
        INSTANCE_ID_LABEL = "ID",
        STATUS_WITH_ID_TEMPLATE = "%s（%s: %s）",
    },
    raidDisplay = {
        moltencore = "熔火之心",
        blackwinglair = "黑翼之巢",
        zulgurub = "祖尔格拉布",
        onyxia = "奥妮克希亚",
        aq20 = "安其拉废墟",
        aq40 = "安其拉神殿",
        lowerkarazhanhalls = "卡拉赞下层",
        towerofkarazhan = "卡拉赞之塔",
        naxxramas = "纳克萨玛斯",
        emeraldsanctum = "翡翠圣殿",
    },
    warningAreas = {
        moltencore = {
            { zone = "黑石山" },
        },
        blackwinglair = {
            { zone = "黑石山" },
        },
        zulgurub = {
            { zone = "荆棘谷", subzone = "祖尔格拉布" },
        },
        onyxia = {
            { subzone = "巨龙沼泽" },
        },
        aq20 = {
            { zone = "安其拉之门" },
        },
        aq40 = {
            { zone = "安其拉之门" },
        },
        lowerkarazhanhalls = {
            { zone = "逆风小径", subzone = "卡拉赞" },
        },
        towerofkarazhan = {
            { zone = "逆风小径", subzone = "卡拉赞" },
        },
        emeraldsanctum = {
            { zone = "海加尔山", subzone = "翡翠之门" },
        },
        naxxramas = {
            { subzone = "病木林" },
        },
    },
}
