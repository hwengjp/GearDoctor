import {
  Callout,
  Card,
  CardBody,
  CardHeader,
  Divider,
  Grid,
  H1,
  H2,
  H3,
  Pill,
  Row,
  Stack,
  Stat,
  Table,
  Text,
  TextArea,
  TextInput,
  UsageBar,
  useCanvasState,
  useHostTheme,
} from "cursor/canvas";

type ScreenId = "home" | "detail" | "replace" | "edit-record" | "add" | "split-merge" | "import-csv" | "sync" | "strava" | "settings" | "gear";
type Position = "rear" | "front" | "single";
type LimitMode = "recommended" | "previousCycle" | "custom";
type CycleKind = "distance" | "months";

type Side = {
  position: Position;
  usedKm: number;
  limitKm: number;
  thresholdPct: number;
  lastReplaced: string;
};

type Part = {
  id: string;
  name: string;
  split: boolean;
  cycle: CycleKind;
  sides: readonly Side[];
};

const GEARS = ["Aeroad", "Endurace", "Grail"] as const;

const PARTS: readonly Part[] = [
  {
    id: "tire",
    name: "タイヤ",
    split: true,
    cycle: "distance",
    sides: [
      { position: "rear", usedKm: 2700, limitKm: 6000, thresholdPct: 80, lastReplaced: "2025-08-01" },
      { position: "front", usedKm: 4800, limitKm: 6000, thresholdPct: 80, lastReplaced: "2025-03-01" },
    ],
  },
  {
    id: "chain",
    name: "チェーン",
    split: false,
    cycle: "distance",
    sides: [
      { position: "single", usedKm: 1800, limitKm: 4000, thresholdPct: 80, lastReplaced: "2025-11-12" },
    ],
  },
  {
    id: "pads",
    name: "ブレーキパッド",
    split: true,
    cycle: "distance",
    sides: [
      { position: "rear", usedKm: 600, limitKm: 1500, thresholdPct: 80, lastReplaced: "2026-01-20" },
      { position: "front", usedKm: 1200, limitKm: 1500, thresholdPct: 80, lastReplaced: "2026-01-20" },
    ],
  },
  {
    id: "cable",
    name: "ワイヤー",
    split: true,
    cycle: "distance",
    sides: [
      { position: "rear", usedKm: 2200, limitKm: 5000, thresholdPct: 80, lastReplaced: "2025-06-10" },
      { position: "front", usedKm: 2200, limitKm: 5000, thresholdPct: 80, lastReplaced: "2025-06-10" },
    ],
  },
  {
    id: "speed-batt",
    name: "スピードセンサ電池",
    split: false,
    cycle: "months",
    sides: [
      { position: "single", usedKm: 7, limitKm: 12, thresholdPct: 80, lastReplaced: "2026-01-20" },
    ],
  },
];

function pct(used: number, limit: number) {
  return Math.round((used / limit) * 100);
}

function statusOf(used: number, limit: number, thresholdPct: number) {
  const p = pct(used, limit);
  if (p >= 100) return { label: "交換", color: "red" as const };
  if (p >= thresholdPct) return { label: "そろそろ", color: "orange" as const };
  return { label: "余裕", color: "green" as const };
}

function positionLabel(position: Position) {
  if (position === "front") return "F";
  if (position === "rear") return "R";
  return "";
}

function findPart(partId: string) {
  return PARTS.find((p) => p.id === partId) ?? PARTS[0];
}

function findSide(part: Part, position: Position) {
  return part.sides.find((s) => s.position === position) ?? part.sides[0];
}

type HistoryRow = {
  date: string;
  km: string;
  memo: string;
};

function unitLabel(cycle: CycleKind) {
  return cycle === "months" ? "か月" : "km";
}

function formatElapsedAndDue(
  used: number,
  limit: number,
  cycle: CycleKind,
  modeLabel?: string,
) {
  let text = `${used.toLocaleString()} / ${limit.toLocaleString()} ${unitLabel(cycle)}`;
  if (modeLabel) {
    text += ` ${modeLabel}`;
  }
  return cycle === "distance" ? `${text}（デモ）` : text;
}

function historyFor(
  partId: string,
  position: Position,
  fallbackDate: string,
  fallbackUsed: number,
  cycle: CycleKind,
) {
  if (partId === "speed-batt") {
    return [{ date: "2026-01-20", km: "8,200km（デモ）", memo: "" }];
  }
  if (partId === "tire" && position === "front") {
    return [
      { date: "2023-04-02", km: "5,800km（デモ）", memo: "" },
      { date: "2024-01-15", km: "11,900km（デモ）", memo: "パンク後に交換" },
      { date: "2025-03-01", km: "16,700km（デモ）", memo: "GP5000" },
    ];
  }
  if (partId === "tire" && position === "rear") {
    return [
      { date: "2024-06-20", km: "5,900km（デモ）", memo: "" },
      { date: "2025-08-01", km: "8,600km（デモ）", memo: "サイドカット" },
    ];
  }
  return [
    {
      date: fallbackDate,
      km: `${fallbackUsed.toLocaleString()}km（デモ）`,
      memo: "",
    },
  ];
}

