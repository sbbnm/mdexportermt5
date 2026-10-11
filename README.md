<div align="center">

# MET v1.0

**MetaTrader 5 → Markdown trade exporter for your Obsidian trading journal**

**English** | [فارسی](README.fa.md) | [Türkçe](README.tr.md) | [Azərbaycanca](README.az.md)

[Telegram](https://t.me/o2tribe) · [GitHub](https://github.com/sbbnm/mdexportermt5)

</div>

---
▶️ [Watch on YouTube](https://youtu.be/CbZ8fmYc9Nw)
MET is an Expert Advisor for MetaTrader 5. It **does not trade**. It only reads your closed positions and writes each one as a `.md` note, ready to drop into an Obsidian vault.

Every note is tagged with the right **New York session**, **macro window** and **timeframe**, even if your broker's server time zone is different from New York (the conversion is done for you, including summer/winter time).

## Features

- One Markdown note per closed trade (`ticket`, symbol, direction, volume, prices, SL/TP, R:R, balance, profit, commission, swap, duration, result and more).
- Automatic export right after a trade closes, plus manual export for Today / This Week / This Month / All History / a custom date range.
- Session, macro and timeframe detection (see [Sessions and macros](#sessions-and-macros)).
- Broker time zone auto-detection, or manual setup with any UTC offset and summer-time (DST) rule.
- Editable sessions and macro windows, extra custom fields, dark / light / auto theme.
- No DLLs, no internet access: nothing leaves your computer.

## Screenshots

<p align="center"><img src="images/overview.png" alt="MET on a chart: panel on the right, settings window on the left" width="820"><br><sub>MET on a chart: panel on the right, settings window on the left</sub></p>

<table align="center">
<tr>
<td align="center"><img src="images/panel.png" alt="The panel on the chart" width="400"><br><sub>The panel on the chart</sub></td>
<td align="center"><img src="images/settings-export.png" alt="Settings: Export" width="400"><br><sub>Settings: Export</sub></td>
</tr>
<tr>
<td align="center"><img src="images/settings-fields.png" alt="Settings: Fields" width="400"><br><sub>Settings: Fields</sub></td>
<td align="center"><img src="images/settings-timezones.png" alt="Settings: Time Zones" width="400"><br><sub>Settings: Time Zones</sub></td>
</tr>
<tr>
<td align="center"><img src="images/settings-sessions.png" alt="Settings: Sessions" width="400"><br><sub>Settings: Sessions</sub></td>
<td align="center"><img src="images/settings-advanced.png" alt="Settings: Advanced" width="400"><br><sub>Settings: Advanced</sub></td>
</tr>
<tr>
<td align="center"><img src="images/settings-about.png" alt="Settings: About" width="400"><br><sub>Settings: About</sub></td>
<td align="center"><img src="images/note-example.png" alt="An exported note in Obsidian" width="400"><br><sub>An exported note in Obsidian</sub></td>
</tr>
</table>

## Requirements

- MetaTrader 5 desktop (any broker, demo or live account).
- [Obsidian](https://obsidian.md) to use the notes. The generated notes contain Dataview (`dataviewjs`) blocks, so install the **Dataview** community plugin and enable JavaScript queries for the full experience.

## Installation

1. In MetaTrader 5 click **File → Open Data Folder**.
2. In the window that opens, open the **MQL5** folder, then the **Experts** folder.
3. Paste the file **`MET_1.ex5`** into the **Experts** folder.
4. Back in MetaTrader 5 open **View → Navigator** (or press `Ctrl+N`).
5. In the Navigator, under **Expert Advisors**, right-click and choose **Refresh** once. **MET** appears in the list.
6. Drag **MET** onto a chart. Use a chart of a symbol that **you do not trade** (recommended, so it never gets mixed up with your trading charts).
7. In the **Inputs** tab type your broker / account name (for example `FundedNext`) in **Account label** and press **OK**. You can also leave it empty.

The panel appears on the top right of the chart. Make sure the **Algo Trading** button is on.

> You can also compile the source yourself: open `MET.mq5` in MetaEditor and press `F7`.

## The panel on the chart

| Item | What it does |
|---|---|
| **Broker / New York / Local** | Live clocks. New York time follows US summer/winter time automatically. |
| **DST line** | Shows whether the broker and New York are currently on summer or winter time and their UTC offsets. |
| **Range** | The export range currently selected. |
| **Settings** | Opens the settings window (on the left side of the chart). |
| **EXPORT NOW** | Exports the trades of the selected range. |
| **`>` arrow** | Hides the panel. A small **`MET <`** button stays in the corner; click it to show the panel again. |

## Settings window (tabs)

### 1. Export

Choose what to export, then press **EXPORT NOW**.

- **Today**, **This Week** (from Monday), **This Month**, **All History**.
- **Custom Range**: type *From* and *To* dates as `YYYY.MM.DD`. Dates use the broker server time and the *To* date is included.

The status line under the button shows how many trades were exported.

### 2. Fields

- Shows the **40 default fields** written to every note (fixed, they cannot be removed so your Obsidian dashboards keep working):

  `ticket, account, account_id, broker, symbol, direction, volume, entry_price, exit_price, sl, tp, risk_amount, rr, open, close, ny_open, duration, balance_before, balance_after, equity_after, gross, commission, swap, net, result, strategy, setup, session, macro, news, timeframe, emotion, mistake, grade, review, notes, entry_images, exit_images, htf_images, tags`

- **Extra fields**: type a *Name* and a *Default value*, press **+ Add**. The field is added to every exported note (after `notes`). Spaces in names become `_`. Use **X** to delete a field. The `news` field is empty by default so you can fill it yourself.

### 3. Time Zones

MET converts every trade time like this: **broker time → GMT → New York time → session / macro**. So it needs to know your broker's time zone.

- **Broker server time zone**
  - **Auto-detect** (default): compares the server clock with your PC clock and recognises the common patterns (GMT+2 / GMT+3 with EU or US summer-time dates). If none matches, it uses the detected offset as a fixed offset. The note under the button tells you what was detected. Your PC clock and PC time zone must be correct.
  - **Manual**: choose a **Preset** (city), or set the **Winter offset** (UTC offset in winter) and the **Summer-time rule** (None / EU / US / Australia / New Zealand). Examples: broker GMT+2 in winter and GMT+3 in summer on EU dates → *Winter offset +2, rule EU*. A broker fixed on GMT+3 all year → *+3, rule None*.
- **Your own time zone**: display only (the "Local" clock in the panel).
- **Reference zone**: always **New York** (GMT-5, GMT-4 in US summer time).
- The tab also lists the **summer-time change dates** of the broker and New York for the current year, and live clocks. Check them against your broker.

### 4. Sessions

All times are **New York time**.

- **Sessions** (a trade gets the first matching one, otherwise `Closed`): start time is included and end time is excluded (`24:00` = midnight).
- **Macros** (otherwise `None`): start and end minutes are both included.
- Add your own window with a **name**, **from** and **to** (`HH:MM`). Windows may cross midnight (for example `22:00 - 02:00`). **X** deletes a row, **Reset to defaults** restores the defaults. Changes are saved automatically.

### 5. Advanced

- **Timeframe** written to the `timeframe` field:
  - **Auto**: MT5 does not store a trade's timeframe, so MET records it when the trade opens (the smallest timeframe among your open charts of that symbol). Trades opened while MET was not running, or without a chart of that symbol, get the **fallback** (default `M1`, or empty).
  - **Manual**: always writes the timeframe you choose.
- **Panel theme**: Dark, Light or Auto (follows the chart background colour).

### 6. About

Project links, the wallet address and QR code to support the project. Click a box and press `Ctrl+C` to copy (MT5 cannot open links itself).

## Where are the exported files?

1. In MetaTrader 5 click **File → Open Data Folder**.
2. Open the **MQL5** folder, then **Files**, then **Trades**.
3. Each trade has its own folder named with its ticket: `MQL5\Files\Trades\<ticket>\Trade-<ticket>.md`.
4. Copy the `.md` files (or the whole **Trades** folder) into your Obsidian vault.

> A trade that is exported again overwrites the file in `MQL5\Files`. When you copy files into your vault, do not overwrite notes you have already edited.

## Sessions and macros

Defaults (New York time). The session and macro are decided from the **trade open time**.

| Session | Time |
|---|---|
| Asia | 20:00 – 24:00 |
| London | 02:00 – 05:00 |
| NewYork(AM) | 08:30 – 10:00 |
| Silver Bullet | 10:00 – 11:00 |
| NewYork Launch | 11:00 – 12:00 |
| NewYork(PM) | 13:30 – 16:00 |

| Macro | Time |
|---|---|
| 8:50 - 9:10 | 08:50 – 09:10 |
| 9:50 - 10:10 | 09:50 – 10:10 |
| 10:50 - 11:10 | 10:50 – 11:10 |
| 13:50 - 14:10 | 13:50 – 14:10 |
| 15:15 - 15:30 | 15:15 – 15:30 |

## Good to know

- Settings are saved in `MQL5\Files\ObsidianExport_Settings.cfg`. Delete this file to reset everything.
- Messages and errors appear in the **Experts** tab of the MT5 Toolbox.
- Trades that were closed before you attached MET can be exported with **EXPORT NOW** (choose the range).
- MET only reads your history. It never opens, modifies or closes trades.

## Support the project

If MET helps you, you can support it with a donation (EVM address: Ethereum, BSC, Polygon, Arbitrum, Optimism, Base and other EVM networks. Send only on an EVM network, funds sent on other networks such as BTC or TRON are lost).

```
0x6a0F64332bDa0757A9C15C0A1C9E52F98b4d0282
```

<img src="donate-qr.png" alt="Donation QR code" width="180">

Questions and ideas: [Telegram](https://t.me/o2tribe) · [GitHub Issues](https://github.com/sbbnm/mdexportermt5/issues)

## Disclaimer

MET is a journaling tool. It is not financial advice and it does not trade for you. Always check the exported data against your broker statement.
