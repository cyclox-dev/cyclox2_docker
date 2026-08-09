/*
 * AJOCC 実績レポート 25-26版 ビルドスクリプト（物理15ページ）
 *
 * 【重要】数値ハードコード禁止:
 *   レポートに出る数値・ラベル・表の中身はすべて dataset_2526.json から読み込む。
 *   このスクリプト内の数値リテラルは、座標・色・フォントサイズ等のレイアウト定数のみ。
 *
 * 入力(読むだけ): .kiro/specs/ajocc-report-2025-26/dataset_2526.json
 * 出力: .kiro/specs/ajocc-report-2025-26/outputs/25-26_AJOCC_report.pptx
 *
 * Web両対応(決定#11): p3/p4/p14/p15 の Web値は placeholder/provisional/null。
 *   値が無ければ「実データ入手後更新（TBD）」表示、値があればその表・数値を描画する両対応。
 *   後日 JSON に Web 実データを入れて同一スクリプトを再実行すれば実表に変わる。
 */

const fs = require("fs");
const path = require("path");
const pptxgen = require("/Users/kyamady/workspace/cyclox2_docker/tmp/ppt_build/node_modules/pptxgenjs");

// ---- 入出力パス（絶対パス） ----
const SPEC_DIR = "/Users/kyamady/workspace/cyclox2_docker/.claude/worktrees/interesting-bouman-d5368b/.kiro/specs/ajocc-report-2025-26";
const DATA_PATH = path.join(SPEC_DIR, "dataset_2526.json");
const OUT_PATH = path.join(SPEC_DIR, "outputs", "25-26_AJOCC_report.pptx");

// ---- 数値の唯一の正: JSONを読む ----
const D = JSON.parse(fs.readFileSync(DATA_PATH, "utf8"));

// ---- レイアウト定数（数値でないブランド/座標定数のみ・ハードコード可） ----
const RED = "E2231A", INK = "1A1A1A", MUTE = "555555", LINE = "DDDDDD";
const BG = "FFFFFF", GRAY = "F2F2F2", HEAD = "EFE3E2";
const BF = "Meiryo", HF = "Meiryo";
const W = 13.3, H = 7.5;
// ---- 元資料24-25準拠の配色（G2）: グループ・カテゴリ・地域ヘッダーの色設計 ----
// シリーズ3区分（P5A/P6/P7/P9）: JCX=オレンジ / ローカル=シアン青 / 全体=緑
const G_JCX = "ED7D31", G_LOCAL = "4BACC6", G_ALL = "70AD47";
// 汎用ヘッダー（列見出し・地域名バンド）: 青
const HB = "4472C4"; // header blue（白抜き文字）
const HW = "FFFFFF"; // header white text
// セグメント色（P8/P10/P11の大分類バンド。元資料準拠）
const SEG = {
  "男子実力別": "ED7D31", "女子": "8064A2", "男子14〜18歳": "70AD47",
  "男子マスターズ": "4472C4", "小学生": "31A2C4", "その他": "808080",
};
// 網掛け（最多年・最多セル）: グループ別の淡色（元資料P.5の網掛けに整合）
const SH_ORANGE = "FCE4D6", SH_BLUE = "DDEBF7", SH_GREEN = "E2EFDA", SH_PEACH = "FCE4D6";
// コホート三角の対角（新規セル）網掛け
const SH_DIAG = "DDEBF7";
// グラフ系列色（レイアウト定数）
const C_ENTRY = "ED7D31", C_ME1 = "4BACC6", C_WE1 = "8064A2", C_OTHER = "9BBB59";
const C_LINE = "1F4E79", C_MALE = "31A2C4", C_FEMALE = "8064A2";
const PIE_COLORS = ["4BACC6","ED7D31","70AD47","8064A2","9BBB59","4472C4","F0A500","C0504D","31A2C4","8C8C8C","D99694","B3A2C7","C3D69B","FAC090","95B3D7","D7E4BC","E2231A"];

const p = new pptxgen();
p.layout = "LAYOUT_WIDE";
p.author = "AJOCC";
p.title = D.meta.title_cover;

// ---- 数値フォーマット ----
const nf = (v) => (v == null ? "" : Number(v).toLocaleString("en-US"));
// 日付フォーマット: YYYY-MM-DD → YYYY/MM/DD（P8）。レイアウト定数扱い。
const dfmt = (isoDate) => {
  if (!isoDate) return "";
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(isoDate);
  return m ? `${m[1]}/${m[2]}/${m[3]}` : isoDate;
};
const sf = (v, unit) => (v == null ? "" : nf(v) + (unit || ""));
// 前年度比: +/- 記号付き
const df = (v, unit) => {
  if (v == null) return "";
  const s = v > 0 ? "+" + nf(v) : nf(v);
  return s + (unit || "");
};

// ================= 共通フレーム =================
function footer(s) {
  s.addShape(p.shapes.RECTANGLE, { x: 0, y: H - 0.36, w: W, h: 0.36, fill: { color: RED } });
  s.addText("ＡＪＯＣＣ　一般社団法人日本シクロクロス競技主催者協会",
    { x: 0, y: H - 0.36, w: W, h: 0.36, align: "center", valign: "middle", fontFace: BF, fontSize: 11, color: "FFFFFF", bold: true });
}
function logo(s, x, y, sz) {
  s.addText([{ text: "A", options: { color: INK } }, { text: "J", options: { color: RED } }, { text: "OCC", options: { color: INK } }],
    { x: x, y: y, w: 1.8, h: 0.5, fontFace: HF, fontSize: sz, bold: true, align: "right" });
}
function header(s, txt) {
  s.addShape(p.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: 0.06, fill: { color: RED } });
  s.addText(txt, { x: 0.35, y: 0.16, w: 10.8, h: 0.5, fontFace: HF, fontSize: 20, bold: true, color: INK });
  s.addShape(p.shapes.LINE, { x: 0.35, y: 0.70, w: 4.6, h: 0, line: { color: RED, width: 3 } });
  logo(s, 11.3, 0.13, 22);
}
function pageNum(s, n) {
  s.addText("P." + n, { x: W - 1.0, y: H - 0.75, w: 0.8, h: 0.35, align: "right", fontFace: BF, fontSize: 10, color: MUTE });
}
function newSlide(titleTxt, n) {
  const s = p.addSlide();
  s.background = { color: BG };
  header(s, titleTxt);
  footer(s);
  pageNum(s, n);
  return s;
}
function tbl(s, x, y, w, rows, opts = {}) {
  s.addTable(rows, Object.assign(
    { x, y, w, fontFace: BF, fontSize: opts.fs || 10, valign: "middle",
      border: { type: "solid", color: LINE, pt: 0.75 }, autoPage: false, color: INK }, opts));
}
// 見出しセル
function hcell(text, colspan) {
  const o = { bold: true, fill: { color: GRAY } };
  if (colspan) o.colspan = colspan;
  return { text, options: o };
}
// 列見出し行セル（元資料準拠: 青地・白抜き）
function thcell(text) { return { text, options: { bold: true, fill: { color: HB }, color: HW, align: "center" } }; }
// 任意色ヘッダーセル（グループ/カテゴリ/地域の色分け。白抜き文字）
function chcell(text, color, extra) {
  return { text, options: Object.assign({ bold: true, fill: { color }, color: HW, align: "center" }, extra || {}) };
}
// 行ラベル色バンド（左端の見出しセル。白抜き）
function lcell(text, color, extra) {
  return { text, options: Object.assign({ bold: true, fill: { color }, color: HW, align: "left" }, extra || {}) };
}

// ================= P.1 表紙 =================
{
  const s = p.addSlide();
  s.background = { color: BG };
  s.addText([{ text: "A", options: { color: INK } }, { text: "J", options: { color: RED } }, { text: "OCC", options: { color: INK } }],
    { x: 0, y: 1.0, w: W, h: 1.6, align: "center", fontFace: HF, fontSize: 64, bold: true });
  s.addShape(p.shapes.LINE, { x: 4.15, y: 2.85, w: 5.0, h: 0, line: { color: RED, width: 3 } });
  s.addText(D.meta.title_cover, { x: 0, y: 3.1, w: W, h: 1.0, align: "center", fontFace: HF, fontSize: 34, bold: true, color: INK });
  s.addText(D.meta.created_month_label, { x: 0, y: 5.3, w: W, h: 0.5, align: "center", fontFace: BF, fontSize: 16, color: MUTE });
  footer(s);
}