function HistoryTable({
  partId,
  position,
  lastReplaced,
  usedKm,
  cycle,
  onOpenRecord,
}: {
  partId: string;
  position: Position;
  lastReplaced: string;
  usedKm: number;
  cycle: CycleKind;
  onOpenRecord?: (row: HistoryRow) => void;
}) {
  const t = useHostTheme();
  const history = historyFor(partId, position, lastReplaced, usedKm, cycle);
  const todayKm =
    partId === "tire" && position === "front"
      ? 21500
      : partId === "tire" && position === "rear"
        ? 11300
        : partId === "speed-batt"
          ? 10500
          : usedKm;
  return (
    <Stack gap={6}>
      <Text size="small" tone="secondary">
        過去の交換記録
      </Text>
      <Text size="small" tone="tertiary">
        行をタップして日付・コメントの修正や削除
      </Text>
      <div
        style={{
          border: `1px solid ${t.stroke.secondary}`,
          borderRadius: 8,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1.2fr 88px 1fr",
            gap: 4,
            padding: "6px 8px",
            background: t.fill.tertiary,
          }}
        >
          <Text size="small" tone="tertiary">
            ギアの走行距離
          </Text>
          <Text size="small" tone="tertiary">
            交換日
          </Text>
          <Text size="small" tone="tertiary">
            コメント
          </Text>
        </div>
        {history.map((row) => (
          <div
            key={`${row.date}-${row.memo}`}
            onClick={() => onOpenRecord?.(row)}
            style={{
              display: "grid",
              gridTemplateColumns: "1.2fr 88px 1fr",
              gap: 4,
              padding: "8px",
              borderTop: `1px solid ${t.stroke.tertiary}`,
              cursor: onOpenRecord ? "pointer" : "default",
            }}
          >
            <Text size="small">{row.km}</Text>
            <Text size="small">{row.date}</Text>
            <Text size="small" tone="secondary">
              {row.memo || "—"}
            </Text>
          </div>
        ))}
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1.2fr 88px 1fr",
            gap: 4,
            padding: "8px",
            borderTop: `1px solid ${t.stroke.tertiary}`,
          }}
        >
          <Text size="small">{todayKm.toLocaleString()}km（今日）</Text>
          <Text size="small"> </Text>
          <Text size="small"> </Text>
        </div>
      </div>
    </Stack>
  );
}

function PhoneButton({
  label,
  variant,
  onClick,
}: {
  label: string;
  variant: "primary" | "secondary" | "ghost";
  onClick: () => void;
}) {
  const t = useHostTheme();
  const bg =
    variant === "primary"
      ? t.accent.primary
      : variant === "secondary"
        ? t.fill.primary
        : "transparent";
  const color = variant === "primary" ? t.text.onAccent : t.text.primary;
  const border =
    variant === "ghost" ? `1px solid ${t.stroke.secondary}` : "1px solid transparent";
  return (
    <div
      onClick={onClick}
      style={{
        flex: 1,
        textAlign: "center",
        padding: "10px 8px",
        borderRadius: 8,
        background: bg,
        color,
        border,
        cursor: "pointer",
        fontSize: 13,
        fontWeight: 590,
      }}
    >
      {label}
    </div>
  );
}

function Phone({
  title,
  onBack,
  trailing,
  onTrailing,
  bodyScroll = true,
  children,
}: {
  title: string;
  onBack?: () => void;
  trailing?: string;
  onTrailing?: () => void;
  bodyScroll?: boolean;
  children?: unknown;
}) {
  const t = useHostTheme();
  return (
    <div
      style={{
        width: 300,
        height: 640,
        borderRadius: 24,
        border: `1px solid ${t.stroke.primary}`,
        background: t.bg.elevated,
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
      }}
    >
      <div
        style={{
          padding: "10px 16px 6px",
          fontSize: 11,
          color: t.text.tertiary,
          display: "flex",
          justifyContent: "space-between",
        }}
      >
        <span>9:41</span>
        <span>Android</span>
      </div>
      <div
        style={{
          padding: "8px 12px 12px",
          display: "flex",
          alignItems: "center",
          gap: 8,
          borderBottom: `1px solid ${t.stroke.tertiary}`,
        }}
      >
        {onBack ? (
          <div
            onClick={onBack}
            style={{ cursor: "pointer", color: t.accent.primary, fontSize: 13, minWidth: 36 }}
          >
            戻る
          </div>
        ) : null}
        <div style={{ flex: 1, fontSize: 16, fontWeight: 590, color: t.text.primary }}>
          {title}
        </div>
        {trailing ? (
          <div
            onClick={onTrailing}
            style={{
              fontSize: 13,
              color: t.accent.primary,
              cursor: onTrailing ? "pointer" : "default",
            }}
          >
            {trailing}
          </div>
        ) : null}
      </div>
      <div
        style={{
          flex: 1,
          minHeight: 0,
          overflow: bodyScroll ? "auto" : "hidden",
          padding: bodyScroll ? 12 : 0,
          display: bodyScroll ? undefined : "flex",
          flexDirection: bodyScroll ? undefined : "column",
        }}
      >
        {children}
      </div>
    </div>
  );
}

function SideBlock({
  side,
  cycle,
  onClick,
}: {
  side: Side;
  cycle: CycleKind;
  onClick: () => void;
}) {
  const p = pct(side.usedKm, side.limitKm);
  const st = statusOf(side.usedKm, side.limitKm, side.thresholdPct);
  const label = positionLabel(side.position);
  const statusLine = label
    ? `${label}：${st.label}・${p}％`
    : `${st.label}・${p}％`;
  return (
    <div onClick={onClick} style={{ flex: 1, cursor: "pointer", minWidth: 0 }}>
      <Text size="small" weight="semibold">
        {statusLine}
      </Text>
      <Text size="small" tone="secondary">
        {formatElapsedAndDue(side.usedKm, side.limitKm, cycle, "推奨")}
      </Text>
      <UsageBar
        total={side.limitKm}
        segments={[{ id: `${side.position}-${side.usedKm}`, value: side.usedKm, color: st.color }]}
      />
    </div>
  );
}

function collectAlerts() {
  const alerts: Array<{
    partId: string;
    position: Position;
    label: string;
  }> = [];
  for (const part of PARTS) {
    for (const side of part.sides) {
      if (pct(side.usedKm, side.limitKm) >= side.thresholdPct) {
        const pos = positionLabel(side.position);
        alerts.push({
          partId: part.id,
          position: side.position,
          label: pos ? `${part.name} ${pos}` : part.name,
        });
      }
    }
  }
  return alerts;
}

function HomeScreen({
  go,
  gear,
}: {
  go: (screen: ScreenId, partId?: string, position?: Position) => void;
  gear: string;
}) {
  const t = useHostTheme();
  const alerts = collectAlerts();

  return (
    <Phone title="GearDoctor" trailing="設定" onTrailing={() => go("settings")} bodyScroll={false}>
      <div
        style={{
          flex: 1,
          minHeight: 0,
          display: "flex",
          flexDirection: "column",
          padding: 12,
          gap: 12,
        }}
      >
        <div
          onClick={() => go("sync")}
          style={{
            padding: 10,
            borderRadius: 8,
            background: t.fill.secondary,
            border: `1px solid ${t.stroke.secondary}`,
            flexShrink: 0,
            cursor: "pointer",
          }}
        >
          <Text size="small" weight="semibold">
            デモを解除するには Strava を同期します。最初の取得でデモ走行は消えます。
          </Text>
        </div>
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            gap: 8,
          }}
        >
          <div onClick={() => go("gear")} style={{ cursor: "pointer", flex: 1 }}>
            <Text weight="semibold">
              ギア: {gear}（デモ）
            </Text>
          </div>
          <div onClick={() => go("sync")} style={{ cursor: "pointer" }}>
            <Text size="small" tone="secondary">
              最終同期 2025-07-17〜2026-07-15（デモ）
            </Text>
          </div>
        </div>
        {alerts.length > 0 ? (
          <div
            style={{
              padding: 10,
              borderRadius: 8,
              background: t.fill.secondary,
              border: `1px solid ${t.stroke.secondary}`,
              flexShrink: 0,
            }}
          >
            <Text size="small" weight="semibold">
              しきい値 {alerts.length}件
            </Text>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginTop: 8 }}>
              {alerts.map((alert) => (
                <div
                  key={`${alert.partId}-${alert.position}`}
                  onClick={() => go("detail", alert.partId, alert.position)}
                  style={{
                    padding: "4px 8px",
                    borderRadius: 6,
                    border: `1px solid ${t.stroke.secondary}`,
                    background: t.fill.tertiary,
                    cursor: "pointer",
                    fontSize: 12,
                    color: t.text.primary,
                  }}
                >
                  {alert.label}
                </div>
              ))}
            </div>
          </div>
        ) : null}
        <div
          style={{
            flex: 1,
            minHeight: 0,
            overflow: "auto",
            display: "flex",
            flexDirection: "column",
            gap: 12,
          }}
        >
          {PARTS.map((part) => (
            <div
              key={part.id}
              style={{
                padding: 12,
                borderRadius: 8,
                border: `1px solid ${t.stroke.secondary}`,
                background: t.fill.tertiary,
              }}
            >
              <Text weight="semibold">{part.name}</Text>
              {part.split ? (
                <div style={{ display: "flex", gap: 10, marginTop: 8 }}>
                  <SideBlock
                    side={part.sides[0]}
                    cycle={part.cycle}
                    onClick={() => go("detail", part.id, "rear")}
                  />
                  <div style={{ width: 1, background: t.stroke.secondary }} />
                  <SideBlock
                    side={part.sides[1]}
                    cycle={part.cycle}
                    onClick={() => go("detail", part.id, "front")}
                  />
                </div>
              ) : (
                <div style={{ marginTop: 8 }}>
                  <SideBlock
                    side={part.sides[0]}
                    cycle={part.cycle}
                    onClick={() => go("detail", part.id, "single")}
                  />
                </div>
              )}
            </div>
          ))}
        </div>
        <div style={{ flexShrink: 0 }}>
          <PhoneButton label="Strava同期" variant="primary" onClick={() => go("sync")} />
        </div>
      </div>
    </Phone>
  );
}

function DetailScreen({
  partId,
  position,
  go,
  limitMode,
  customLimitKm,
  customLimitMonths,
  onOpenRecord,
}: {
  partId: string;
  position: Position;
  go: (screen: ScreenId, partId?: string, position?: Position) => void;
  limitMode: LimitMode;
  customLimitKm: number;
  customLimitMonths: number;
  onOpenRecord: (row: HistoryRow) => void;
}) {
  const part = findPart(partId);
  const side = findSide(part, position);
  const previousCycleLimit = 4800;
  const customLimit = part.cycle === "months" ? customLimitMonths : customLimitKm;
  const limitKm =
    limitMode === "recommended"
      ? side.limitKm
      : limitMode === "previousCycle"
        ? previousCycleLimit
        : customLimit;
  const p = pct(side.usedKm, limitKm);
  const st = statusOf(side.usedKm, limitKm, side.thresholdPct);
  const pos = positionLabel(side.position);
  const title = pos ? `${part.name} · ${pos}` : part.name;
  const modeLabel =
    limitMode === "recommended" ? "推奨" : limitMode === "previousCycle" ? "自動" : "設定";
  const unit = unitLabel(part.cycle);
  return (
    <Phone title={title} onBack={() => go("home")}>
      <Stack gap={14}>
        <Text size="small" tone="secondary">
          {part.cycle === "months" ? "交換後の経過" : "交換後の走行距離"}
        </Text>
        <Text weight="semibold" style={{ fontSize: 22, lineHeight: "28px" }}>
          {formatElapsedAndDue(side.usedKm, limitKm, part.cycle, modeLabel)}
        </Text>
        <UsageBar
          total={limitKm}
          topLeftLabel={`${p}% · ${st.label}`}
          topRightLabel={`しきい値 ${side.thresholdPct}%`}
          segments={[{ id: part.id, value: side.usedKm, color: st.color }]}
        />
        <Text size="small" tone="secondary">
          最終交換 {side.lastReplaced}
        </Text>
        <Row gap={8}>
          <PhoneButton
            label="交換した"
            variant="primary"
            onClick={() => go("replace", part.id, side.position)}
          />
          <PhoneButton label="編集" variant="ghost" onClick={() => go("add")} />
        </Row>
        <HistoryTable
          partId={part.id}
          position={side.position}
          lastReplaced={side.lastReplaced}
          usedKm={side.usedKm}
          cycle={part.cycle}
          onOpenRecord={onOpenRecord}
        />
      </Stack>
    </Phone>
  );
}