// ================= P.2 目次 =================
{
  const s = newSlide("目次", 2);
  // 見出し番号は各ページの heading から機械的に構成（#10: 「6. AJOCC Web 閲覧数」）
  const items = [
    { t: D.p3.heading, sub: false },
    { t: D.p4.heading, sub: false },
    { t: "3. エントリー件数推移", sub: false },
    { t: "└ 全体と JCX", sub: true },
    { t: "└ AJOCC 全体", sub: true },
    { t: "└ JCX", sub: true },
    { t: "└ ローカル大会", sub: true },
    { t: "└ カテゴリー別", sub: true },
    { t: D.p11.heading.replace(/：.*$/, "").replace(/^4\..*/, "4. 参加者数"), sub: false },
    { t: "5. 新規参加者数", sub: false },
    { t: D.p14.heading, sub: false },
  ];
  // 6項目(内サブ5項目)=11行を1ページ(フッター上端7.14)に収める。行間・フォントを調整。
  s.addText(items.map(it => ({
    text: (it.sub ? "    " : "") + it.t + "\n",
    options: { fontSize: it.sub ? 12.5 : 15, bold: !it.sub, color: INK, breakLine: true }
  })), { x: 1.0, y: 0.95, w: 11, h: 5.8, fontFace: BF, valign: "top", lineSpacingMultiple: 1.15 });
}

// ================= P.3 シーズンまとめ =================
{
  const s = newSlide(D.p3.heading, 3);
  const rows = [];
  const addBlock = (title, rowsArr) => {
    rows.push([hcell(title, 3)]);
    rowsArr.forEach(r => {
      const note = r.note ? r.note : (r.provisional ? "（仮値）" : "");
      // Web両対応: provisional/placeholder のときは note に TBD 補足
      rows.push([
        { text: r.label, options: { align: "left" } },
        { text: sf(r.value, r.unit), options: { align: "right", bold: true } },
        { text: note || "", options: { align: "left", fontSize: 10.5, color: MUTE } },
      ]);
    });
  };
  addBlock("■開催実績", D.p3.kaisai_jisseki.rows);
  addBlock("■エントリー件数", D.p3.entry_kensu.rows);
  addBlock("■選手数", D.p3.senshu_su.rows);
  // Web閲覧数: provisional/placeholder 両対応
  rows.push([hcell("■web 閲覧数", 3)]);
  D.p3.web_view.rows.forEach(r => {
    const hasVal = r.value != null && r.provisional !== true && r.placeholder !== true;
    const valText = hasVal ? sf(r.value, r.unit)
      : (r.value != null ? sf(r.value, r.unit) + "（仮値）" : "実データ入手後更新（TBD）");
    const noteText = hasVal ? (r.note || "")
      : (r.value != null ? (r.note || "") : "実データ未入手のため未確定（TBD）");
    rows.push([
      { text: r.label, options: { align: "left" } },
      { text: valText, options: { align: "right", bold: true, color: r.provisional || r.placeholder ? MUTE : INK } },
      { text: noteText, options: { align: "left", fontSize: 10.5, color: MUTE } },
    ]);
  });
  tbl(s, 0.5, 0.95, 12.3, rows, { fs: 11, colW: [3.4, 2.4, 6.5], rowH: 0.28 });
  s.addText("※月平均ビュー数はGA実データ（2026-07-19反映）。ページ別内訳（P.14/P.15）は一部項目が実データ入手後更新予定（決定#1・#11）。",
    { x: 0.5, y: 6.55, w: 9, h: 0.35, fontFace: BF, fontSize: 10.5, italic: true, color: MUTE });
}

// ================= P.4 前年度との比較 =================
{
  const s = newSlide(D.p4.heading, 4);
  const yrHead = () => [thcell(""), thcell("2023-2024"), thcell("2024-2025"), thcell("2025-2026"), thcell("前年度比")];
  const rows = [];
  const addBlock = (block) => {
    rows.push([hcell(block.block, 5)]);
    rows.push(yrHead());
    block.rows.forEach(r => {
      const isProv = r.provisional === true;
      const y2526 = isProv ? (r.y2526 != null ? nf(r.y2526) + (r.unit || "") + "（仮）" : "TBD") : sf(r.y2526, r.unit);
      rows.push([
        { text: r.label, options: { align: "left" } },
        { text: sf(r.y2324, r.unit), options: { align: "right" } },
        { text: sf(r.y2425, r.unit), options: { align: "right" } },
        { text: y2526, options: { align: "right", bold: true } },
        { text: (r.yoy_delta != null ? df(r.yoy_delta, r.unit) : "") + (isProv ? "（暫定）" : ""),
          options: { align: "right", color: (r.yoy_delta != null && r.yoy_delta < 0) ? RED : INK } },
      ]);
    });
  };
  addBlock(D.p4.kaisai_jisseki);
  addBlock(D.p4.entry_kensu);
  addBlock(D.p4.senshu_su);
  addBlock(D.p4.web_view);
  tbl(s, 0.5, 0.92, 12.3, rows, { fs: 10.5, colW: [3.3, 2.25, 2.25, 2.25, 2.25], rowH: 0.2 });
  s.addText("※Web閲覧数の25-26はGA実データ（2026-07-19反映）。23-24/24-25はPDF転記。",
    { x: 0.5, y: 6.9, w: 9, h: 0.3, fontFace: BF, fontSize: 10, italic: true, color: MUTE });
}

// ================= P.5 表A(AJOCC年度別×シリーズ) + 表B(全日本) =================
{
  const s = newSlide("3. エントリー件数推移（表A・表B）", 5);
  // フッター上端 y=H-0.36=7.14。両表がこれより上に収まるよう縦配分を圧縮する。

  // ---- 表A（年度別×シリーズ：2ヘッダ + 13データ = 15行） ----
  s.addText("■AJOCC エントリー数推移（年度別×シリーズ区分）",
    { x: 0.3, y: 0.74, w: 9, h: 0.24, fontFace: BF, fontSize: 12, bold: true, color: INK });
  // 2段ヘッダ: グループ見出し（G2: JCX=橙/ローカル=シアン/全体=緑・白抜き） + 5列見出し×3
  const grpHead = [
    { text: "年度", options: { rowspan: 2, bold: true, fill: { color: RED }, color: HW, valign: "middle", align: "center", fontSize: 8.5 } },
    { text: "JCXシリーズ", options: { colspan: 5, bold: true, fill: { color: G_JCX }, color: HW, align: "center", fontSize: 9 } },
    { text: "ローカル大会", options: { colspan: 5, bold: true, fill: { color: G_LOCAL }, color: HW, align: "center", fontSize: 9 } },
    { text: "AJOCC全体", options: { colspan: 5, bold: true, fill: { color: G_ALL }, color: HW, align: "center", fontSize: 9 } },
  ];
  const sub = ["大会数", "エントリー数", "平均", "ME1", "ME1平均"];
  const subHead = [];
  for (let g = 0; g < 3; g++) sub.forEach(x => subHead.push({ text: x, options: { bold: true, fill: { color: GRAY }, align: "center", fontSize: 8 } }));
  const grpKeys = ["JCX", "local", "all"];
  // 各グループ×各指標の最多年を算出（網掛け用）。全historical + row_2526で判定。
  const aAllRows = D.p5a.historical.rows.concat([Object.assign({ year: "2025-2026" }, D.p5a.row_2526)]);
  const metricKeys = ["meets", "entries", "avg", "ME1", "ME1_avg"];
  const aMaxIdx = {}; // aMaxIdx[grp][metric] = 最多行index
  grpKeys.forEach(k => {
    aMaxIdx[k] = {};
    metricKeys.forEach(mk => {
      let bi = 0, bv = -Infinity;
      aAllRows.forEach((r, i) => { const v = r[k][mk]; if (v != null && v > bv) { bv = v; bi = i; } });
      aMaxIdx[k][mk] = bi;
    });
  });
  const grpShade = { JCX: SH_ORANGE, local: SH_BLUE, all: SH_GREEN };
  const mkRow = (yearLabel, obj, rowIdx, isCur) => {
    const cells = [{ text: yearLabel, options: { align: "center", bold: isCur, fontSize: 8.5, fill: isCur ? { color: GRAY } : undefined } }];
    grpKeys.forEach(k => {
      const g = obj[k];
      metricKeys.forEach((mk) => {
        const v = g[mk];
        const isMax = aMaxIdx[k][mk] === rowIdx;
        cells.push({ text: (typeof v === "number" && !Number.isInteger(v)) ? v.toFixed(1) : nf(v),
          options: { align: "right", fontSize: 8.5, bold: isCur || isMax, fill: isMax ? { color: grpShade[k] } : undefined } });
      });
    });
    return cells;
  };
  const aRows = [grpHead, subHead];
  D.p5a.historical.rows.forEach((r, i) => aRows.push(mkRow(r.year, r, i, false)));
  aRows.push(mkRow("2025-2026", D.p5a.row_2526, aAllRows.length - 1, true));
  tbl(s, 0.3, 1.0, 12.7, aRows, { fs: 8.5, colW: (() => {
    const cw = [1.0];
    for (let i = 0; i < 15; i++) cw.push((12.7 - 1.0) / 15);
    return cw;
  })(), rowH: 0.15, align: "right", valign: "middle", margin: 0.02 });
  s.addText("ME1=C1+UCIME。大会数は多大会統合後。網掛け=各シリーズ×指標の最多年。太字=当年度(2025-2026)。",
    { x: 0.3, y: 3.95, w: 12.7, h: 0.2, fontFace: BF, fontSize: 8.5, italic: true, color: MUTE });

  // ---- 表B: 全日本選手権（1ヘッダ + 12過去 + 1当年 = 14行） ----
  s.addText("■全日本選手権エントリー数推移（年×会場×カテゴリー）",
    { x: 0.3, y: 4.2, w: 9, h: 0.24, fontFace: BF, fontSize: 12, bold: true, color: INK });
  const bcols = D.p5b.historical.columns; // year,venue,entries_total, ME.. WM
  const catKeys = bcols.slice(3);
  // カテゴリ別ヘッダー色（元資料P.5B準拠: 会場=青/ME=橙/MU=青/MJ=緑/WE=紫/MM,WM=青系）
  const catHeadColor = {
    year: RED, venue: HB, entries_total: HB,
    ME: G_JCX, MU23: HB, MJ: G_ALL, MU17: "8064A2", MU15: G_LOCAL,
    WE: "8064A2", WJ: HB, WU17: "8064A2", WU15: G_LOCAL, MM: HB, WM: HB,
  };
  const bColLabel = { year: "年", venue: "会場", entries_total: "エントリー数" };
  const bHead = bcols.map(c => chcell(bColLabel[c] || c, catHeadColor[c] || HB, { fontSize: 8.5 }));
  // カテゴリ別最多年（p5b.category_max_year）。historical yearとevent_2526('2025')で照合し網掛け。
  const maxYear = D.p5b.category_max_year || {};
  const bRows = [bHead];
  D.p5b.historical.rows.forEach(r => {
    const cells = [
      { text: r.year, options: { align: "center", fontSize: 8.5 } },
      { text: r.venue, options: { align: "left", fontSize: 8 } },
      { text: nf(r.entries_total), options: { align: "right", fontSize: 8.5, bold: true } },
    ];
    catKeys.forEach(k => {
      const v = r.categories[k];
      const isMax = maxYear[k] === r.year && v != null;
      cells.push({ text: v == null ? "-" : nf(v), options: { align: "right", fontSize: 8.5, bold: isMax, fill: isMax ? { color: SH_PEACH } : undefined } });
    });
    bRows.push(cells);
  });
  // 当年 25-26 行（event_2526）を追加
  const e = D.p5b.event_2526;
  const curCells = [
    { text: e.year, options: { align: "center", fontSize: 8.5, bold: true, fill: { color: GRAY } } },
    { text: e.venue.replace(/（.*）/, ""), options: { align: "left", fontSize: 8, bold: true, fill: { color: GRAY } } },
    { text: nf(e.entries_total), options: { align: "right", fontSize: 8.5, bold: true, fill: { color: GRAY } } },
  ];
  catKeys.forEach(k => {
    const v = e.categories[k];
    const isMax = maxYear[k] === e.year && v != null;
    curCells.push({ text: v == null ? "-" : nf(v),
      options: { align: "right", fontSize: 8.5, bold: true, fill: { color: isMax ? SH_PEACH : GRAY } } });
  });
  bRows.push(curCells);
  const bcw = [0.6, 1.4, 1.0];
  for (let i = 0; i < catKeys.length; i++) bcw.push((12.7 - 3.0) / catKeys.length);
  tbl(s, 0.3, 4.46, 12.7, bRows, { fs: 8.5, colW: bcw, rowH: 0.135, valign: "middle", margin: 0.02 });
  s.addText("*シングルスピード等併催含む。ME=UCIME等、MM=MM35..MM70合算。網掛け=各カテゴリ最多年。当年(" + e.year + " " + e.venue.replace(/（.*）/, "") + "/" + nf(e.entries_total) + ")は最下段。",
    { x: 0.3, y: 6.98, w: 12.7, h: 0.16, fontFace: BF, fontSize: 8, italic: true, color: MUTE });
}

// ================= P.6 複合グラフ2 + 前年比較3表 + 所見 =================
{
  const s = newSlide(D.p6.heading, 6);
  // データ: p5a.historical + p5a.row_2526
  const years = D.p5a.historical.rows.map(r => r.year.replace("20", "").replace("-", "-"));
  years.push("2025-2026".replace("20", "").replace("-", "-"));
  const shortY = D.p5a.historical.rows.map(r => r.year.slice(2)).concat([D.p5a.row_2526 ? "25-26" : ""]);
  const getSeries = (grp, field) => D.p5a.historical.rows.map(r => r[grp][field]).concat([D.p5a.row_2526[grp][field]]);

  // ---- 左上: AJOCC全体 複合（棒:entries + 積上ME1, 折線:meets 右軸） ----
  s.addText(D.p6.charts.ajocc_overall.title, { x: 0.4, y: 0.85, w: 6.2, h: 0.3, fontFace: BF, fontSize: 11, bold: true, color: INK });
  s.addChart([
    { type: p.charts.BAR, data: [
      { name: "エントリー数", labels: shortY, values: getSeries("all", "entries") },
      { name: "ME1", labels: shortY, values: getSeries("all", "ME1") },
    ], options: { barGrouping: "stacked", chartColors: [C_ENTRY, C_ME1] } },
    { type: p.charts.LINE, data: [
      { name: "大会数", labels: shortY, values: getSeries("all", "meets") },
    ], options: { secondaryValAxis: true, secondaryCatAxis: true, chartColors: [C_LINE], lineSize: 2, lineDataSymbol: "circle" } },
  ], {
    x: 0.35, y: 1.15, w: 6.4, h: 2.9, showLegend: true, legendPos: "b", legendFontSize: 9.5,
    catAxisLabelFontSize: 8.5, valAxisLabelFontSize: 8.5,
    valAxes: [
      { valAxisMaxVal: 26000, valAxisMinVal: 0, valAxisLabelFontSize: 8.5 },
      { valAxisMaxVal: 80, valAxisMinVal: 0, valAxisLabelFontSize: 8.5 },
    ],
    catAxes: [{ catAxisLabelFontSize: 7.5 }, { catAxisHidden: true }],
  });

  // ---- 左下: JCX 複合（棒:entries + 積上ME1 + WE1(近似), 折線:meets 右軸） ----
  s.addText(D.p6.charts.jcx.title, { x: 0.4, y: 4.05, w: 6.2, h: 0.3, fontFace: BF, fontSize: 11, bold: true, color: INK });
  s.addChart([
    { type: p.charts.BAR, data: [
      { name: "エントリー数", labels: shortY, values: getSeries("JCX", "entries") },
      { name: "ME1", labels: shortY, values: getSeries("JCX", "ME1") },
    ], options: { barGrouping: "stacked", chartColors: [C_ENTRY, C_ME1] } },
    { type: p.charts.LINE, data: [
      { name: "大会数", labels: shortY, values: getSeries("JCX", "meets") },
    ], options: { secondaryValAxis: true, secondaryCatAxis: true, chartColors: [C_LINE], lineSize: 2, lineDataSymbol: "circle" } },
  ], {
    x: 0.35, y: 4.35, w: 6.4, h: 2.6, showLegend: true, legendPos: "b", legendFontSize: 9.5,
    valAxes: [
      { valAxisMaxVal: 7000, valAxisMinVal: 0, valAxisLabelFontSize: 8.5 },
      { valAxisMaxVal: 15, valAxisMinVal: 0, valAxisLabelFontSize: 8.5 },
    ],
    catAxes: [{ catAxisLabelFontSize: 7.5 }, { catAxisHidden: true }],
  });

  // ---- 右側: 前年比較3小表 ----
  const ct = D.p6.compare_tables;
  const mkCmp = (title, obj, hcolor) => {
    const rows = [
      [{ text: title, options: { colspan: 6, bold: true, fill: { color: hcolor }, color: HW, align: "center", fontSize: 10.5 } }],
      ["年度", "大会数", "エントリー数", "平均", "ME1", "ME1平"].map(t => ({ text: t, options: { bold: true, fill: { color: GRAY }, align: "center", fontSize: 9 } })),
    ];
    const line = (lbl, o) => [{ text: lbl, options: { align: "center", fontSize: 9.5 } }].concat(
      [o.meets, o.entries, o.avg, o.ME1, o.ME1_avg].map(v => ({ text: (typeof v === "number" && !Number.isInteger(v)) ? v.toFixed(1) : nf(v), options: { align: "right", fontSize: 9.5 } })));
    rows.push(line("2024-2025", obj.y2425));
    rows.push(line("2025-2026", obj.y2526));
    rows.push([{ text: "比較", options: { align: "center", fontSize: 9.5, bold: true, fill: { color: GRAY } } }].concat(
      [obj.compare.meets, obj.compare.entries, obj.compare.avg, obj.compare.ME1, obj.compare.ME1_avg].map(v =>
        ({ text: (typeof v === "number" && !Number.isInteger(v)) ? df(Number(v.toFixed(1))) : df(v), options: { align: "right", fontSize: 9.5, bold: true, color: (v < 0 ? RED : INK), fill: { color: GRAY } } }))));
    return rows;
  };
  tbl(s, 7.0, 0.95, 6.0, mkCmp("JCXシリーズ", ct.JCX, G_JCX), { fs: 9.5, colW: [1.1, 0.98, 0.98, 0.98, 0.98, 0.98], rowH: 0.16 });
  tbl(s, 7.0, 2.6, 6.0, mkCmp("ローカル大会", ct.local, G_LOCAL), { fs: 9.5, colW: [1.1, 0.98, 0.98, 0.98, 0.98, 0.98], rowH: 0.16 });
  tbl(s, 7.0, 4.25, 6.0, mkCmp("AJOCC全体", ct.all, G_ALL), { fs: 9.5, colW: [1.1, 0.98, 0.98, 0.98, 0.98, 0.98], rowH: 0.16 });

  // ---- 右下: 所見（3小表の直下・フッター上に収める） ----
  s.addText(D.p6.comments.map(c => ({ text: "・" + c + "\n", options: { breakLine: true } })),
    { x: 7.05, y: 5.98, w: 6.0, h: 1.1, fontFace: BF, fontSize: 7.5, color: INK, valign: "top", lineSpacingMultiple: 1.0 });
}