function ReplaceScreen({
  partId,
  position,
  go,
  onOpenRecord,
}: {
  partId: string;
  position: Position;
  go: (screen: ScreenId, partId?: string, position?: Position) => void;
  onOpenRecord: (row: HistoryRow) => void;
}) {
  const part = findPart(partId);
  const side = findSide(part, position);
  const pos = positionLabel(side.position);
  const name = pos ? `${part.name}（${pos}）` : part.name;
  const [replaceDate, setReplaceDate] = useCanvasState("replaceDate", "2026-08-23");
  const [replaceMemo, setReplaceMemo] = useCanvasState("replaceMemo", "");
  return (
    <Phone title="交換を記録" onBack={() => go("detail", part.id, side.position)}>
      <Stack gap={14}>
        <Text>
          {name}を交換した日付を記録すると、この位置の
          {part.cycle === "months" ? "経過月" : "走行距離"}
          だけゼロから始まります。
        </Text>
        <Stack gap={4}>
          <Text size="small" tone="secondary">
            交換日
          </Text>
          <TextInput
            value={replaceDate}
            onChange={setReplaceDate}
            placeholder="YYYY-MM-DD"
          />
          <Text size="small" tone="tertiary">
            初期値は今日。記録し忘れのときは、実際に交換した日に直す
          </Text>
        </Stack>
        <Stack gap={4}>
          <Text size="small" tone="secondary">
            メモ
          </Text>
          <TextArea
            value={replaceMemo}
            onChange={setReplaceMemo}
            placeholder="製品名、交換理由など（空でも可）"
            rows={2}
          />
        </Stack>
        <PhoneButton label="記録する" variant="primary" onClick={() => go("home")} />
        <HistoryTable
          partId={part.id}
          position={side.position}
          lastReplaced={side.lastReplaced}
          usedKm={side.usedKm}
          cycle={part.cycle}
          onOpenRecord={onOpenRecord}
        />
        <PhoneButton
          label="キャンセル"
          variant="ghost"
          onClick={() => go("detail", part.id, side.position)}
        />
      </Stack>
    </Phone>
  );
}

function EditRecordScreen({
  partId,
  position,
  row,
  editDate,
  editMemo,
  onChangeDate,
  onChangeMemo,
  go,
}: {
  partId: string;
  position: Position;
  row: HistoryRow;
  editDate: string;
  editMemo: string;
  onChangeDate: (value: string) => void;
  onChangeMemo: (value: string) => void;
  go: (screen: ScreenId, partId?: string, position?: Position) => void;
}) {
  const part = findPart(partId);
  const pos = positionLabel(position);
  const name = pos ? `${part.name}（${pos}）` : part.name;
  return (
    <Phone title="記録を編集" onBack={() => go("replace", partId, position)}>
      <Stack gap={14}>
        <Text size="small" tone="secondary">
          {name} · {row.km}
        </Text>
        <Stack gap={4}>
          <Text size="small" tone="secondary">
            交換日
          </Text>
          <TextInput value={editDate} onChange={onChangeDate} placeholder="YYYY-MM-DD" />
        </Stack>
        <Stack gap={4}>
          <Text size="small" tone="secondary">
            メモ
          </Text>
          <TextArea
            value={editMemo}
            onChange={onChangeMemo}
            placeholder="製品名、交換理由など（空でも可）"
            rows={2}
          />
        </Stack>
        <Text size="small" tone="tertiary">
          日付を変えると、その期間の走行距離を数え直す
        </Text>
        <PhoneButton label="保存" variant="primary" onClick={() => go("replace", partId, position)} />
        <PhoneButton label="この記録を削除" variant="ghost" onClick={() => go("replace", partId, position)} />
        <PhoneButton label="キャンセル" variant="ghost" onClick={() => go("replace", partId, position)} />
      </Stack>
    </Phone>
  );
}