// ================= P.7 円グラフ2 + シリーズ×カテゴリ大表 + 地方集約 =================
{
  const s = newSlide(D.p7.heading, 7);
  const sct = D.p7.series_category_table;

  // ---- 左円: シリーズ別割合（total） ----
  s.addText("シリーズ別エントリー数割合", { x: 0.4, y: 0.82, w: 4, h: 0.3, fontFace: BF, fontSize: 10, bold: true, color: INK });
  s.addChart(p.charts.PIE,
    [{ name: "シリーズ別", labels: sct.rows.map(r => r.region), values: sct.rows.map(r => r.total) }],
    { x: 0.2, y: 1.1, w: 3.7, h: 2.5, showLegend: true, legendPos: "r", legendFontSize: 6, chartColors: PIE_COLORS, showPercent: true, dataLabelFontSize: 6, dataLabelColor: "FFFFFF" });

  // ---- 右円: 地方ブロック別割合 ----
  s.addText("地域別エントリー数割合", { x: 4.5, y: 0.82, w: 4, h: 0.3, fontFace: BF, fontSize: 10, bold: true, color: INK });
  const rb = D.p7.region_block_table.rows;
  s.addChart(p.charts.PIE,
    [{ name: "地域別", labels: rb.map(r => r.block), values: rb.map(r => r.total) }],
    { x: 4.3, y: 1.1, w: 3.7, h: 2.5, showLegend: true, legendPos: "r", legendFontSize: 6, chartColors: PIE_COLORS, showPercent: true, dataLabelFontSize: 6, dataLabelColor: "FFFFFF" });

  // ---- 右: 地方ブロック集約表 ----
  const rbRows = [
    [thcell("地方ブロック"), thcell("合計"), thcell("前年度比")],
  ];
  rb.forEach(r => rbRows.push([
    { text: r.block, options: { align: "left", fontSize: 9 } },
    { text: nf(r.total), options: { align: "right", fontSize: 9 } },
    { text: df(r.yoy_delta), options: { align: "right", fontSize: 9, color: (r.yoy_delta < 0 ? RED : INK) } },
  ]));
  tbl(s, 8.4, 1.1, 4.6, rbRows, { fs: 9, colW: [2.0, 1.3, 1.3], rowH: 0.17 });
  s.addText("関東=茨城+千葉+野田+東京+湘南+前橋+宇都宮 / 中国=もみじ+山口+中国",
    { x: 8.4, y: 3.52, w: 4.6, h: 0.4, fontFace: BF, fontSize: 8, italic: true, color: MUTE });

  // ---- 下: シリーズ別×カテゴリ大表（region行 + 合計） ----
  s.addText("シリーズ別×カテゴリー別エントリー数", { x: 0.3, y: 3.7, w: 8, h: 0.3, fontFace: BF, fontSize: 11, bold: true, color: INK });
  const rows = D.p7.series_category_table.rows;
  const head = [thcell("シリーズ")].concat(["ME1", "WE1", "その他", "合計"].map(thcell));
  const bigRows = [head];
  rows.forEach(r => bigRows.push([
    { text: r.region, options: { align: "left", fontSize: 9.5 } },
    { text: nf(r.ME1), options: { align: "right", fontSize: 9.5 } },
    { text: nf(r.WE1), options: { align: "right", fontSize: 9.5 } },
    { text: nf(r.other), options: { align: "right", fontSize: 9.5 } },
    { text: nf(r.total), options: { align: "right", fontSize: 9.5, bold: true } },
  ]));
  const gt = sct.grand_total;
  bigRows.push([
    { text: "合計", options: { align: "left", fontSize: 9.5, bold: true, fill: { color: GRAY } } },
    { text: nf(gt.ME1), options: { align: "right", fontSize: 9.5, bold: true, fill: { color: GRAY } } },
    { text: nf(gt.WE1), options: { align: "right", fontSize: 9.5, bold: true, fill: { color: GRAY } } },
    { text: nf(gt.other), options: { align: "right", fontSize: 9.5, bold: true, fill: { color: GRAY } } },
    { text: nf(gt.total), options: { align: "right", fontSize: 9.5, bold: true, fill: { color: GRAY } } },
  ]);
  // 2列に分けて縦長を回避（17地域+合計=18行 → 9行ずつ2ブロック）
  const half = Math.ceil((bigRows.length - 1) / 2);
  const left = [head].concat(bigRows.slice(1, 1 + half));
  const right = [head].concat(bigRows.slice(1 + half));
  tbl(s, 0.3, 4.05, 6.2, left, { fs: 9.5, colW: [1.9, 1.05, 1.05, 1.1, 1.1], rowH: 0.19 });
  tbl(s, 6.8, 4.05, 6.2, right, { fs: 9.5, colW: [1.9, 1.05, 1.05, 1.1, 1.1], rowH: 0.19 });
  s.addText("能登はDBに存在せず25-26では非掲載。ME1=C1+UCIME, WE1=CL1+UCIWE。",
    { x: 0.3, y: 6.95, w: 12, h: 0.25, fontFace: BF, fontSize: 8.5, italic: true, color: MUTE });
}

// ================= P.8 JCXカテゴリ表(24列) + 積み上げ棒(24系列) =================
{
  const s = newSlide(D.p8.heading, 8);
  const cats = D.p8.columns; // 24 category codes
  const meets = D.p8.meets;

  // ---- 表: 大会別×カテゴリ ----
  const head = [thcell("大会名"), thcell("開催日")].concat(cats.map(c => chcell(c, HB, { fontSize: 7 }))).concat([thcell("計")]);
  const rows = [head];
  meets.forEach(m => {
    const cells = [
      { text: m.meet_label, options: { align: "left", fontSize: 7.5 } },
      // G/P8修正: date(YYYY-MM-DD)からYYYY/MM/DD西暦付きで表示
      { text: dfmt(m.date || m.at_date), options: { align: "center", fontSize: 7 } },
    ];
    cats.forEach(c => cells.push({ text: nf(m.values[c]), options: { align: "right", fontSize: 7 } }));
    cells.push({ text: nf(m.total), options: { align: "right", fontSize: 7.5, bold: true } });
    rows.push(cells);
  });
  // 合計行
  const ctot = D.p8.category_totals;
  const totCells = [{ text: "合計", options: { align: "left", fontSize: 7.5, bold: true, fill: { color: GRAY } } }, { text: "—", options: { align: "center", fontSize: 7, fill: { color: GRAY } } }];
  cats.forEach(c => totCells.push({ text: nf(ctot[c]), options: { align: "right", fontSize: 7, bold: true, fill: { color: GRAY } } }));
  totCells.push({ text: nf(D.p8.grand_total), options: { align: "right", fontSize: 7.5, bold: true, fill: { color: GRAY } } });
  rows.push(totCells);
  // 列幅: 大会1.3 日0.85 + 24カテゴリ + 合計0.6（日付が西暦付で広がるため会場/日列を拡幅）
  const cw = [1.3, 0.85];
  const catW = (13.0 - 1.3 - 0.85 - 0.6) / cats.length;
  for (let i = 0; i < cats.length; i++) cw.push(catW);
  cw.push(0.6);
  tbl(s, 0.15, 0.85, 13.0, rows, { fs: 7, colW: cw, rowH: 0.14 });

  // ---- 積み上げ棒(24系列): 大会別 ----
  s.addText("カテゴリー別エントリー数（JCX大会別・24系列積み上げ）", { x: 0.3, y: 3.98, w: 9, h: 0.3, fontFace: BF, fontSize: 11, bold: true, color: INK });
  const labels = meets.map(m => m.meet_label);
  const series = cats.map(c => ({ name: c, labels: labels, values: meets.map(m => m.values[c]) }));
  // 24系列色（PIE_COLORSを循環）
  const chartColors = cats.map((_, i) => PIE_COLORS[i % PIE_COLORS.length]);
  s.addChart(p.charts.BAR, series, {
    x: 0.3, y: 4.3, w: 12.7, h: 2.45, barGrouping: "stacked", chartColors: chartColors,
    showLegend: true, legendPos: "b", legendFontSize: 6,
    catAxisLabelFontSize: 8, valAxisLabelFontSize: 8, valAxisMinVal: 0,
  });
  s.addText("多大会統合: 宇都宮=12/06+12/07, お台場=02/07+02/08。",
    { x: 0.3, y: 6.9, w: 12, h: 0.25, fontFace: BF, fontSize: 8, italic: true, color: MUTE });
}

// ================= P.9 ローカル地域別 実数+平均 + 複合グラフ =================
{
  const s = newSlide(D.p9.heading, 9);
  // 決定#12: 地域を北→南西順に並べ替え（region_orderがあればそれを使用。数値はJSON由来）
  const p9order = Array.isArray(D.p9.region_order) ? D.p9.region_order
    : ["東北","前橋","茨城","千葉","野田","東京","湘南","信州","東海","北陸","関西","中国","もみじ","山口","四国","九州"];
  const rows = p9order
    .map(rn => D.p9.rows.find(r => r.region === rn))
    .filter(Boolean)
    .concat(D.p9.rows.filter(r => !p9order.includes(r.region)));
  const gt = D.p9.grand_total;

  // ---- 表: 地域別（大会数/ME1/WE1/その他/合計 + 平均4列） ----
  const head = [thcell("地域"), thcell("大会"), thcell("ME1"), thcell("WE1"), thcell("その他"), thcell("合計"),
    thcell("平均計"), thcell("平ME1"), thcell("平WE1"), thcell("平他")];
  const trows = [head];
  rows.forEach(r => trows.push([
    { text: r.region, options: { align: "left", fontSize: 10.5 } },
    { text: nf(r.meets), options: { align: "right", fontSize: 10.5 } },
    { text: nf(r.ME1), options: { align: "right", fontSize: 10.5 } },
    { text: nf(r.WE1), options: { align: "right", fontSize: 10.5 } },
    { text: nf(r.other), options: { align: "right", fontSize: 10.5 } },
    { text: nf(r.total), options: { align: "right", fontSize: 10.5, bold: true } },
    { text: r.avg_total != null ? r.avg_total.toFixed(1) : "", options: { align: "right", fontSize: 10.5 } },
    { text: r.avg_ME1 != null ? r.avg_ME1.toFixed(1) : "", options: { align: "right", fontSize: 10.5 } },
    { text: r.avg_WE1 != null ? r.avg_WE1.toFixed(1) : "", options: { align: "right", fontSize: 10.5 } },
    { text: r.avg_other != null ? r.avg_other.toFixed(1) : "", options: { align: "right", fontSize: 10.5 } },
  ]));
  trows.push([
    { text: "合計", options: { align: "left", fontSize: 10.5, bold: true, fill: { color: GRAY } } },
    { text: nf(gt.meets), options: { align: "right", fontSize: 10.5, bold: true, fill: { color: GRAY } } },
    { text: nf(gt.ME1), options: { align: "right", fontSize: 10.5, bold: true, fill: { color: GRAY } } },
    { text: nf(gt.WE1), options: { align: "right", fontSize: 10.5, bold: true, fill: { color: GRAY } } },
    { text: nf(gt.other), options: { align: "right", fontSize: 10.5, bold: true, fill: { color: GRAY } } },
    { text: nf(gt.total), options: { align: "right", fontSize: 10.5, bold: true, fill: { color: GRAY } } },
    { text: gt.avg_total != null ? gt.avg_total.toFixed(1) : "", options: { align: "right", fontSize: 10.5, bold: true, fill: { color: GRAY } } },
    { text: "", options: { fill: { color: GRAY } } }, { text: "", options: { fill: { color: GRAY } } }, { text: "", options: { fill: { color: GRAY } } },
  ]);
  tbl(s, 0.3, 0.85, 7.6, trows, { fs: 10.5, colW: [1.0, 0.65, 0.72, 0.72, 0.82, 0.82, 0.72, 0.7, 0.7, 0.73], rowH: 0.19 });

  // ---- 複合グラフ: 積上棒(その他/WE1/ME1) + 折線(大会数, 右軸) ----
  s.addText("1大会あたりの平均エントリー数（地域別）", { x: 8.1, y: 0.82, w: 5, h: 0.3, fontFace: BF, fontSize: 10, bold: true, color: INK });
  const regs = rows.map(r => r.region);
  s.addChart([
    { type: p.charts.BAR, data: [
      { name: "その他", labels: regs, values: rows.map(r => r.avg_other) },
      { name: "WE1", labels: regs, values: rows.map(r => r.avg_WE1) },
      { name: "ME1", labels: regs, values: rows.map(r => r.avg_ME1) },
    ], options: { barGrouping: "stacked", chartColors: [C_OTHER, C_WE1, C_ME1] } },
    { type: p.charts.LINE, data: [
      { name: "大会数", labels: regs, values: rows.map(r => r.meets) },
    ], options: { secondaryValAxis: true, secondaryCatAxis: true, chartColors: [C_LINE], lineSize: 2, lineDataSymbol: "circle" } },
  ], {
    x: 8.0, y: 1.15, w: 5.1, h: 5.4, showLegend: true, legendPos: "b", legendFontSize: 9.5,
    valAxes: [
      { valAxisMaxVal: 800, valAxisMinVal: 0, valAxisLabelFontSize: 8.5 },
      { valAxisMaxVal: 14, valAxisMinVal: 0, valAxisLabelFontSize: 8.5 },
    ],
    catAxes: [{ catAxisLabelFontSize: 7.5, catAxisLabelRotate: 45 }, { catAxisHidden: true }],
  });
  s.addText("is_jcx=0。平均=合計/大会数。宇都宮はJCX扱いで除外、能登なし。",
    { x: 0.3, y: 6.85, w: 7.6, h: 0.3, fontFace: BF, fontSize: 8.5, italic: true, color: MUTE });
}