function AddScreen({
  go,
  cycleKind,
  onSelectCycle,
  limitMode,
  onSelectLimitMode,
  recommendedKm,
  customLimitKm,
  recommendedMonths,
  customLimitMonths,
}: {
  go: (screen: ScreenId) => void;
  cycleKind: CycleKind;
  onSelectCycle: (cycle: CycleKind) => void;
  limitMode: LimitMode;
  onSelectLimitMode: (mode: LimitMode) => void;
  recommendedKm: number;
  customLimitKm: number;
  recommendedMonths: number;
  customLimitMonths: number;
}) {
  const t = useHostTheme();
  const [partName, setPartName] = useCanvasState("addPartName", "タイヤ");
  const unit = unitLabel(cycleKind);
  const recommended = cycleKind === "months" ? recommendedMonths : recommendedKm;
  const custom = cycleKind === "months" ? customLimitMonths : customLimitKm;
  return (
    <Phone title="部品を追加" onBack={() => go("gear")}>
      <Stack gap={14}>
        <Stack gap={4}>
          <Text size="small" tone="secondary">
            名前
          </Text>
          <TextInput
            value={partName}
            onChange={setPartName}
            placeholder="登録名（前タイヤ、心拍計電池など）"
          />
          <Text size="small" tone="tertiary">
            ホームに出す名前。前と後ろは別々に登録します。
          </Text>
          <Text size="small" tone="tertiary">
            最初の交換日は、このギアのいちばん古い走行日です。入力しません。
          </Text>
        </Stack>
        <Stack gap={6}>
          <Text size="small" tone="secondary">
            交換周期
          </Text>
          <Text size="small" tone="tertiary">
            距離か月のどちらか。
          </Text>
          <div style={{ display: "flex", gap: 8 }}>
            <div
              onClick={() => onSelectCycle("distance")}
              style={{
                flex: 1,
                padding: 10,
                borderRadius: 8,
                textAlign: "center",
                border: `1px solid ${cycleKind === "distance" ? t.stroke.primary : t.stroke.secondary}`,
                background: cycleKind === "distance" ? t.fill.secondary : t.fill.tertiary,
                cursor: "pointer",
              }}
            >
              <Text size="small" weight={cycleKind === "distance" ? "semibold" : "normal"}>
                距離
              </Text>
            </div>
            <div
              onClick={() => onSelectCycle("months")}
              style={{
                flex: 1,
                padding: 10,
                borderRadius: 8,
                textAlign: "center",
                border: `1px solid ${cycleKind === "months" ? t.stroke.primary : t.stroke.secondary}`,
                background: cycleKind === "months" ? t.fill.secondary : t.fill.tertiary,
                cursor: "pointer",
              }}
            >
              <Text size="small" weight={cycleKind === "months" ? "semibold" : "normal"}>
                月
              </Text>
            </div>
          </div>
        </Stack>
        <Stack gap={6}>
          <Text size="small" tone="secondary">
            交換目安
          </Text>
          <div
            onClick={() => onSelectLimitMode("recommended")}
            style={{
              padding: 10,
              borderRadius: 8,
              border: `1px solid ${limitMode === "recommended" ? t.stroke.primary : t.stroke.secondary}`,
              background: limitMode === "recommended" ? t.fill.secondary : t.fill.tertiary,
              cursor: "pointer",
            }}
          >
            <Text size="small" weight={limitMode === "recommended" ? "semibold" : "normal"}>
              推奨  {recommended.toLocaleString()} {unit}
            </Text>
            <Text size="small" tone="tertiary">
              名前から自動で決まります。
            </Text>
          </div>
          <div
            onClick={() => onSelectLimitMode("previousCycle")}
            style={{
              padding: 10,
              borderRadius: 8,
              border: `1px solid ${limitMode === "previousCycle" ? t.stroke.primary : t.stroke.secondary}`,
              background: limitMode === "previousCycle" ? t.fill.secondary : t.fill.tertiary,
              cursor: "pointer",
            }}
          >
            <Text size="small" weight={limitMode === "previousCycle" ? "semibold" : "normal"}>
              自動  4,800 {unit}
            </Text>
            <Text size="small" tone="tertiary">
              直近の2回の間隔。毎回計算
            </Text>
          </div>
          <div
            onClick={() => onSelectLimitMode("custom")}
            style={{
              padding: 10,
              borderRadius: 8,
              border: `1px solid ${limitMode === "custom" ? t.stroke.primary : t.stroke.secondary}`,
              background: limitMode === "custom" ? t.fill.secondary : t.fill.tertiary,
              cursor: "pointer",
            }}
          >
            <Text size="small" weight={limitMode === "custom" ? "semibold" : "normal"}>
              設定  {custom.toLocaleString()} {unit}
            </Text>
            <Text size="small" tone="tertiary">
              自分で入力します。
            </Text>
          </div>
        </Stack>
        <Stack gap={4}>
          <Text size="small" tone="secondary">
            通知しきい値
          </Text>
          <Text>80 %</Text>
        </Stack>
        <PhoneButton label="保存" variant="primary" onClick={() => go("home")} />
      </Stack>
    </Phone>
  );
}

function SplitMergeScreen({ go }: { go: (screen: ScreenId) => void }) {
  const t = useHostTheme();
  const [mode, setMode] = useCanvasState<"combine" | "separate">("displayGroupMode", "combine");
  const [picked, setPicked] = useCanvasState<string[]>("displayGroupPicked", [
    "前タイヤ",
    "後タイヤ",
  ]);
  const [frontName, setFrontName] = useCanvasState("displayGroupFront", "前タイヤ");
  const [groupName, setGroupName] = useCanvasState("displayGroupName", "タイヤ");
  const candidates = ["前タイヤ", "後タイヤ", "チェーン", "心拍計電池"];

  const togglePick = (name: string) => {
    const has = picked.includes(name);
    if (has) {
      setPicked(picked.filter((n) => n !== name));
      return;
    }
    if (picked.length >= 2) {
      setPicked([picked[1], name]);
      return;
    }
    setPicked([...picked, name]);
  };

  return (
    <Phone title="表示のまとめ" onBack={() => go("gear")}>
      <Stack gap={14}>
        <Text size="small" tone="tertiary">
          ホームでは1行にまとめます。部品そのものは分かれています。
        </Text>
        <div style={{ display: "flex", gap: 8 }}>
          <div
            onClick={() => setMode("combine")}
            style={{
              flex: 1,
              padding: 8,
              textAlign: "center",
              borderRadius: 8,
              cursor: "pointer",
              border: `1px solid ${mode === "combine" ? t.stroke.primary : t.stroke.secondary}`,
              background: mode === "combine" ? t.fill.secondary : t.fill.tertiary,
            }}
          >
            <Text size="small" weight={mode === "combine" ? "semibold" : "normal"}>
              まとめて表示
            </Text>
          </div>
          <div
            onClick={() => setMode("separate")}
            style={{
              flex: 1,
              padding: 8,
              textAlign: "center",
              borderRadius: 8,
              cursor: "pointer",
              border: `1px solid ${mode === "separate" ? t.stroke.primary : t.stroke.secondary}`,
              background: mode === "separate" ? t.fill.secondary : t.fill.tertiary,
            }}
          >
            <Text size="small" weight={mode === "separate" ? "semibold" : "normal"}>
              分けて表示
            </Text>
          </div>
        </div>
        {mode === "combine" ? (
          <Stack gap={10}>
            <Text size="small" tone="secondary">
              1. 2つの部品を選ぶ
            </Text>
            {candidates.map((name) => {
              const on = picked.includes(name);
              return (
                <div
                  key={name}
                  onClick={() => togglePick(name)}
                  style={{
                    padding: 8,
                    borderRadius: 8,
                    cursor: "pointer",
                    border: `1px solid ${on ? t.stroke.primary : t.stroke.secondary}`,
                    background: on ? t.fill.secondary : t.fill.tertiary,
                  }}
                >
                  <Text size="small" weight={on ? "semibold" : "normal"}>
                    {on ? `${name}（選択）` : name}
                  </Text>
                </div>
              );
            })}
            <Text size="small" tone="secondary">
              2. どちらが F か
            </Text>
            <div style={{ display: "flex", gap: 8 }}>
              {picked.map((name) => (
                <div
                  key={`front-${name}`}
                  onClick={() => setFrontName(name)}
                  style={{
                    flex: 1,
                    padding: 10,
                    textAlign: "center",
                    borderRadius: 8,
                    cursor: "pointer",
                    border: `1px solid ${frontName === name ? t.stroke.primary : t.stroke.secondary}`,
                    background: frontName === name ? t.fill.secondary : t.fill.tertiary,
                  }}
                >
                  <Text size="small" weight={frontName === name ? "semibold" : "normal"}>
                    {name} が F
                  </Text>
                </div>
              ))}
            </div>
            <Text size="small" tone="secondary">
              3. まとめた名前
            </Text>
            <TextInput
              value={groupName}
              onChange={setGroupName}
              placeholder="タイヤ"
            />
            <Text size="small" tone="tertiary">
              ホームは「{groupName || "（名前）"}」。左が R、右が F
            </Text>
            <PhoneButton label="まとめて表示" variant="primary" onClick={() => go("home")} />
          </Stack>
        ) : (
          <Stack gap={10}>
            <Text>「タイヤ」のまとめ表示をやめます。各カードは登録名で出します。</Text>
            <Text size="small" tone="secondary">
              分かれたあとの表示（登録名）
            </Text>
            <Text weight="semibold">前タイヤ</Text>
            <Text weight="semibold">後タイヤ</Text>
            <Text size="small" tone="tertiary">
              登録名は変えない。末尾に F/R を付ける合わせこみはしない
            </Text>
            <PhoneButton label="分けて表示" variant="primary" onClick={() => go("home")} />
          </Stack>
        )}
        <PhoneButton label="キャンセル" variant="ghost" onClick={() => go("gear")} />
      </Stack>
    </Phone>
  );
}