// ================= P.10 円グラフ3 + エントリ数表 + 参加者数表 =================
{
  const s = newSlide(D.p10.heading, 10);
  const segs = D.p10.segments;
  const t1 = D.p10.table1_entries;

  // ---- 円グラフ3つ ----
  const pie = (title, obj, x) => {
    s.addText(title, { x: x, y: 0.82, w: 4, h: 0.3, fontFace: BF, fontSize: 10.5, bold: true, color: INK, align: "center" });
    s.addChart(p.charts.PIE, [{ name: title, labels: segs, values: segs.map(sg => obj.counts[sg]) }],
      { x: x - 0.2, y: 1.1, w: 4.4, h: 2.3, showLegend: true, legendPos: "b", legendFontSize: 7.5, chartColors: PIE_COLORS, showPercent: true, dataLabelFontSize: 7.5, dataLabelColor: "FFFFFF" });
  };
  pie("JCX：エントリー割合", t1.JCX, 0.5);
  pie("ローカル：エントリー割合", t1.local, 4.7);
  pie("25-26 全参加者割合", D.p10.table2_participants, 8.9);

  // ---- 表1: エントリ数 & 割合 ----
  const head = [thcell("分類")].concat(segs.map(thcell)).concat([thcell("合計")]);
  const mkEntryRows = (label, obj) => {
    return [
      [{ text: label, options: { align: "left", bold: true } }].concat(segs.map(sg => ({ text: nf(obj.counts[sg]), options: { align: "right" } }))).concat([{ text: nf(obj.total), options: { align: "right", bold: true } }]),
      [{ text: "　割合", options: { align: "left", color: MUTE } }].concat(segs.map(sg => ({ text: obj.pct[sg].toFixed(1) + "%", options: { align: "right", color: MUTE, fontSize: 9.5 } }))).concat([{ text: "", options: {} }]),
    ];
  };
  const t1rows = [head];
  mkEntryRows("JCX", t1.JCX).forEach(r => t1rows.push(r));
  mkEntryRows("ローカル", t1.local).forEach(r => t1rows.push(r));
  mkEntryRows("全体", t1.all).forEach(r => t1rows.push(r));
  s.addText("■カテゴリーボリューム別エントリー数と割合", { x: 0.3, y: 3.55, w: 8, h: 0.3, fontFace: BF, fontSize: 10, bold: true, color: INK });
  tbl(s, 0.3, 3.85, 12.7, t1rows, { fs: 10.5, colW: [1.6, 1.75, 1.55, 1.75, 1.85, 1.55, 1.5, 1.15], rowH: 0.18 });

  // ---- 表2: 参加者数 ----
  const t2 = D.p10.table2_participants;
  const t2rows = [
    [thcell("分類")].concat(segs.map(thcell)).concat([thcell("延べ計"), thcell("ﾕﾆｰｸactive")]),
    [{ text: "参加者数(延べ)", options: { align: "left", bold: true } }].concat(segs.map(sg => ({ text: nf(t2.counts[sg]), options: { align: "right" } }))).concat([
      { text: nf(t2.delne_total), options: { align: "right", bold: true } },
      { text: nf(t2.unique_active_total), options: { align: "right", bold: true } },
    ]),
  ];
  s.addText("■カテゴリーボリューム別参加者数（延べdistinct）", { x: 0.3, y: 5.75, w: 9, h: 0.3, fontFace: BF, fontSize: 10, bold: true, color: INK });
  tbl(s, 0.3, 6.05, 12.7, t2rows, { fs: 10.5, colW: [1.55, 1.45, 1.4, 1.45, 1.55, 1.4, 1.3, 0.9, 1.7], rowH: 0.18 });
  s.addText(t2.note, { x: 0.3, y: 6.6, w: 12.7, h: 0.3, fontFace: BF, fontSize: 7.5, italic: true, color: MUTE });
}

// ================= P.11 カテゴリ個別推移表(25行・WE2/WE3別行) + 所見 =================
{
  const s = newSlide(D.p11.heading, 11);
  const rows = D.p11.rows;
  // 各コードのセグメント帰属（左端バンドの色分け・元資料P.11準拠。数値はJSON由来）
  const segOf = (code) => {
    if (/^ME/.test(code)) return "男子実力別";
    if (/^(WE|WJ|WU|WM)/.test(code)) return "女子";
    if (/^(CJ|MU)/.test(code)) return "男子14〜18歳";
    if (/^MM/.test(code)) return "男子マスターズ";
    if (/^CK/.test(code)) return "小学生";
    return "その他";
  };
  // P11専用: セル上下パディングを詰めて27行をフッター上端(y=7.14)より上に収める。
  const P11_CELL_FS = 7.5;
  const P11_MARGIN = [0.01, 0.03, 0.01, 0.03]; // [top,right,bottom,left] インチ。行高圧縮の主因。
  const head = [chcell("カテゴリー", HB, { fontSize: 9.5 }), thcell("参加者"), thcell("前年度比"), thcell("平均ｴﾝﾄﾘ回数"), thcell("エントリ数")];
  const trows = [head];
  rows.forEach(r => {
    const seg = segOf(r.code);
    // WE2は但し書き（WE2+3を含む）をコード脇に小注記
    const codeText = r.code;
    trows.push([
      { text: codeText, options: { align: "left", fontSize: P11_CELL_FS, bold: true, fill: { color: SEG[seg] }, color: HW } },
      { text: nf(r.participants), options: { align: "right", fontSize: P11_CELL_FS } },
      { text: df(r.yoy_delta), options: { align: "right", fontSize: P11_CELL_FS, color: (r.yoy_delta < 0 ? RED : INK) } },
      { text: r.avg_entries != null ? r.avg_entries.toFixed(1) + "回" : "", options: { align: "right", fontSize: P11_CELL_FS } },
      { text: nf(r.entries), options: { align: "right", fontSize: P11_CELL_FS } },
    ]);
  });
  const tt = D.p11.total;
  trows.push([
    { text: "合計(ﾕﾆｰｸ)", options: { align: "left", fontSize: P11_CELL_FS, bold: true, fill: { color: GRAY } } },
    { text: nf(tt.unique_active), options: { align: "right", fontSize: P11_CELL_FS, bold: true, fill: { color: GRAY } } },
    { text: df(tt.yoy_delta), options: { align: "right", fontSize: P11_CELL_FS, bold: true, color: (tt.yoy_delta < 0 ? RED : INK), fill: { color: GRAY } } },
    { text: tt.avg_entries_overall.toFixed(1) + "回", options: { align: "right", fontSize: P11_CELL_FS, bold: true, fill: { color: GRAY } } },
    { text: "", options: { fill: { color: GRAY } } },
  ]);
  // 単一表（元資料P.11同様の縦長1表）。27行をフッター上に収めるためrowH+margin圧縮。
  tbl(s, 0.3, 0.62, 4.9, trows, { fs: P11_CELL_FS, colW: [1.55, 0.95, 0.9, 0.9, 0.9], rowH: 0.13, margin: P11_MARGIN });
  // WE2但し書き（p11.note由来のWE2+3統合説明を脚注化）＋一般注記。右側所見列の下に配置。
  const we2Note = (rows.find(r => r.code === "WE2") || {}).note;
  s.addText("※参加者=各報告カテゴリのdistinct racer_code（延べ・重複あり）。ユニークactive総数=" + nf(tt.unique_active) + "。平均ｴﾝﾄﾘ回数=当該カテゴリのentries/participants。"
    + (we2Note ? "　※WE2: " + we2Note + "（WE2=CL2+CL2+3合算・WE3=CL3を別行表示）。" : ""),
    { x: 0.3, y: 4.72, w: 5.0, h: 1.4, fontFace: BF, fontSize: 8, italic: true, color: MUTE, lineSpacingMultiple: 1.15 });

  // ---- 右側: 所見5段（■全体/■ME/■女子/■マスターズ/■小学生）。JSONにcommentsが無ければ描かない安全策 ----
  if (Array.isArray(D.p11.comments) && D.p11.comments.length > 0) {
    const runs = [];
    D.p11.comments.forEach((c, i) => {
      runs.push({ text: c.label + "\n", options: { bold: true, fontSize: 12, color: INK, breakLine: true } });
      runs.push({ text: "・" + c.text + "\n" + (i < D.p11.comments.length - 1 ? "\n" : ""),
        options: { bold: false, fontSize: 10, color: INK, breakLine: true } });
    });
    s.addText(runs, { x: 5.6, y: 0.78, w: 7.4, h: 5.5, fontFace: BF, valign: "top", lineSpacingMultiple: 1.15 });
  }
}

// ================= P.12 年齢分布ヒストグラム(1歳刻み・男女) + 年齢帯表 =================
{
  const s = newSlide(D.p12.heading, 12);
  const rows = D.p12.rows;

  // ---- ヒストグラム（1歳刻み縦棒・男女2系列。p12.histogram由来。数値はJSON） ----
  s.addText("参加者の年齢分布（1歳刻み×性別）", { x: 0.4, y: 0.85, w: 8, h: 0.3, fontFace: BF, fontSize: 12, bold: true, color: INK });
  const hg = D.p12.histogram;
  // 横軸=年齢(数値)ラベル。1歳刻みで密なため軸ラベルは5歳ごとのみ表示（レイアウト都合）。
  const ageLabels = hg.ages.map(a => (a % 5 === 0 ? String(a) : ""));
  s.addChart(p.charts.BAR, [
    { name: "男性", labels: ageLabels, values: hg.male },
    { name: "女性", labels: ageLabels, values: hg.female },
  ], {
    x: 0.3, y: 1.2, w: 8.4, h: 5.3, barGrouping: "clustered", chartColors: [C_MALE, C_FEMALE],
    showLegend: true, legendPos: "tr", legendFontSize: 10,
    catAxisLabelFontSize: 9.5, valAxisLabelFontSize: 9.5, valAxisMinVal: 0,
    catAxisTitle: "年齢", showCatAxisTitle: true, catAxisTitleFontSize: 9.5,
    valAxisTitle: "人数", showValAxisTitle: true, valAxisTitleFontSize: 9.5,
    barGapWidthPct: 20,
  });

  // ---- 年齢帯表（現状維持: p12.rowsの年齢帯集計。表は不変） ----
  const head = [thcell("年齢帯"), thcell("男性"), thcell("女性")];
  const trows = [head];
  rows.forEach(r => trows.push([
    { text: r.band, options: { align: "left", fontSize: 10.5 } },
    { text: nf(r.male), options: { align: "right", fontSize: 10.5 } },
    { text: nf(r.female), options: { align: "right", fontSize: 10.5 } },
  ]));
  const tot = D.p12.totals;
  trows.push([
    { text: "合計", options: { align: "left", fontSize: 10.5, bold: true, fill: { color: GRAY } } },
    { text: nf(tot.male), options: { align: "right", fontSize: 10.5, bold: true, fill: { color: GRAY } } },
    { text: nf(tot.female), options: { align: "right", fontSize: 10.5, bold: true, fill: { color: GRAY } } },
  ]);
  tbl(s, 9.0, 1.2, 4.0, trows, { fs: 10.5, colW: [1.6, 1.2, 1.2], rowH: 0.22 });
  s.addText("age=2025-YEAR(birth_date)。gender 0=男/1=女/-1=不明。性別不明" + nf(tot.gender_unknown) + "名を含め合計" + nf(tot.grand) + "名（ユニークactive総数と整合）。",
    { x: 9.0, y: 4.6, w: 4.0, h: 1.2, fontFace: BF, fontSize: 9, italic: true, color: MUTE, lineSpacingMultiple: 1.2 });
}

// ================= P.13 コホート三角(表A) + 年×地域新規(表B) + 地方ブロック + 所見 =================
{
  const s = newSlide(D.p13.heading, 13);
  const cohort = D.p13.cohort;

  // ---- 表A: コホート三角（行=観測年度・列=初参戦コホート・対角=新規・右端=新規割合・最下段=継続者割合） ----
  s.addText("■新規参加者と継続者割合（初参戦コホート三角）", { x: 0.3, y: 0.72, w: 9, h: 0.24, fontFace: BF, fontSize: 11, bold: true, color: INK });
  const cCols = cohort.columns; // ["2014以前","15-16",...,"25-26"]
  // ヘッダー: 初参戦 / 参加者合計 / <各コホート> / 新規参加者割合（色分け）
  const aHead = [chcell("初参戦", RED, { fontSize: 8 }), chcell("参加者\n合計", G_JCX, { fontSize: 8 })];
  cCols.forEach((c, i) => aHead.push(chcell(c, i % 2 === 0 ? HB : G_LOCAL, { fontSize: 8 })));
  aHead.push(chcell("新規参加者\n割合", G_ALL, { fontSize: 8 }));
  const aRows = [aHead];
  cohort.rows.forEach(r => {
    // 対角（新規セル）= その年度の右端の非null実データ列。cells最終非null indexで判定。
    let diagIdx = -1;
    for (let i = r.cells.length - 1; i >= 0; i--) { if (r.cells[i] != null) { diagIdx = i; break; } }
    const cells = [{ text: r.year, options: { align: "center", fontSize: 8, bold: (r.source === "db") } }];
    cells.push({ text: r.total == null ? "-" : nf(r.total), options: { align: "right", fontSize: 8, bold: true } });
    r.cells.forEach((v, i) => {
      const isDiag = (i === diagIdx);
      cells.push({ text: v == null ? "" : nf(v),
        options: { align: "right", fontSize: 8, bold: isDiag, fill: isDiag ? { color: SH_DIAG } : undefined } });
    });
    cells.push({ text: r.new_ratio || "", options: { align: "right", fontSize: 8, bold: true, color: MUTE } });
    aRows.push(cells);
  });
  // 最下段: 継続者割合（continuation_row: nullや reliable:false は扱いに注意）
  const contRow = [{ text: "継続者割合", options: { align: "center", fontSize: 8, bold: true, fill: { color: GRAY }, color: INK } },
    { text: "", options: { fill: { color: GRAY } } }];
  cCols.forEach(cn => {
    const cr = cohort.continuation_row.find(x => x.cohort === cn);
    let txt = "", clr = INK;
    if (cr && cr.ratio_pct != null) {
      txt = cr.ratio_pct + "%";
      if (cr.reliable === false) { txt = "(" + txt + ")"; clr = MUTE; } // 参考値は括弧＋グレー
    }
    contRow.push({ text: txt, options: { align: "right", fontSize: 8, bold: true, color: clr, fill: { color: GRAY } } });
  });
  contRow.push({ text: "", options: { fill: { color: GRAY } } });
  aRows.push(contRow);
  // 列幅: 初参戦0.9 合計0.75 + 12コホート + 新規割合0.95
  const aColW = [0.9, 0.75];
  const acW = (13.0 - 0.9 - 0.75 - 1.0) / cCols.length;
  for (let i = 0; i < cCols.length; i++) aColW.push(acW);
  aColW.push(1.0);
  tbl(s, 0.15, 0.98, 13.0, aRows, { fs: 8, colW: aColW, rowH: 0.14, valign: "middle", margin: 0.02 });
  // 脚注（決定#13）: 必ず表示（継続者割合行と重ならないよう下げる）
  s.addText(cohort.footnote + "（()=参考値・空欄=分離不能/対象外）",
    { x: 0.15, y: 3.32, w: 13.0, h: 0.3, fontFace: BF, fontSize: 8, italic: true, color: MUTE, lineSpacingMultiple: 1.0 });

  // ---- 表B: 年×地域 新規参加者（列=地域・決定#12順・right端total） ----
  s.addText("■シリーズ（地域）別 新規参加者（年×地域）", { x: 0.3, y: 3.5, w: 9, h: 0.24, fontFace: BF, fontSize: 11, bold: true, color: INK });
  const rnCols = D.p13.regional_new.columns; // ["year",<regions>,"total"]
  const rnRegions = rnCols.slice(1, -1); // 地域名（決定#12順）
  const rnHead = [chcell("年度", RED, { fontSize: 8 })]
    .concat(rnRegions.map((rg, i) => chcell(rg, i % 2 === 0 ? HB : G_LOCAL, { fontSize: 8 })))
    .concat([chcell("合計", G_ALL, { fontSize: 8 })]);
  const rnRows = [rnHead];
  D.p13.regional_new.rows.forEach(r => {
    const isYoy = r.year === "前年度比";
    const cells = [{ text: r.year, options: { align: "center", fontSize: 8, bold: true, fill: isYoy ? { color: HEAD } : undefined } }];
    r.cells.forEach(v => {
      const disp = v == null ? "-" : (isYoy ? df(v) : nf(v));
      cells.push({ text: disp, options: { align: "right", fontSize: 8, color: (isYoy && v != null && v < 0) ? RED : INK } });
    });
    cells.push({ text: r.total == null ? "" : (isYoy ? df(r.total) : nf(r.total)),
      options: { align: "right", fontSize: 8, bold: true, color: (isYoy && r.total != null && r.total < 0) ? RED : INK } });
    rnRows.push(cells);
  });
  const rnColW = [0.85];
  const rnW = (13.0 - 0.85 - 0.75) / rnRegions.length;
  for (let i = 0; i < rnRegions.length; i++) rnColW.push(rnW);
  rnColW.push(0.75);
  tbl(s, 0.15, 3.78, 13.0, rnRows, { fs: 8, colW: rnColW, rowH: 0.16, valign: "middle", margin: 0.02 });

  // ---- 地方ブロック集約（表B下部） ----
  const blk = D.p13.regional_new.blocks;
  const blkOrder = blk.block_order;
  const blkMap = {};
  blk.rows_2526.forEach(b => { blkMap[b.block] = b.new_participants; });
  const blkHead = [chcell("地方ブロック", HB, { fontSize: 8 })].concat(blkOrder.map(b => chcell(b, G_LOCAL, { fontSize: 8 })));
  const blkVal = [{ text: "新規(25-26)", options: { align: "center", fontSize: 8, bold: true, fill: { color: GRAY } } }]
    .concat(blkOrder.map(b => ({ text: nf(blkMap[b]), options: { align: "right", fontSize: 8 } })));
  const blkColW = [1.4];
  const bW = (7.6 - 1.4) / blkOrder.length;
  for (let i = 0; i < blkOrder.length; i++) blkColW.push(bW);
  tbl(s, 0.15, 5.5, 7.6, [blkHead, blkVal], { fs: 8, colW: blkColW, rowH: 0.2, valign: "middle", margin: 0.02 });
  s.addText("地方=" + blk.blocks_definition, { x: 0.15, y: 6.0, w: 7.6, h: 0.3, fontFace: BF, fontSize: 7.5, italic: true, color: MUTE });

  // ---- 所見（右下） ----
  const comments = [
    "新規参加者は" + nf(cohort.new_2526) + "名（新規参加者割合" + cohort.new_pct + "%、前年度比" + df(D.p4.senshu_su.rows[1].yoy_delta) + "名）と引き続き減少。",
    "関東・関西・東海が新規参加者の主要供給源。宇都宮のJCX新規参入は初年度のため新規1名にとどまる。",
    "継続者割合は初参戦から年を経るほど上昇（18-19〜24-25はreliable値）。25-26アクティブ選手" + nf(cohort.total) + "名の初参戦別内訳を表Aに示す。",
  ];
  s.addText(comments.map(c => ({ text: "・" + c + "\n", options: { breakLine: true } })),
    { x: 8.0, y: 5.45, w: 5.1, h: 1.6, fontFace: BF, fontSize: 8.5, color: INK, valign: "top", lineSpacingMultiple: 1.1 });
}