function ImportCsvScreen({
  go,
  gear,
}: {
  go: (screen: ScreenId) => void;
  gear: string;
}) {
  return (
    <Phone title="記録の CSV" onBack={() => go("gear")}>
      <Stack gap={14}>
        <Text weight="semibold">{gear}（デモ）</Text>
        <Text size="small" tone="tertiary">
          このギアの交換記録だけを出し入れします。他のギアの記録はそのままです。
        </Text>
        <Text>入力欄に出してコピーします。</Text>
        <PhoneButton label="いまの記録を書き出す" variant="ghost" onClick={() => go("import-csv")} />
        <Text size="small" tone="secondary">
          いまの登録名
        </Text>
        <Text>前タイヤ、後タイヤ、チェーン、前ブレーキパッド、後ブレーキパッド、前ワイヤー、後ワイヤー、前ブレーキオイル、後ブレーキオイル、前ディスク、後ディスク、バーテープ、スピードセンサ電池、パワーセンサ電池、リモコン電池、心拍計電池、リヤライト電池、プーリー</Text>
        <Text size="small" tone="secondary">
          CSV
        </Text>
        <Text>
          登録名,交換日,メモ
          {"\n"}
          前タイヤ,2025-07-17,
          {"\n"}
          後タイヤ,2025-07-17,
          {"\n"}
          チェーン,2025-07-17,
          {"\n"}
          …
        </Text>
        <Text>部品は増えません。登録名（前タイヤ）で結びます。CSV に出た部品の、このギアの記録は差し替えます。</Text>
        <PhoneButton label="CSVを取り込み" variant="primary" onClick={() => go("import-csv")} />
        <Text size="small" tone="secondary">
          差し替え 1 件
        </Text>
        <Text>前タイヤ  2025-03-01  GP5000</Text>
        <PhoneButton label="取り込む" variant="primary" onClick={() => go("gear")} />
      </Stack>
    </Phone>
  );
}

function SyncScreen({ go }: { go: (screen: ScreenId) => void }) {
  return (
    <Phone title="Strava 同期" onBack={() => go("home")}>
      <Stack gap={14}>
        <Stack gap={4}>
          <Text size="small" tone="secondary">
            データの範囲
          </Text>
          <Text weight="semibold">Strava開始日  2025-07-17（デモ）</Text>
          <Text weight="semibold">何日まで  2026-07-15（デモ）</Text>
          <Text size="small" tone="tertiary">
            何日までは、Strava開始日以降で入っているいちばん新しい走行の日です。
          </Text>
        </Stack>
        <Text>期間を選んで取得します。自動では取りに行きません。</Text>
        <PhoneButton label="前回から 3 か月" variant="primary" onClick={() => go("home")} />
        <PhoneButton label="前回から 6 か月" variant="ghost" onClick={() => go("home")} />
        <PhoneButton label="前回から 1 年" variant="ghost" onClick={() => go("home")} />
        <div style={{ height: 16 }} />
        <Text size="small" tone="tertiary">
          Strava開始日を変えると、取り込んだ走行は消えて初期化されます。新しい日から取り直します。
        </Text>
        <PhoneButton label="Strava開始日を変更" variant="ghost" onClick={() => go("home")} />
      </Stack>
    </Phone>
  );
}

function StravaConnectScreen({ go }: { go: (screen: ScreenId) => void }) {
  return (
    <Phone title="Strava 連携" onBack={() => go("settings")}>
      <Stack gap={14}>
        <Stack gap={4}>
          <Text weight="semibold">未連携</Text>
        </Stack>
        <Stack gap={4}>
          <Text size="small" tone="secondary">
            Client ID
          </Text>
          <TextInput value="" onChange={() => undefined} placeholder="Strava のアプリ登録で発行される番号" />
        </Stack>
        <Stack gap={4}>
          <Text size="small" tone="secondary">
            Client Secret
          </Text>
          <TextInput value="" onChange={() => undefined} placeholder="Strava のアプリ登録で Show すると出る値" />
        </Stack>
        <PhoneButton label="連携する" variant="primary" onClick={() => go("strava")} />
        <PhoneButton label="連携を解除" variant="ghost" onClick={() => go("strava")} />
        <Stack gap={6}>
          <Text weight="semibold">連携方法</Text>
          <Text size="small">1. Strava の API 設定でアプリを作る（strava.com/settings/api）</Text>
          <Text size="small">2. Authorization Callback Domain は 127.0.0.1</Text>
          <Text size="small">3. Client ID と Client Secret を上に入れる。このアプリでは Access Token は使いません。</Text>
          <Text size="small">4. 「連携する」を押し、ブラウザで許可する</Text>
          <Text size="small">5. 戻らないときは、「連携する」のあとに出る欄へアドレス欄（code=）を貼る</Text>
        </Stack>
      </Stack>
    </Phone>
  );
}