// ================= P.14 Web ページビュー推移表(23行) — Web両対応 =================
{
  const s = newSlide(D.p14.heading, 14);
  s.addText(D.p14.subtitle, { x: 0.3, y: 0.82, w: 9, h: 0.3, fontFace: BF, fontSize: 12, bold: true, color: INK });
  const isPlaceholder = D.p14.placeholder === true;
  const period = D.p14.period_label || "集計期間: 実データ入手後確定（TBD）";
  s.addText(period, { x: 0.3, y: 1.15, w: 9, h: 0.3, fontFace: BF, fontSize: 10.5, color: MUTE });

  // 列見出しは出す。値はnull/placeholderならTBD、あれば実値を描画（両対応）
  const head = [thcell("親ページ"), thcell("子ページ"), thcell("2023-2024"), thcell("2024-2025"), thcell("2025-2026"), thcell("前年度比")];
  const rows = [head];
  const cell = (v, isPct) => {
    if (v == null) return { text: "TBD", options: { align: "right", color: MUTE, fontSize: 9.5, italic: true } };
    return { text: isPct ? nf(v) + "%" : nf(v), options: { align: "right", fontSize: 9.5 } };
  };
  D.p14.rows.forEach(r => {
    const isTotal = r.parent === "total";
    rows.push([
      { text: isTotal ? "合計" : r.parent, options: { align: "left", fontSize: 9.5, bold: isTotal, fill: isTotal ? { color: GRAY } : undefined } },
      { text: r.child || "", options: { align: "left", fontSize: 9.5, color: MUTE, fill: isTotal ? { color: GRAY } : undefined } },
      cell(r.y2324), cell(r.y2425), cell(r.y2526), cell(r.yoy_pct, true),
    ]);
  });
  // 23行 → 2列分割。colW合計を実幅に一致させ（親/子列を確保し年列を詰める）文字重なりを解消。
  const body = rows.slice(1);
  const half = Math.ceil(body.length / 2);
  // 6列 colW 合計 = 6.2（親1.35/子1.25/年0.9×3/前年度比0.9）。左右とも同一。
  const p14cw = [1.35, 1.25, 0.9, 0.9, 0.9, 0.9];
  tbl(s, 0.3, 1.55, 6.2, [head].concat(body.slice(0, half)), { fs: 9, colW: p14cw, rowH: 0.19, valign: "middle" });
  tbl(s, 6.9, 1.55, 6.2, [head].concat(body.slice(half)), { fs: 9, colW: p14cw, rowH: 0.19, valign: "middle" });

  if (isPlaceholder) {
    const lines = ["※GA実データを14/24行に反映済み（2026-07-19）。リザルト・ランキング・選手検索・選手データ・その他の10行は新トラッキング設定で分離不能なためTBD（詳細はagreement-log.md参照）。所見は全項目確定後に執筆。"];
    if (D.p14.anomaly_note) lines.push("※" + D.p14.anomaly_note);
    s.addText(lines.join("\n"),
      { x: 0.3, y: 6.05, w: 12.7, h: 1.0, fontFace: BF, fontSize: 8.5, italic: true, color: RED, lineSpacingMultiple: 1.05, valign: "top" });
  }
}

// ================= P.15 Web ランキング4表 — Web両対応 =================
{
  const s = newSlide(D.p15.heading, 15);
  s.addText(D.p15.subtitle, { x: 0.3, y: 0.82, w: 9, h: 0.3, fontFace: BF, fontSize: 12, bold: true, color: INK });
  const positions = [
    { x: 0.3, y: 1.3 }, { x: 6.8, y: 1.3 }, { x: 0.3, y: 4.5 }, { x: 6.8, y: 4.5 },
  ];
  D.p15.tables.forEach((t, i) => {
    const pos = positions[i] || { x: 0.3, y: 1.3 };
    s.addText("■" + t.title, { x: pos.x, y: pos.y - 0.32, w: 6, h: 0.3, fontFace: BF, fontSize: 11, bold: true, color: INK });
    const head = t.columns.map(thcell);
    const trows = [head];
    if (t.rows == null || t.placeholder === true) {
      // Web両対応: 行データが無ければ列見出しのみ＋TBD行を数行
      const tbdCount = t.title.includes("Top 10") ? 10 : 5;
      for (let r = 1; r <= tbdCount; r++) {
        trows.push([
          { text: String(r), options: { align: "center", fontSize: 9.5, color: MUTE } },
          { text: "実データ入手後更新（TBD）", options: { align: "left", fontSize: 9.5, color: MUTE, italic: true } },
          { text: "TBD", options: { align: "right", fontSize: 9.5, color: MUTE, italic: true } },
        ]);
      }
    } else {
      // 実データあり: そのまま描画
      t.rows.forEach((row, idx) => {
        trows.push([
          { text: String(row.rank != null ? row.rank : idx + 1), options: { align: "center", fontSize: 9.5 } },
          { text: row.title || row.page || "", options: { align: "left", fontSize: 9.5 } },
          { text: nf(row.views != null ? row.views : row.value), options: { align: "right", fontSize: 9.5 } },
        ]);
      });
    }
    tbl(s, pos.x, pos.y, 6.0, trows, { fs: 8.5, colW: [0.7, 4.0, 1.3], rowH: 0.135 });
  });
  if (D.p15.placeholder === true) {
    s.addText("※概要Top5・ニュースTop5はGA実データを反映済み（2026-07-19）。ランキングTop10・リザルトTop10は対応するアクセス解析データが未取得のためTBD。",
      { x: 0.3, y: 6.95, w: 12.7, h: 0.3, fontFace: BF, fontSize: 9.5, italic: true, color: RED });
  }
}

// ================= 出力 =================
p.writeFile({ fileName: OUT_PATH }).then(() => console.log("written:", OUT_PATH));