function GearScreen({
  go,
  gear,
  onSelectGear,
}: {
  go: (screen: ScreenId) => void;
  gear: string;
  onSelectGear: (name: string) => void;
}) {
  const t = useHostTheme();
  return (
    <Phone title="ギア" onBack={() => go("home")}>
      <Stack gap={14}>
        <Stack gap={4}>
          <Text weight="semibold">{gear}（デモ）</Text>
          <Text size="small" tone="tertiary">
            Strava から取った自転車だけ選べます。部品の追加・設定、交換記録、CSV は選んだギアだけです。初期の部品は同じです。デモのあいだは部品の追加と記録の CSV は使えません。先に Strava を同期してください。
          </Text>
        </Stack>
        {GEARS.map((name) => {
          const selected = name === gear;
          return (
            <div
              key={name}
              onClick={() => onSelectGear(name)}
              style={{
                padding: 10,
                borderRadius: 8,
                border: `1px solid ${selected ? t.stroke.primary : t.stroke.secondary}`,
                background: selected ? t.fill.secondary : t.fill.tertiary,
                cursor: "pointer",
              }}
            >
              <Text size="small" weight={selected ? "semibold" : "normal"}>
                {selected ? `${name}（デモ・選択中）` : `${name}（デモ）`}
              </Text>
            </div>
          );
        })}
        <PhoneButton label="部品を追加" variant="primary" onClick={() => go("add")} />
        <PhoneButton label="記録の CSV" variant="ghost" onClick={() => go("import-csv")} />
        <PhoneButton label="表示をまとめる / 分ける" variant="ghost" onClick={() => go("split-merge")} />
      </Stack>
    </Phone>
  );
}

function SettingsScreen({
  go,
}: {
  go: (screen: ScreenId) => void;
}) {
  return (
    <Phone title="設定" onBack={() => go("home")}>
      <Stack gap={14}>
        <Stack gap={4}>
          <Text size="small" tone="secondary">
            Strava
          </Text>
          <Text weight="semibold">連携済み</Text>
          <Text size="small" tone="secondary">
            連携すると走行を取れます。手順は次の画面。
          </Text>
        </Stack>
        <PhoneButton label="Strava 連携" variant="primary" onClick={() => go("strava")} />
        <PhoneButton label="Strava同期" variant="ghost" onClick={() => go("sync")} />
        <Stack gap={4}>
          <Text size="small" tone="secondary">
            ギア
          </Text>
          <Text size="small" tone="tertiary">
            距離を足す自転車と、そのギアの交換記録です。
          </Text>
        </Stack>
        <PhoneButton label="ギア" variant="ghost" onClick={() => go("gear")} />
        <Stack gap={4}>
          <Text size="small" tone="secondary">
            初期化
          </Text>
          <Text size="small" tone="tertiary">
            Strava の連携と走行、部品の設定と交換記録を消し、初回と同じデモ状態に戻します。
          </Text>
        </Stack>
        <PhoneButton label="初期状態に戻す" variant="ghost" onClick={() => go("settings")} />
        <Text size="small" tone="tertiary">
          GearDoctor 1.0.0
        </Text>
      </Stack>
    </Phone>
  );
}

export default function GearDoctorUiWireframe() {
  const [screen, setScreen] = useCanvasState<ScreenId>("screen", "home");
  const [partId, setPartId] = useCanvasState("partId", "tire");
  const [position, setPosition] = useCanvasState<Position>("position", "front");
  const [gear, setGear] = useCanvasState("gear", "Aeroad");
  const [limitMode, setLimitMode] = useCanvasState<LimitMode>("limitMode", "recommended");
  const [cycleKind, setCycleKind] = useCanvasState<CycleKind>("cycleKind", "distance");
  const [historyRow, setHistoryRow] = useCanvasState<HistoryRow>("historyRow", {
    date: "2025-03-01",
    km: "4,800 km",
    memo: "GP5000",
  });
  const [editRecordDate, setEditRecordDate] = useCanvasState("editRecordDate", "2025-03-01");
  const [editRecordMemo, setEditRecordMemo] = useCanvasState("editRecordMemo", "GP5000");
  const customLimitKm = 5000;
  const recommendedKm = 6000;
  const customLimitMonths = 12;
  const recommendedMonths = 12;

  const go = (next: ScreenId, nextPart?: string, nextPosition?: Position) => {
    if (nextPart) setPartId(nextPart);
    if (nextPosition) setPosition(nextPosition);
    setScreen(next);
  };

  const phone =
    screen === "home" ? (
      <HomeScreen go={go} gear={gear} />
    ) : screen === "detail" ? (
      <DetailScreen
        partId={partId}
        position={position}
        go={go}
        limitMode={limitMode}
        customLimitKm={customLimitKm}
        customLimitMonths={customLimitMonths}
        onOpenRecord={(row) => {
          setHistoryRow(row);
          setEditRecordDate(row.date);
          setEditRecordMemo(row.memo);
          setScreen("edit-record");
        }}
      />
    ) : screen === "replace" ? (
      <ReplaceScreen
        partId={partId}
        position={position}
        go={go}
        onOpenRecord={(row) => {
          setHistoryRow(row);
          setEditRecordDate(row.date);
          setEditRecordMemo(row.memo);
          setScreen("edit-record");
        }}
      />
    ) : screen === "edit-record" ? (
      <EditRecordScreen
        partId={partId}
        position={position}
        row={historyRow}
        editDate={editRecordDate}
        editMemo={editRecordMemo}
        onChangeDate={setEditRecordDate}
        onChangeMemo={setEditRecordMemo}
        go={go}
      />
    ) : screen === "split-merge" ? (
      <SplitMergeScreen go={go} />
    ) : screen === "add" ? (
      <AddScreen
        go={go}
        cycleKind={cycleKind}
        onSelectCycle={setCycleKind}
        limitMode={limitMode}
        onSelectLimitMode={setLimitMode}
        recommendedKm={recommendedKm}
        customLimitKm={customLimitKm}
        recommendedMonths={recommendedMonths}
        customLimitMonths={customLimitMonths}
      />
    ) : screen === "sync" ? (
      <SyncScreen go={go} />
    ) : screen === "import-csv" ? (
      <ImportCsvScreen go={go} gear={gear} />
    ) : screen === "strava" ? (
      <StravaConnectScreen go={go} />
    ) : screen === "gear" ? (
      <GearScreen go={go} gear={gear} onSelectGear={setGear} />
    ) : (
      <SettingsScreen go={go} />
    );

  return (
    <Stack gap={20}>
      <Stack gap={8}>
        <H1>GearDoctor 画面案</H1>
        <Text tone="secondary">
          前後がある部品は、左が R・右が F です。表示は「F：余裕・45％」のように位置と状態を同じ行にします。
        </Text>
      </Stack>

      <Row gap={8} wrap>
        <Pill active={screen === "home"} onClick={() => setScreen("home")}>
          ホーム
        </Pill>
        <Pill active={screen === "detail"} onClick={() => setScreen("detail")}>
          部品の詳細
        </Pill>
        <Pill active={screen === "replace"} onClick={() => setScreen("replace")}>
          交換を記録
        </Pill>
        <Pill active={screen === "edit-record"} onClick={() => setScreen("edit-record")}>
          記録を編集
        </Pill>
        <Pill active={screen === "add"} onClick={() => setScreen("add")}>
          部品を追加
        </Pill>
        <Pill active={screen === "gear"} onClick={() => setScreen("gear")}>
          ギア
        </Pill>
        <Pill active={screen === "import-csv"} onClick={() => setScreen("import-csv")}>
          記録の CSV
        </Pill>
        <Pill active={screen === "split-merge"} onClick={() => setScreen("split-merge")}>
          表示のまとめ
        </Pill>
        <Pill active={screen === "sync"} onClick={() => setScreen("sync")}>
          同期
        </Pill>
        <Pill active={screen === "settings"} onClick={() => setScreen("settings")}>
          設定
        </Pill>
        <Pill active={screen === "strava"} onClick={() => setScreen("strava")}>
          Strava 連携
        </Pill>
      </Row>

      <Grid columns="320px minmax(0, 1fr)" gap={24} align="start">
        {phone}

        <Stack gap={16}>
          <H2>決まったこと</H2>
          <Text>
            下部タブなし。交換したは詳細画面。ホームの主ボタンは同期。部品は登録名だけで管理し、追加に F/R の種別は付けない。左右の合体は表示のまとめだけ。同期は自動ではなく、押したときだけ。デモのあいだは部品の追加と記録の CSV はエラーにし、先に Strava を同期する。
          </Text>
          <Table
            headers={["画面", "上から下", "横並び"]}
            rows={[
              ["ホーム", "デモ案内 → ギアと最終同期 → 警告 → 部品 → 同期", "ギア | 最終同期、R | F"],
              ["詳細", "距離 → バー → 交換日 → 操作 → 過去の交換記録", "交換した | 編集"],
              ["記録を編集", "日付 → メモ → 保存 → 削除", "なし（縦のみ）"],
              ["ギア", "大きなギア名 → 自転車の選択 → 部品追加 / CSV / まとめ", "なし（縦のみ）"],
              ["部品を追加", "登録名 → 周期 → 目安 → しきい値", "距離 | 月"],
              ["記録の CSV", "ギア名 → 書き出し → 貼り付け → CSVを取り込み", "なし（縦のみ）"],
              ["表示のまとめ", "2件選択 → どちらがF → 表示名", "なし（縦のみ）"],
              ["同期", "Strava開始日と何日まで → 期間の選択 → 取得", "なし（縦のみ）"],
              ["設定", "Strava 連携へ → Strava同期へ → ギアへ → 初期化 → バージョン", "なし（縦のみ）"],
              ["Strava 連携", "状態 → ID/Secret → 連携 → 解除 → 連携方法", "なし（縦のみ）"],
            ]}
          />

          <H2>前後の並べ方</H2>
          <Text>
            自転車を左から見て進行方向が右、という向きです。左が R、右が F。前と後ろは別々に交換・集計します。チェーンは分けません。
          </Text>

          <H3>交換周期</H3>
          <Callout tone="info" title="距離か月、排他">
            部品ごとに距離（km）か月、どちらか一方。しきい値は選んだ周期に対する％。日指定はしない。
          </Callout>

          <H3>交換目安</H3>
          <Callout tone="info" title="推奨・自動・設定">
            三つの数値を見せ、選んだ一方を使う。自動は直近の2回の間隔。毎回計算。
          </Callout>

          <H3>同期画面は未確定</H3>
          <Callout tone="warning" title="別途相談">
            期間は 3か月・6か月・1年・Strava開始日。失敗時の続きはまだ決めません。ギアはホームまたは設定から選びます。交換記録はギアごとです。
          </Callout>

          <Card>
            <CardHeader>最初の部品</CardHeader>
            <CardBody>
              <Stack gap={8}>
                <Stat value="18" label="初期の登録名（電池類は月、オイルは距離）" />
                <Divider />
                <Text size="small" tone="secondary">
                  前後をまとめ表示できる例: タイヤ、ブレーキパッド、ワイヤー。まとめない: チェーン。内部はすべて登録名の1件。
                </Text>
              </Stack>
            </CardBody>
          </Card>
        </Stack>
      </Grid>
    </Stack>
  );
}
