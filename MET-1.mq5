//+------------------------------------------------------------------+
//|                                                          MET.mq5 |
//|              MET - md format export from MT5 (Obsidian journal)  |
//+------------------------------------------------------------------+
#property copyright "MET - md format export from MT5 (Obsidian journal)"
#property link      "https://github.com/sbbnm/mdexportermt5"
#property version   "1.00"
#property description "MET - Export MT5 trades to Markdown notes for your Obsidian trading journal."
#property description "Telegram: https://t.me/o2tribe"
#property description "GitHub: https://github.com/sbbnm/mdexportermt5"

enum ENUM_EXPORT_RANGE
{
      EXPORT_TODAY,          // Today
      EXPORT_THIS_WEEK,      // This Week
      EXPORT_ALL,            // All History
      EXPORT_CUSTOM_DATE,    // Custom Date
      EXPORT_THIS_MONTH      // This Month
};

// --- Inputs ---
input group "--- General Settings ---"
input string                         InpAccountLabel   = "";                    // Account label (optional - written to the 'account' field)
input bool                           InpAutoBrokerTime = true;                  // Smart Live Broker Time (Auto-fallback on close)

input group "--- Export Range Settings (first-run defaults; later changes are saved from the Settings window) ---"
input ENUM_EXPORT_RANGE             InpExportRange     = EXPORT_ALL;            // Default Export Range
input datetime                     InpStartDate         = D'2026.01.01 00:00';   // Custom Start Date
input datetime                     InpEndDate             = D'2026.12.31 23:59';   // Custom End Date

//+------------------------------------------------------------------+
//| Constants                                                        |
//+------------------------------------------------------------------+
#define SETTINGS_FILE "ObsidianExport_Settings.cfg"

#define PANEL_WIDTH   250
#define PANEL_HEIGHT  224
#define MARGIN_RIGHT  20
#define MARGIN_TOP    20

#define WIN_W         620
#define WIN_H         440
#define ROWS_PER_PAGE 6
#define FIELD_ROWS    5

#define DST_NONE 0
#define DST_EU   1
#define DST_US   2
#define DST_AU   3
#define DST_NZ   4

#define EA_NAME       "MET"
#define EA_DESC       "MT5 trade export to Markdown (Obsidian journal)"
#define EA_VERSION    "1.0"
#define EA_TITLE      "MET v1.0"
#define URL_TELEGRAM  "https://t.me/o2tribe"
#define URL_GITHUB    "https://github.com/sbbnm/mdexportermt5"
#define WALLET_ADDR   "0x6a0F64332bDa0757A9C15C0A1C9E52F98b4d0282"
#define QR_N          29

// Theme colours (filled by ApplyTheme)
color COL_BG          = C'20,24,33';
color COL_BORDER      = C'50,60,80';
color COL_BTN         = C'40,46,60';
color COL_BTN_TXT     = clrWhite;
color COL_EDIT_BG     = C'30,36,50';
color COL_EDIT_TXT    = clrWhite;
color COL_EDIT_BORDER = C'90,100,125';
color T_TEXT   = clrWhite;
color T_MUTED  = clrSilver;
color T_TITLE  = clrGold;
color T_NOTE   = clrKhaki;
color T_FAINT  = clrGray;
color T_WARN   = clrOrangeRed;
color T_INFO   = clrLightSkyBlue;
color T_OK     = clrLime;

//+------------------------------------------------------------------+
//| State                                                            |
//+------------------------------------------------------------------+
ulong             LastProcessedPositionID = 0;
ENUM_EXPORT_RANGE CurrentMode             = EXPORT_ALL;

// Time zone settings (mode: 0 = Auto, 1 = Manual)
int  g_brokerMode   = 0;
int  g_brokerStd    = 120;       // standard (winter) offset in minutes
int  g_brokerRule   = DST_EU;
int  g_brokerPreset = -1;
int  g_ownMode      = 0;
int  g_ownStd       = 0;
int  g_ownRule      = DST_NONE;
int  g_ownPreset    = -1;

// Auto-detected broker offset (server time vs GMT, minutes) and whether it matches the classic GMT+2/+3 EU-DST pattern
int  g_autoDetectedMin = 0;
int  g_autoModel       = 0;   // 0 = not detected yet (behaves as 1), 1 = GMT+2/+3 with EU DST dates, 2 = GMT+2/+3 with US DST dates, 3 = fixed offset

// Custom export dates
string g_custFrom = "";
string g_custTo   = "";

// Extra frontmatter fields
string g_fieldName[];
string g_fieldVal[];

// Sessions and macros (NY time, minutes from midnight, both ends inclusive)
string g_sessName[];
int    g_sessStart[];
int    g_sessEnd[];
string g_macroName[];
int    g_macroStart[];
int    g_macroEnd[];

// Advanced settings
int    g_theme      = 2;      // 0 = Dark, 1 = Light, 2 = Auto (follows chart background)
bool   g_isLight    = false;
int    g_tfMode     = 0;      // 0 = Auto (detected), 1 = Manual
int    g_tfManual   = 0;      // index in TfNames
int    g_tfFallback = 0;      // index in TfNames used by Auto when unknown (-1 = leave empty)

// UI state
bool   g_settingsOpen = false;
bool   g_panelHidden  = false;
int    g_tab          = 0;
int    g_fieldPage    = 0;
int    g_sessPage     = 0;
int    g_macroPage    = 0;
string g_statusMsg    = "";
int    g_lastW        = 0;
int    g_lastH        = 0;

// Edit box contents (kept here so they survive UI rebuilds)
string g_edFName = "", g_edFVal = "";
string g_edSName = "", g_edSFrom = "", g_edSTo = "";
string g_edMName = "", g_edMFrom = "", g_edMTo = "";

// Latest computed clocks
datetime g_gmtNow    = 0;
datetime g_brokerNow = 0;

string DefaultFields[] =
{
   "ticket","account","account_id","broker","symbol","direction","volume","entry_price","exit_price","sl",
   "tp","risk_amount","rr","open","close","ny_open","duration","balance_before","balance_after","equity_after",
   "gross","commission","swap","net","result","strategy","setup","session","macro","news",
   "timeframe","emotion","mistake","grade","review","notes","entry_images","exit_images","htf_images","tags"
};

string PresetName[] =
{
   "UTC","London","Berlin / Paris","Athens / Kyiv (EET)","Istanbul / Moscow","Tehran","Dubai","Karachi","Delhi","Dhaka",
   "Bangkok","Singapore / HK","Tokyo","Sydney","Auckland","Sao Paulo","New York","Chicago","Denver","Los Angeles"
};
int PresetOff[]  = {0,0,60,120,180,210,240,300,330,360,420,480,540,600,720,-180,-300,-360,-420,-480};
int PresetRule[] = {0,1,1,1,0,0,0,0,0,0,0,0,0,3,4,0,2,2,2,2};

string TfNames[] = {"M1","M2","M3","M4","M5","M6","M10","M12","M15","M20","M30","H1","H2","H3","H4","H6","H8","H12","D1","W1","MN1"};

// QR code of the support address (module matrix, 1 = dark)
string QR_ROWS[] =
{
   "11111110100000010000101111111",
   "10000010101110110101101000001",
   "10111010000100001000101011101",
   "10111010110111110011001011101",
   "10111010011010100110101011101",
   "10000010010111011010001000001",
   "11111110101010101010101111111",
   "00000000110100000101000000000",
   "10110111011011001000001001011",
   "11000100011000000110010110011",
   "10111110101010101010010111110",
   "01010000101101011001101001000",
   "00100011010110010001000001100",
   "00110101101001110001101000111",
   "00101011101110110011101011001",
   "10111100100101010001100011010",
   "11001111001100001100100010101",
   "01111100011001001111000000010",
   "10000111100110011010110100100",
   "00000001001110010000000100100",
   "01001011100101010110111110101",
   "00000000111101110011100011001",
   "11111110101101000000101010000",
   "10000010110000001011100011000",
   "10111010010100110000111111101",
   "10111010111000110111001011100",
   "10111010111100001010000001001",
   "10000010001110011100011100010",
   "11111110100001000100100101010"
};

int OffsetList[] =
{
   -720,-660,-600,-570,-540,-480,-420,-360,-300,-240,-210,-180,-120,-60,0,
   60,120,180,210,240,270,300,330,345,360,390,420,480,525,540,570,600,630,660,720,765,780,840
};

//+------------------------------------------------------------------+
//| Small helpers                                                    |
//+------------------------------------------------------------------+
string Trim(string s)
{
      StringTrimLeft(s);
      StringTrimRight(s);
      return s;
}

string CleanText(string s)
{
      StringReplace(s, "|", "/");
      StringReplace(s, "\r", " ");
      StringReplace(s, "\n", " ");
      return Trim(s);
}

string SanitizeKey(string s)
{
      s = Trim(s);
      string r = "";
      int len = StringLen(s);
      for (int i = 0; i < len; i++)
      {
            ushort c = StringGetCharacter(s, i);
            if ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || c > 127)
                  r += ShortToString(c);
            else if (c == ' ' || c == '-')
                  r += "_";
      }
      return r;
}

bool IsDigits(string s)
{
      int len = StringLen(s);
      if (len == 0) return false;
      for (int i = 0; i < len; i++)
      {
            ushort c = StringGetCharacter(s, i);
            if (c < '0' || c > '9') return false;
      }
      return true;
}

string FmtHM(int m)
{
      return StringFormat("%02d:%02d", m / 60, m % 60);
}

bool ParseHM(string s, int &mins)
{
      s = Trim(s);
      string p[];
      int n = StringSplit(s, ':', p);
      if (n != 2) return false;
      p[0] = Trim(p[0]);
      p[1] = Trim(p[1]);
      if (!IsDigits(p[0]) || !IsDigits(p[1])) return false;
      int h = (int)StringToInteger(p[0]);
      int m = (int)StringToInteger(p[1]);
      if (h < 0 || h > 23 || m < 0 || m > 59) return false;
      mins = h * 60 + m;
      return true;
}

// end time of a session: also accepts 24:00 (= midnight, 1440)
bool ParseHMEnd(string s, int &mins)
{
      if (Trim(s) == "24:00") { mins = 1440; return true; }
      return ParseHM(s, mins);
}

string OffsetStr(int minutes)
{
      string sign = (minutes < 0) ? "-" : "+";
      int a = (minutes < 0) ? -minutes : minutes;
      string r = "UTC" + sign + IntegerToString(a / 60);
      if (a % 60 > 0) r += ":" + StringFormat("%02d", a % 60);
      return r;
}

string ShortOffset(int seconds)
{
      return StringSubstr(OffsetStr(seconds / 60), 3);
}

string RuleName(int r)
{
      switch (r)
      {
            case DST_EU: return "EU";
            case DST_US: return "US";
            case DST_AU: return "Australia";
            case DST_NZ: return "New Zealand";
      }
      return "None";
}

string RangeName(ENUM_EXPORT_RANGE m)
{
      switch (m)
      {
            case EXPORT_TODAY:       return "Today";
            case EXPORT_THIS_WEEK:   return "This Week";
            case EXPORT_THIS_MONTH:  return "This Month";
            case EXPORT_ALL:         return "All History";
            case EXPORT_CUSTOM_DATE: return "Custom Range";
      }
      return "?";
}

ENUM_EXPORT_RANGE RangeAt(int i)
{
      switch (i)
      {
            case 0: return EXPORT_TODAY;
            case 1: return EXPORT_THIS_WEEK;
            case 2: return EXPORT_THIS_MONTH;
            case 3: return EXPORT_ALL;
      }
      return EXPORT_CUSTOM_DATE;
}

int StepOffset(int cur, int dir)
{
      int n = ArraySize(OffsetList);
      int idx = -1;
      for (int i = 0; i < n; i++)
            if (OffsetList[i] == cur) { idx = i; break; }
      if (idx < 0)
      {
            idx = 0;
            for (int i = 0; i < n; i++)
                  if (OffsetList[i] >= cur) { idx = i; break; }
      }
      idx += dir;
      if (idx < 0) idx = 0;
      if (idx >= n) idx = n - 1;
      return OffsetList[idx];
}

//+------------------------------------------------------------------+
//| Sessions / macros defaults and list helpers                      |
//+------------------------------------------------------------------+
void AddSession(string n, int s, int e)
{
      int k = ArraySize(g_sessName);
      ArrayResize(g_sessName, k + 1);
      ArrayResize(g_sessStart, k + 1);
      ArrayResize(g_sessEnd, k + 1);
      g_sessName[k]  = n;
      g_sessStart[k] = s;
      g_sessEnd[k]   = e;
}

void AddMacro(string n, int s, int e)
{
      int k = ArraySize(g_macroName);
      ArrayResize(g_macroName, k + 1);
      ArrayResize(g_macroStart, k + 1);
      ArrayResize(g_macroEnd, k + 1);
      g_macroName[k]  = n;
      g_macroStart[k] = s;
      g_macroEnd[k]   = e;
}

void DefaultSessions()
{
      ArrayResize(g_sessName, 0);
      ArrayResize(g_sessStart, 0);
      ArrayResize(g_sessEnd, 0);
      // start included, end excluded
      AddSession("Asia",            1200, 1440);   // 20:00 - 24:00
      AddSession("London",           120,  300);   // 02:00 - 05:00
      AddSession("NewYork(AM)",      510,  600);   // 08:30 - 10:00
      AddSession("Silver Bullet",    600,  660);   // 10:00 - 11:00
      AddSession("NewYork Launch",   660,  720);   // 11:00 - 12:00
      AddSession("NewYork(PM)",      810,  960);   // 13:30 - 16:00
}

void DefaultMacros()
{
      ArrayResize(g_macroName, 0);
      ArrayResize(g_macroStart, 0);
      ArrayResize(g_macroEnd, 0);
      AddMacro("8:50 - 9:10",   530, 550);
      AddMacro("9:50 - 10:10",  590, 610);
      AddMacro("10:50 - 11:10", 650, 670);
      AddMacro("13:50 - 14:10", 830, 850);
      AddMacro("15:15 - 15:30", 915, 930);
}

void RemoveSession(int idx)
{
      int n = ArraySize(g_sessName);
      if (idx < 0 || idx >= n) return;
      for (int i = idx; i < n - 1; i++)
      {
            g_sessName[i]  = g_sessName[i + 1];
            g_sessStart[i] = g_sessStart[i + 1];
            g_sessEnd[i]   = g_sessEnd[i + 1];
      }
      ArrayResize(g_sessName, n - 1);
      ArrayResize(g_sessStart, n - 1);
      ArrayResize(g_sessEnd, n - 1);
}

void RemoveMacro(int idx)
{
      int n = ArraySize(g_macroName);
      if (idx < 0 || idx >= n) return;
      for (int i = idx; i < n - 1; i++)
      {
            g_macroName[i]  = g_macroName[i + 1];
            g_macroStart[i] = g_macroStart[i + 1];
            g_macroEnd[i]   = g_macroEnd[i + 1];
      }
      ArrayResize(g_macroName, n - 1);
      ArrayResize(g_macroStart, n - 1);
      ArrayResize(g_macroEnd, n - 1);
}

void RemoveField(int idx)
{
      int n = ArraySize(g_fieldName);
      if (idx < 0 || idx >= n) return;
      for (int i = idx; i < n - 1; i++)
      {
            g_fieldName[i] = g_fieldName[i + 1];
            g_fieldVal[i]  = g_fieldVal[i + 1];
      }
      ArrayResize(g_fieldName, n - 1);
      ArrayResize(g_fieldVal, n - 1);
}

bool FieldNameTaken(string key)
{
      string k = key;
      StringToLower(k);
      for (int i = 0; i < ArraySize(DefaultFields); i++)
      {
            string d = DefaultFields[i];
            StringToLower(d);
            if (d == k) return true;
      }
      for (int j = 0; j < ArraySize(g_fieldName); j++)
      {
            string f = g_fieldName[j];
            StringToLower(f);
            if (f == k) return true;
      }
      return false;
}

string BuildExtraFieldsYaml()
{
      string s = "";
      for (int i = 0; i < ArraySize(g_fieldName); i++)
      {
            string v = g_fieldVal[i];
            StringReplace(v, "\\", "\\\\");
            StringReplace(v, "\"", "\\\"");
            s += g_fieldName[i] + ": \"" + v + "\"\n";
      }
      return s;
}

//+------------------------------------------------------------------+
//| Settings persistence (MQL5\Files\ObsidianExport_Settings.cfg)    |
//+------------------------------------------------------------------+
void SaveSettings()
{
      int h = FileOpen(SETTINGS_FILE, FILE_WRITE | FILE_TXT | FILE_UNICODE);
      if (h == INVALID_HANDLE) return;

      FileWrite(h, "version=3");
      FileWrite(h, "auto_det=" + IntegerToString(g_autoDetectedMin));
      FileWrite(h, "auto_model=" + IntegerToString(g_autoModel));
      FileWrite(h, "broker_mode=" + IntegerToString(g_brokerMode));
      FileWrite(h, "broker_std=" + IntegerToString(g_brokerStd));
      FileWrite(h, "broker_rule=" + IntegerToString(g_brokerRule));
      FileWrite(h, "broker_preset=" + IntegerToString(g_brokerPreset));
      FileWrite(h, "own_mode=" + IntegerToString(g_ownMode));
      FileWrite(h, "own_std=" + IntegerToString(g_ownStd));
      FileWrite(h, "own_rule=" + IntegerToString(g_ownRule));
      FileWrite(h, "own_preset=" + IntegerToString(g_ownPreset));
      FileWrite(h, "range=" + IntegerToString((int)CurrentMode));
      FileWrite(h, "theme=" + IntegerToString(g_theme));
      FileWrite(h, "panel_hidden=" + IntegerToString(g_panelHidden ? 1 : 0));
      FileWrite(h, "tf_mode=" + IntegerToString(g_tfMode));
      FileWrite(h, "tf_manual=" + IntegerToString(g_tfManual));
      FileWrite(h, "tf_fallback=" + IntegerToString(g_tfFallback));
      FileWrite(h, "cust_from=" + g_custFrom);
      FileWrite(h, "cust_to=" + g_custTo);
      FileWrite(h, "lists=1");
      for (int i = 0; i < ArraySize(g_fieldName); i++)
            FileWrite(h, "field=" + CleanText(g_fieldName[i]) + "|" + CleanText(g_fieldVal[i]));
      for (int s = 0; s < ArraySize(g_sessName); s++)
            FileWrite(h, "session=" + CleanText(g_sessName[s]) + "|" + IntegerToString(g_sessStart[s]) + "|" + IntegerToString(g_sessEnd[s]));
      for (int m = 0; m < ArraySize(g_macroName); m++)
            FileWrite(h, "macro=" + CleanText(g_macroName[m]) + "|" + IntegerToString(g_macroStart[m]) + "|" + IntegerToString(g_macroEnd[m]));
      FileClose(h);
}

bool LoadSettings()
{
      if (!FileIsExist(SETTINGS_FILE)) return false;
      int h = FileOpen(SETTINGS_FILE, FILE_READ | FILE_TXT | FILE_UNICODE);
      if (h == INVALID_HANDLE) return false;

      bool hasLists = false;
      int cfgVersion = 0;
      ArrayResize(g_fieldName, 0);
      ArrayResize(g_fieldVal, 0);
      ArrayResize(g_sessName, 0);
      ArrayResize(g_sessStart, 0);
      ArrayResize(g_sessEnd, 0);
      ArrayResize(g_macroName, 0);
      ArrayResize(g_macroStart, 0);
      ArrayResize(g_macroEnd, 0);

      while (!FileIsEnding(h))
      {
            string line = Trim(FileReadString(h));
            int p = StringFind(line, "=");
            if (p < 1) continue;
            string key = StringSubstr(line, 0, p);
            string val = StringSubstr(line, p + 1);

            if (key == "version")            cfgVersion     = (int)StringToInteger(val);
            else if (key == "auto_det")      g_autoDetectedMin = (int)StringToInteger(val);
            else if (key == "auto_model")    g_autoModel    = (int)StringToInteger(val);
            else if (key == "broker_mode")   g_brokerMode   = (int)StringToInteger(val);
            else if (key == "broker_std")    g_brokerStd    = (int)StringToInteger(val);
            else if (key == "broker_rule")   g_brokerRule   = (int)StringToInteger(val);
            else if (key == "broker_preset") g_brokerPreset = (int)StringToInteger(val);
            else if (key == "own_mode")      g_ownMode      = (int)StringToInteger(val);
            else if (key == "own_std")       g_ownStd       = (int)StringToInteger(val);
            else if (key == "own_rule")      g_ownRule      = (int)StringToInteger(val);
            else if (key == "own_preset")    g_ownPreset    = (int)StringToInteger(val);
            else if (key == "range")
            {
                  int r = (int)StringToInteger(val);
                  if (r >= 0 && r <= 4) CurrentMode = (ENUM_EXPORT_RANGE)r;
            }
            else if (key == "theme")         g_theme      = (int)StringToInteger(val);
            else if (key == "panel_hidden")  g_panelHidden = ((int)StringToInteger(val) != 0);
            else if (key == "tf_mode")       g_tfMode     = (int)StringToInteger(val);
            else if (key == "tf_manual")     g_tfManual   = (int)StringToInteger(val);
            else if (key == "tf_fallback")   g_tfFallback = (int)StringToInteger(val);
            else if (key == "cust_from")     g_custFrom = val;
            else if (key == "cust_to")       g_custTo   = val;
            else if (key == "lists")         hasLists = true;
            else if (key == "field")
            {
                  string parts[];
                  int n = StringSplit(val, '|', parts);
                  if (n >= 1 && StringLen(parts[0]) > 0)
                  {
                        int k = ArraySize(g_fieldName);
                        ArrayResize(g_fieldName, k + 1);
                        ArrayResize(g_fieldVal, k + 1);
                        g_fieldName[k] = parts[0];
                        g_fieldVal[k]  = (n >= 2) ? parts[1] : "";
                  }
            }
            else if (key == "session")
            {
                  string sp[];
                  if (StringSplit(val, '|', sp) == 3)
                        AddSession(sp[0], (int)StringToInteger(sp[1]), (int)StringToInteger(sp[2]));
            }
            else if (key == "macro")
            {
                  string mp[];
                  if (StringSplit(val, '|', mp) == 3)
                        AddMacro(mp[0], (int)StringToInteger(mp[1]), (int)StringToInteger(mp[2]));
            }
      }
      FileClose(h);

      if (!hasLists)
      {
            DefaultSessions();
            DefaultMacros();
      }
      else if (cfgVersion < 3)
            DefaultSessions();     // older files used inclusive session ends; start from the new rounded defaults
      if (g_theme < 0 || g_theme > 2) g_theme = 2;
      if (g_tfMode < 0 || g_tfMode > 1) g_tfMode = 0;
      if (g_tfManual < 0 || g_tfManual >= ArraySize(TfNames)) g_tfManual = 0;
      if (g_tfFallback < -1 || g_tfFallback >= ArraySize(TfNames)) g_tfFallback = 0;
      if (g_brokerMode < 0 || g_brokerMode > 1) g_brokerMode = 0;
      if (g_ownMode < 0 || g_ownMode > 1) g_ownMode = 0;
      if (g_brokerRule < 0 || g_brokerRule > 4) g_brokerRule = DST_NONE;
      if (g_ownRule < 0 || g_ownRule > 4) g_ownRule = DST_NONE;
      if (g_brokerPreset >= ArraySize(PresetName)) g_brokerPreset = -1;
      if (g_ownPreset >= ArraySize(PresetName)) g_ownPreset = -1;
      return true;
}

//+------------------------------------------------------------------+
//| DST / time zone calculations                                     |
//+------------------------------------------------------------------+
datetime DateOnly(int y, int m, int d)
{
      MqlDateTime dt;
      dt.year = y;
      dt.mon = m;
      dt.day = d;
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;
      dt.day_of_week = 0;
      dt.day_of_year = 0;
      return StructToTime(dt);
}

datetime NthSundayDate(int y, int m, int n)
{
      datetime first = DateOnly(y, m, 1);
      MqlDateTime dt;
      TimeToStruct(first, dt);
      int add = (dt.day_of_week == 0) ? 0 : (7 - dt.day_of_week);
      return first + (datetime)((add + (n - 1) * 7) * 86400);
}

datetime LastSundayDate(int y, int m)
{
      int ny = y;
      int nm = m + 1;
      if (nm > 12) { nm = 1; ny++; }
      datetime last = DateOnly(ny, nm, 1) - 86400;
      MqlDateTime dt;
      TimeToStruct(last, dt);
      return last - (datetime)(dt.day_of_week * 86400);
}

// stdSec = standard (winter) offset from GMT in seconds
bool IsDstRule(int rule, datetime gmt, int stdSec)
{
      if (rule == DST_NONE) return false;

      MqlDateTime dt;
      TimeToStruct(gmt + stdSec, dt);
      int y = dt.year;
      datetime s, e;

      switch (rule)
      {
            case DST_EU:
                  s = LastSundayDate(y, 3) + 3600;
                  e = LastSundayDate(y, 10) + 3600;
                  return (gmt >= s && gmt < e);

            case DST_US:
                  s = NthSundayDate(y, 3, 2) + 7200 - stdSec;
                  e = NthSundayDate(y, 11, 1) + 3600 - stdSec;
                  return (gmt >= s && gmt < e);

            case DST_AU:
                  s = NthSundayDate(y, 10, 1) + 7200 - stdSec;
                  e = NthSundayDate(y, 4, 1) + 7200 - stdSec;
                  return (gmt >= s || gmt < e);

            case DST_NZ:
                  s = LastSundayDate(y, 9) + 7200 - stdSec;
                  e = NthSundayDate(y, 4, 1) + 7200 - stdSec;
                  return (gmt >= s || gmt < e);
      }
      return false;
}

datetime ZoneGmtToLocal(datetime gmt, int stdMin, int rule)
{
      int stdSec = stdMin * 60;
      return gmt + stdSec + (IsDstRule(rule, gmt, stdSec) ? 3600 : 0);
}

datetime ZoneLocalToGmt(datetime local, int stdMin, int rule)
{
      int stdSec = stdMin * 60;
      datetime gStd = local - stdSec;
      datetime gDst = local - stdSec - 3600;
      if (rule != DST_NONE && IsDstRule(rule, gDst, stdSec)) return gDst;
      return gStd;
}

// --- Original (Auto) broker logic: server = GMT+2, GMT+3 during EU DST ---
datetime GetLastSunday(int year, int month) {
    MqlDateTime dt;
    dt.year = year;
    dt.mon = (month == 12) ? 1 : month + 1;
    dt.day = 1;
    dt.hour = 1;
    dt.min = 0;
    dt.sec = 0;

    datetime lastDay = StructToTime(dt) - 86400;
    TimeToStruct(lastDay, dt);

    datetime sunday = lastDay - (dt.day_of_week * 86400);
    return sunday;
}

bool LegacyBrokerDST(datetime gmtTime) {
    MqlDateTime dt;
    TimeToStruct(gmtTime, dt);

    datetime dstStart = GetLastSunday(dt.year, 3);
    datetime dstEnd = GetLastSunday(dt.year, 10);

    return (gmtTime >= dstStart && gmtTime < dstEnd);
}

datetime LegacyBrokerToGMT(datetime brokerTime) {
      MqlDateTime dt;
      TimeToStruct(brokerTime, dt);

      datetime dstStart = GetLastSunday(dt.year, 3);
      datetime dstEnd = GetLastSunday(dt.year, 10);

      bool isDstApprox = (brokerTime >= (dstStart + 7200) && brokerTime < (dstEnd + 7200));
      int offset = isDstApprox ? 3 : 2;

      return brokerTime - (offset * 3600);
}

// Human readable summer-time calendar of a zone for a given year
string RuleShort(int r)
{
      switch (r)
      {
            case DST_EU: return "EU";
            case DST_US: return "US";
            case DST_AU: return "AU";
            case DST_NZ: return "NZ";
      }
      return "-";
}

// Short summer-time calendar of a zone for a given year (labels hold at most 63 characters)
string DstCalendarText(string name, int rule, int stdMin, int year)
{
      if (rule == DST_NONE)
            return name + ": no summer time (fixed " + OffsetStr(stdMin) + ")";

      int stdSec = stdMin * 60;
      datetime s = 0, e = 0;
      switch (rule)
      {
            case DST_EU:
                  s = LastSundayDate(year, 3) + 3600;
                  e = LastSundayDate(year, 10) + 3600;
                  break;
            case DST_US:
                  s = NthSundayDate(year, 3, 2) + 7200 - stdSec;
                  e = NthSundayDate(year, 11, 1) + 3600 - stdSec;
                  break;
            case DST_AU:
                  s = NthSundayDate(year, 10, 1) + 7200 - stdSec;
                  e = NthSundayDate(year, 4, 1) + 7200 - stdSec;
                  break;
            case DST_NZ:
                  s = LastSundayDate(year, 9) + 7200 - stdSec;
                  e = NthSundayDate(year, 4, 1) + 7200 - stdSec;
                  break;
      }
      datetime sLocal = s + stdSec;           // clock reading just before the shift forward
      datetime eLocal = e + stdSec + 3600;    // clock reading just before the shift back
      return name + "  +1h " + TimeToString(sLocal, TIME_DATE|TIME_MINUTES) + " | -1h " +
             TimeToString(eLocal, TIME_DATE|TIME_MINUTES) + " (" + RuleShort(rule) + ")";
}

// --- Auto-detect: server time (TimeTradeServer) vs PC GMT ---
// The current offset is measured, then matched against the known summer-time calendars:
//   model 1: GMT+2 / GMT+3, switching on EU dates (original EA logic)
//   model 2: GMT+2 / GMT+3, switching on US dates (New-York-close servers)
//   model 3: none of them match -> fixed offset (no summer time)
// A model that already matched is kept while it still matches (so it does not flip back and forth).
void UpdateAutoDetect()
{
      if (!(bool)TerminalInfoInteger(TERMINAL_CONNECTED)) return;
      datetime gmt = TimeGMT();
      datetime srv = TimeTradeServer();
      int det = (int)MathRound((double)(srv - gmt) / 900.0) * 15;
      if (det < -720 || det > 840) return;

      bool eu = (det == (LegacyBrokerDST(gmt) ? 180 : 120));
      bool us = (det == (IsDstRule(DST_US, gmt, 7200) ? 180 : 120));

      int model;
      if ((g_autoModel == 1 || g_autoModel == 0) && eu) model = 1;
      else if (g_autoModel == 2 && us)                  model = 2;
      else if (eu)                                      model = 1;
      else if (us)                                      model = 2;
      else                                              model = 3;

      if (det != g_autoDetectedMin || model != g_autoModel)
      {
            g_autoDetectedMin = det;
            g_autoModel = model;
            SaveSettings();
      }
}

int AutoModelNow()
{
      return (g_autoModel == 0) ? 1 : g_autoModel;
}

string AutoDetectNote()
{
      if (g_autoModel == 0)
            return "Waiting for a server connection to detect the broker time zone (EU summer-time dates assumed meanwhile).";
      if (g_autoModel == 1)
            return "Detected " + OffsetStr(g_autoDetectedMin) + " now - GMT+2/+3 server, EU summer-time dates.";
      if (g_autoModel == 2)
            return "Detected " + OffsetStr(g_autoDetectedMin) + " now - GMT+2/+3 server, US summer-time dates.";
      return "Detected " + OffsetStr(g_autoDetectedMin) + " now - no known summer-time pattern, treated as fixed. Use Manual if your broker shifts for DST.";
}

// effective rule of the broker clock (what is really used for the calculations)
void BrokerRuleInfo(int &rule, int &stdMin)
{
      if (g_brokerMode == 1)
      {
            rule = g_brokerRule;
            stdMin = g_brokerStd;
            return;
      }
      int m = AutoModelNow();
      if (m == 1)      { rule = DST_EU;   stdMin = 120; }
      else if (m == 2) { rule = DST_US;   stdMin = 120; }
      else             { rule = DST_NONE; stdMin = g_autoDetectedMin; }
}

// --- Broker time zone (Auto or Manual) ---
bool BrokerDstAt(datetime gmt)
{
      int rule, stdMin;
      BrokerRuleInfo(rule, stdMin);
      if (g_brokerMode == 0 && rule == DST_EU) return LegacyBrokerDST(gmt);
      return IsDstRule(rule, gmt, stdMin * 60);
}

int BrokerOffsetSecAt(datetime gmt)
{
      int rule, stdMin;
      BrokerRuleInfo(rule, stdMin);
      if (g_brokerMode == 0 && rule == DST_EU) return LegacyBrokerDST(gmt) ? 10800 : 7200;
      return stdMin * 60 + (IsDstRule(rule, gmt, stdMin * 60) ? 3600 : 0);
}

datetime GMTToBroker(datetime gmt)
{
      return gmt + BrokerOffsetSecAt(gmt);
}

datetime BrokerToGMT(datetime brokerTime)
{
      int rule, stdMin;
      BrokerRuleInfo(rule, stdMin);
      if (g_brokerMode == 0 && rule == DST_EU) return LegacyBrokerToGMT(brokerTime);
      return ZoneLocalToGmt(brokerTime, stdMin, rule);
}

// --- New York (fixed reference zone: GMT-5, GMT-4 during US DST) ---
bool IsNewYorkDST(datetime gmt)
{
      return IsDstRule(DST_US, gmt, -18000);
}

datetime GMTToNewYork(datetime gmtTime)
{
      return gmtTime - 18000 + (IsNewYorkDST(gmtTime) ? 3600 : 0);
}

//+------------------------------------------------------------------+
//| Session & Macro Determination Function                           |
//+------------------------------------------------------------------+
bool InWindow(int t, int s, int e)
{
      if (s <= e) return (t >= s && t <= e);
      return (t >= s || t <= e);          // window crossing midnight
}

// session window: start included, end excluded (may cross midnight)
bool InSession(int t, int s, int e)
{
      if (s == e) return false;
      if (s < e) return (t >= s && t < e);
      return (t >= s || t < e);
}

void GetNYTimeAndDetails(datetime brokerTime, string &nyTimeStr, string &sessionStr, string &macroStr)
{
      datetime gmt = BrokerToGMT(brokerTime);
      datetime nyTime = GMTToNewYork(gmt);

      nyTimeStr = TimeToString(nyTime, TIME_DATE|TIME_MINUTES);
      StringReplace(nyTimeStr, ".", "-");

      MqlDateTime nyStruct;
      TimeToStruct(nyTime, nyStruct);

      int totalMinutes = nyStruct.hour * 60 + nyStruct.min;

      sessionStr = "Closed";
      for (int i = 0; i < ArraySize(g_sessName); i++)
      {
            if (InSession(totalMinutes, g_sessStart[i], g_sessEnd[i]))
            {
                  sessionStr = g_sessName[i];
                  break;
            }
      }

      macroStr = "None";
      for (int j = 0; j < ArraySize(g_macroName); j++)
      {
            if (InWindow(totalMinutes, g_macroStart[j], g_macroEnd[j]))
            {
                  macroStr = g_macroName[j];
                  break;
            }
      }
}

void WritePureString(int fileHandle, string text)
{
      uchar array[];
      int len = StringToCharArray(text, array, 0, StringLen(text), CP_UTF8);
      if (len > 0)
      {
            FileWriteArray(fileHandle, array, 0, len);
      }
}

//+------------------------------------------------------------------+
//| Timeframe tracking (timeframe of the chart at position open)     |
//+------------------------------------------------------------------+
int SmallestChartTF(string sym)
{
      int best = 0;
      int bestSec = 0;
      long id = ChartFirst();
      while (id >= 0)
      {
            if (ChartSymbol(id) == sym)
            {
                  ENUM_TIMEFRAMES p = ChartPeriod(id);
                  int sec = PeriodSeconds(p);
                  if (best == 0 || sec < bestSec)
                  {
                        best = (int)p;
                        bestSec = sec;
                  }
            }
            id = ChartNext(id);
      }
      return best;
}

// markUnknown = true: positions already open at EA start are stored as "unknown" (0)
void TrackOpenPositions(bool markUnknown)
{
      int total = PositionsTotal();
      for (int i = 0; i < total; i++)
      {
            ulong t = PositionGetTicket(i);
            if (t == 0) continue;
            long pid = PositionGetInteger(POSITION_IDENTIFIER);
            string gv = "OBX_TF_" + IntegerToString(pid);
            if (GlobalVariableCheck(gv)) continue;

            double tf = 0;
            if (!markUnknown)
                  tf = (double)SmallestChartTF(PositionGetString(POSITION_SYMBOL));
            GlobalVariableSet(gv, tf);
      }
}

string TimeframeForPosition(ulong positionID)
{
      if (g_tfMode == 1)
            return TfNames[g_tfManual];

      string tf = "";
      string gv = "OBX_TF_" + IntegerToString((long)positionID);
      if (GlobalVariableCheck(gv))
      {
            int p = (int)GlobalVariableGet(gv);
            if (p > 0) tf = StringSubstr(EnumToString((ENUM_TIMEFRAMES)p), 7);
      }
      if (tf == "" && g_tfFallback >= 0)
            tf = TfNames[g_tfFallback];
      return tf;
}

//+------------------------------------------------------------------+
//| UI primitives                                                    |
//+------------------------------------------------------------------+
void ApplyTheme()
{
      bool light = false;
      if (g_theme == 1) light = true;
      else if (g_theme == 2)
      {
            long bgc = ChartGetInteger(0, CHART_COLOR_BACKGROUND);
            int r = (int)(bgc & 0xFF);
            int g = (int)((bgc >> 8) & 0xFF);
            int b = (int)((bgc >> 16) & 0xFF);
            light = ((r * 299 + g * 587 + b * 114) / 1000 > 140);
      }
      g_isLight = light;

      if (light)
      {
            COL_BG = C'246,247,250';      COL_BORDER = C'160,168,185';
            COL_BTN = C'222,227,237';     COL_BTN_TXT = C'25,30,45';
            COL_EDIT_BG = clrWhite;       COL_EDIT_TXT = C'20,24,35';   COL_EDIT_BORDER = C'130,138,155';
            T_TEXT = C'25,30,45';         T_MUTED = C'70,76,95';        T_TITLE = C'140,95,0';
            T_NOTE = C'115,90,0';         T_FAINT = C'95,100,115';      T_WARN = C'190,40,0';
            T_INFO = C'0,85,155';         T_OK = C'0,115,40';
      }
      else
      {
            COL_BG = C'20,24,33';         COL_BORDER = C'50,60,80';
            COL_BTN = C'40,46,60';        COL_BTN_TXT = clrWhite;
            COL_EDIT_BG = C'30,36,50';    COL_EDIT_TXT = clrWhite;      COL_EDIT_BORDER = C'90,100,125';
            T_TEXT = clrWhite;            T_MUTED = clrSilver;          T_TITLE = clrGold;
            T_NOTE = clrKhaki;            T_FAINT = clrGray;            T_WARN = clrOrangeRed;
            T_INFO = clrLightSkyBlue;     T_OK = clrLime;
      }
}

// labels are designed with dark-theme colours; map them to the active theme
color ThemeColor(color c)
{
      if (c == clrWhite) return T_TEXT;
      if (c == clrSilver || c == clrLightGray) return T_MUTED;
      if (c == clrGold) return T_TITLE;
      if (c == clrKhaki) return T_NOTE;
      if (c == clrGray) return T_FAINT;
      if (c == clrOrangeRed) return T_WARN;
      if (c == clrLightSkyBlue) return T_INFO;
      if (c == clrLime) return T_OK;
      return c;
}

void UiRect(string name, int x, int y, int w, int h, color bg, color border, int z)
{
      if (ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_COLOR, border);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, z);
}

void UiLabel(string name, int x, int y, string text, color clr, int size = 8, string font = "Arial", int z = 11)
{
      if (text == "") text = " ";                       // an empty OBJ_LABEL would show the default text "Label"
      if (StringLen(text) > 63) text = StringSubstr(text, 0, 63);   // MT5 labels cannot hold more than 63 characters
      if (ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_FONT, font);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetInteger(0, name, OBJPROP_COLOR, ThemeColor(clr));
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, z);
}

// word-wrapped note: one label per line (labels are limited to 63 characters); returns the number of lines
int UiNote(string name, int x, int y, string text, color clr, int size, int lineH)
{
      int maxc = 58;
      int n = 0;
      string rest = text;
      while (StringLen(rest) > 0)
      {
            string line;
            if (StringLen(rest) <= maxc)
            {
                  line = rest;
                  rest = "";
            }
            else
            {
                  int cut = maxc;
                  for (int i = maxc; i > 0; i--)
                  {
                        if (StringGetCharacter(rest, i) == ' ') { cut = i; break; }
                  }
                  line = StringSubstr(rest, 0, cut);
                  rest = StringSubstr(rest, cut);
                  StringTrimLeft(rest);
            }
            UiLabel(name + "_" + IntegerToString(n), x, y + n * lineH, line, clr, size);
            n++;
      }
      return n;
}

void UiButton(string name, int x, int y, int w, int h, string text, color bg, color fg, int size = 8, int z = 11)
{
      if (bg == COL_BTN) fg = COL_BTN_TXT;
      if (ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetInteger(0, name, OBJPROP_COLOR, fg);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, COL_EDIT_BORDER);
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, z);
}

void UiEdit(string name, int x, int y, int w, int h, string text, int z = 11)
{
      if (ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, name, OBJPROP_COLOR, COL_EDIT_TXT);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, COL_EDIT_BG);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, COL_EDIT_BORDER);
      ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_LEFT);
      ObjectSetInteger(0, name, OBJPROP_READONLY, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, z);
}

void UiEditRO(string name, int x, int y, int w, int h, string text, int z = 11)
{
      UiEdit(name, x, y, w, h, text, z);
      ObjectSetInteger(0, name, OBJPROP_READONLY, true);
}

void DrawQR(string name, int x, int y, int scale)
{
      int quiet = 3;
      int size = (QR_N + 2 * quiet) * scale;
      uint px[];
      ArrayResize(px, size * size);
      for (int i = 0; i < size * size; i++) px[i] = 0xFFFFFFFF;
      for (int r = 0; r < QR_N; r++)
      {
            for (int c = 0; c < QR_N; c++)
            {
                  if (StringGetCharacter(QR_ROWS[r], c) != '1') continue;
                  for (int dy = 0; dy < scale; dy++)
                        for (int dx = 0; dx < scale; dx++)
                              px[((r + quiet) * scale + dy) * size + (c + quiet) * scale + dx] = 0xFF000000;
            }
      }
      if (!ResourceCreate("OBX_QR", px, size, size, 0, 0, size, COLOR_FORMAT_ARGB_NORMALIZE)) return;
      if (ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_BITMAP_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_BMPFILE, "::OBX_QR");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 11);
}

void SetLabelText(string name, string text)
{
      if (text == "") text = " ";
      if (StringLen(text) > 63) text = StringSubstr(text, 0, 63);
      if (ObjectFind(0, name) >= 0) ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void SyncEdit(string name, string &var)
{
      if (ObjectFind(0, name) >= 0) var = ObjectGetString(0, name, OBJPROP_TEXT);
}

void SyncEdits()
{
      SyncEdit("OBX_S_ED_CFROM", g_custFrom);
      SyncEdit("OBX_S_ED_CTO",   g_custTo);
      SyncEdit("OBX_S_ED_FNAME", g_edFName);
      SyncEdit("OBX_S_ED_FVAL",  g_edFVal);
      SyncEdit("OBX_S_ED_SNAME", g_edSName);
      SyncEdit("OBX_S_ED_SFROM", g_edSFrom);
      SyncEdit("OBX_S_ED_STO",   g_edSTo);
      SyncEdit("OBX_S_ED_MNAME", g_edMName);
      SyncEdit("OBX_S_ED_MFROM", g_edMFrom);
      SyncEdit("OBX_S_ED_MTO",   g_edMTo);
}

//+------------------------------------------------------------------+
//| Main panel on the chart                                          |
//+------------------------------------------------------------------+
int GetPanelX()
{
      int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      return chartWidth - PANEL_WIDTH - MARGIN_RIGHT;
}

void RenderMainPanel()
{
      int x = GetPanelX();
      int y = MARGIN_TOP;

      if (g_panelHidden)
      {
            string names[] = {"OBX_MainBg", "OBX_MainHdr", "OBX_MainSub", "OBX_InfoBroker", "OBX_InfoNy", "OBX_InfoLocal",
                              "OBX_InfoDst", "OBX_InfoWarn", "OBX_InfoRange", "OBX_BtnSettings", "OBX_BtnExportNow", "OBX_BtnHide"};
            for (int i = 0; i < ArraySize(names); i++)
                  ObjectDelete(0, names[i]);
            int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
            UiButton("OBX_BtnShow", cw - 64 - MARGIN_RIGHT, y, 64, 22, "MET  <", COL_BTN, clrWhite, 9, 1);
            return;
      }
      ObjectDelete(0, "OBX_BtnShow");

      UiRect("OBX_MainBg", x, y, PANEL_WIDTH, PANEL_HEIGHT, COL_BG, COL_BORDER, 0);
      UiLabel("OBX_MainHdr",    x + 12, y + 6,   EA_TITLE, clrGold, 13, "Arial Bold", 1);
      UiLabel("OBX_MainSub",    x + 12, y + 30,  EA_DESC, clrSilver, 8, "Arial", 1);
      UiLabel("OBX_InfoBroker", x + 12, y + 52,  "", clrSilver, 9, "Arial", 1);
      UiLabel("OBX_InfoNy",     x + 12, y + 72,  "", clrSilver, 9, "Arial", 1);
      UiLabel("OBX_InfoLocal",  x + 12, y + 92,  "", clrSilver, 9, "Arial", 1);
      UiLabel("OBX_InfoDst",    x + 12, y + 112, "", clrKhaki,  8, "Arial", 1);
      UiLabel("OBX_InfoWarn",   x + 12, y + 128, "", clrOrangeRed, 8, "Arial", 1);
      UiLabel("OBX_InfoRange",  x + 12, y + 142, "", clrLightSkyBlue, 8, "Arial", 1);

      UiButton("OBX_BtnSettings",  x + 12, y + 160, PANEL_WIDTH - 24, 26, "Settings", COL_BTN, clrWhite, 9, 1);
      UiButton("OBX_BtnExportNow", x + 12, y + 190, PANEL_WIDTH - 24, 28, "EXPORT NOW", clrDodgerBlue, clrWhite, 9, 1);
      UiButton("OBX_BtnHide",      x + PANEL_WIDTH - 34, y + 6, 24, 20, ">", COL_BTN, clrWhite, 9, 1);
}

void UpdateLiveInfoLabels()
{
      datetime pcGmt = TimeGMT();
      datetime tc = TimeCurrent();
      datetime calculatedBrokerTime = GMTToBroker(pcGmt);

      bool isMarketClosed = (calculatedBrokerTime - tc > 120);
      bool pcMismatch = false;

      datetime gmtNow;
      datetime brokerNow;
      if (InpAutoBrokerTime && isMarketClosed)
      {
            brokerNow = calculatedBrokerTime;
            gmtNow = pcGmt;
      }
      else
      {
            brokerNow = tc;
            gmtNow = BrokerToGMT(tc);
            if (!isMarketClosed)
            {
                  long diff = (long)(gmtNow - pcGmt);
                  if (diff < 0) diff = -diff;
                  if (diff > 300) pcMismatch = true;
            }
      }
      g_gmtNow = gmtNow;
      g_brokerNow = brokerNow;

      datetime nyNow = GMTToNewYork(gmtNow);
      datetime ownNow = (g_ownMode == 0) ? TimeLocal() : ZoneGmtToLocal(gmtNow, g_ownStd, g_ownRule);

      bool brokerDst = BrokerDstAt(gmtNow);
      bool nyDst = IsNewYorkDST(gmtNow);
      int brokerOff = BrokerOffsetSecAt(gmtNow);
      int nyOff = nyDst ? -14400 : -18000;

      string ownOffTxt = "PC clock";
      if (g_ownMode == 1)
      {
            int ownOff = g_ownStd * 60 + (IsDstRule(g_ownRule, gmtNow, g_ownStd * 60) ? 3600 : 0);
            ownOffTxt = OffsetStr(ownOff / 60);
      }

      SetLabelText("OBX_InfoBroker", "Broker: " + TimeToString(brokerNow, TIME_DATE|TIME_SECONDS));
      SetLabelText("OBX_InfoNy",     "New York: " + TimeToString(nyNow, TIME_DATE|TIME_SECONDS));
      SetLabelText("OBX_InfoLocal",  "Local: " + TimeToString(ownNow, TIME_DATE|TIME_SECONDS));
      SetLabelText("OBX_InfoDst",    "DST->Brk:" + (brokerDst ? "Summer" : "Winter") + " (" + ShortOffset(brokerOff) + ") | NY:" +
                                     (nyDst ? "Summer" : "Winter") + " (" + ShortOffset(nyOff) + ")");
      SetLabelText("OBX_InfoWarn",   pcMismatch ? "! Broker time zone differs from PC clock - check Settings" : "");
      SetLabelText("OBX_InfoRange",  "Range: " + RangeName(CurrentMode) + "  |  Local " + ownOffTxt);

      // live clocks inside the Time Zones tab
      SetLabelText("OBX_S_LV_GMT",    "GMT:        " + TimeToString(gmtNow, TIME_DATE|TIME_SECONDS));
      SetLabelText("OBX_S_LV_BROKER", "Broker:    " + TimeToString(brokerNow, TIME_DATE|TIME_SECONDS) + "   (" + OffsetStr(brokerOff / 60) + ")");
      SetLabelText("OBX_S_LV_NY",     "New York: " + TimeToString(nyNow, TIME_DATE|TIME_SECONDS) + "   (" + OffsetStr(nyOff / 60) + ")");
      SetLabelText("OBX_S_LV_OWN",    "Local:      " + TimeToString(ownNow, TIME_DATE|TIME_SECONDS) + "   (" + ownOffTxt + ")");

      ChartRedraw();
}

//+------------------------------------------------------------------+
//| Settings window                                                  |
//+------------------------------------------------------------------+
void ZoneBlock(string p, string title, int mode, int std, int rule, int preset, string autoTxt, string autoNote, int x, int y)
{
      UiLabel("OBX_S_" + p + "T", x, y, title, clrGold, 9, "Arial Bold");
      UiButton("OBX_S_" + p + "MODE", x, y + 22, 300, 22, "Mode: " + ((mode == 0) ? autoTxt : "Manual"), COL_BTN, clrWhite, 8);
      UiLabel("OBX_S_" + p + "HINT", x + 310, y + 27, "(click to switch Auto / Manual)", clrGray, 8);
      if (mode == 0)
            UiNote("OBX_S_" + p + "NOTE", x, y + 52, autoNote, clrKhaki, 8, 14);
      if (mode == 1)
      {
            datetime gm = (g_gmtNow > 0) ? g_gmtNow : TimeGMT();
            bool dstNow = IsDstRule(rule, gm, std * 60);
            string pn = (preset >= 0 && preset < ArraySize(PresetName)) ? PresetName[preset] : "- choose -";
            UiButton("OBX_S_" + p + "PRESET", x, y + 50, 200, 22, "Preset: " + pn, COL_BTN, clrWhite, 8);
            UiLabel("OBX_S_" + p + "L1", x + 212, y + 54, "Winter offset:", clrSilver, 8);
            UiButton("OBX_S_" + p + "DEC", x + 290, y + 50, 26, 22, "<", COL_BTN, clrWhite, 9);
            UiLabel("OBX_S_" + p + "OFF", x + 322, y + 54, OffsetStr(std), clrWhite, 9, "Arial Bold");
            UiButton("OBX_S_" + p + "INC", x + 392, y + 50, 26, 22, ">", COL_BTN, clrWhite, 9);
            UiButton("OBX_S_" + p + "RULE", x + 428, y + 50, 146, 22, "Summer-time rule: " + RuleName(rule), COL_BTN, clrWhite, 8);
            UiLabel("OBX_S_" + p + "NOW", x, y + 78, "Now: " + OffsetStr(std + (dstNow ? 60 : 0)) + (dstNow ? "  (summer time active)" : "  (standard/winter time)"), clrKhaki, 8);
            UiLabel("OBX_S_" + p + "HELP", x, y + 92, "Rule: which DST calendar the server follows (None = fixed).", clrGray, 8);
      }
}

void BuildTabExport(int x, int y)
{
      UiLabel("OBX_S_L1", x, y, "Export range (broker server time):", clrSilver, 9);
      string nm[5] = {"Today", "This Week", "This Month", "All History", "Custom Range"};
      for (int i = 0; i < 5; i++)
      {
            bool act = (CurrentMode == RangeAt(i));
            UiButton("OBX_S_RNG_" + IntegerToString(i), x + i * 112, y + 24, 106, 26, nm[i],
                     act ? clrForestGreen : COL_BTN, clrWhite, 9);
      }
      UiLabel("OBX_S_L2", x, y + 68, "Custom range (used when 'Custom Range' is selected):", clrSilver, 9);
      UiLabel("OBX_S_L3", x, y + 94, "From (YYYY.MM.DD):", clrWhite, 9);
      UiEdit("OBX_S_ED_CFROM", x + 130, y + 90, 110, 22, g_custFrom);
      UiLabel("OBX_S_L4", x + 270, y + 94, "To (YYYY.MM.DD):", clrWhite, 9);
      UiEdit("OBX_S_ED_CTO", x + 390, y + 90, 110, 22, g_custTo);
      UiLabel("OBX_S_L5", x, y + 128, "Selected: " + RangeName(CurrentMode), clrKhaki, 9);
      UiButton("OBX_S_EXPORT", x, y + 154, 220, 34, "EXPORT NOW", clrDodgerBlue, clrWhite, 10);
      UiLabel("OBX_S_STATUS", x, y + 200, g_statusMsg, clrLime, 9);
      UiLabel("OBX_S_L6", x, y + 236, "Saved to MQL5\\Files\\Trades\\<ticket>\\Trade-<ticket>.md", clrGray, 8);
      UiLabel("OBX_S_L7", x, y + 252, "Dates use broker server time; the 'To' date is included.", clrGray, 8);
}

void BuildTabFields(int x, int y)
{
      int nDef = ArraySize(DefaultFields);
      UiLabel("OBX_S_FH1", x, y, "Default fields (" + IntegerToString(nDef) + ") - always exported, fixed:", clrSilver, 9);
      for (int i = 0; i < nDef; i++)
      {
            int col = i / 10;
            int row = i % 10;
            UiLabel("OBX_S_DF_" + IntegerToString(i), x + col * 145, y + 20 + row * 14, DefaultFields[i], clrLightGray, 8);
      }

      int nExtra = ArraySize(g_fieldName);
      int maxPage = (nExtra > 0) ? (nExtra - 1) / FIELD_ROWS : 0;
      if (g_fieldPage > maxPage) g_fieldPage = maxPage;
      if (g_fieldPage < 0) g_fieldPage = 0;

      UiLabel("OBX_S_FH2", x, y + 166, "Extra fields (" + IntegerToString(nExtra) + ") - added after 'notes' in every note:", clrSilver, 9);
      UiButton("OBX_S_FUP", x + 520, y + 162, 26, 20, "^", COL_BTN, clrWhite, 8);
      UiButton("OBX_S_FDN", x + 550, y + 162, 26, 20, "v", COL_BTN, clrWhite, 8);

      for (int r = 0; r < FIELD_ROWS; r++)
      {
            int idx = g_fieldPage * FIELD_ROWS + r;
            if (idx >= nExtra) break;
            string v = g_fieldVal[idx];
            if (StringLen(v) > 40) v = StringSubstr(v, 0, 40) + "...";
            UiLabel("OBX_S_FN_" + IntegerToString(r), x, y + 188 + r * 20, g_fieldName[idx], clrWhite, 9);
            UiLabel("OBX_S_FV_" + IntegerToString(r), x + 180, y + 188 + r * 20, "= \"" + v + "\"", clrSilver, 9);
            UiButton("OBX_S_FDEL_" + IntegerToString(idx), x + 520, y + 186 + r * 20, 26, 18, "X", C'120,40,40', clrWhite, 8);
      }

      UiLabel("OBX_S_FA1", x, y + 296, "Name:", clrWhite, 9);
      UiEdit("OBX_S_ED_FNAME", x + 45, y + 292, 150, 22, g_edFName);
      UiLabel("OBX_S_FA2", x + 210, y + 296, "Default value:", clrWhite, 9);
      UiEdit("OBX_S_ED_FVAL", x + 290, y + 292, 190, 22, g_edFVal);
      UiButton("OBX_S_FADD", x + 495, y + 291, 70, 24, "+ Add", clrForestGreen, clrWhite, 9);
}

void BuildTabZones(int x, int y)
{
      ZoneBlock("B", "Broker server time zone", g_brokerMode, g_brokerStd, g_brokerRule, g_brokerPreset,
                "Auto-detect", AutoDetectNote(), x, y);
      ZoneBlock("O", "Your own time zone (display only)", g_ownMode, g_ownStd, g_ownRule, g_ownPreset,
                "Auto (PC clock)", "Uses the time and time zone of this PC.", x, y + 112);

      datetime gm = (g_gmtNow > 0) ? g_gmtNow : TimeGMT();
      MqlDateTime gd;
      TimeToStruct(gm, gd);
      int bRule, bStd;
      BrokerRuleInfo(bRule, bStd);

      UiLabel("OBX_S_RF1", x, y + 224, "Reference zone: New York (GMT-5 / GMT-4 with US DST)", clrGold, 9, "Arial Bold");
      UiLabel("OBX_S_RF2", x, y + 240, "Summer time: +1h = clocks go forward, -1h = go back", clrGray, 8);
      UiLabel("OBX_S_CAL1", x, y + 256, DstCalendarText("Broker", bRule, bStd, gd.year), clrKhaki, 8);
      UiLabel("OBX_S_CAL2", x, y + 270, DstCalendarText("New York", DST_US, -300, gd.year), clrKhaki, 8);
      UiLabel("OBX_S_LV_GMT",    x, y + 292, "", clrWhite, 9, "Consolas");
      UiLabel("OBX_S_LV_BROKER", x, y + 307, "", clrWhite, 9, "Consolas");
      UiLabel("OBX_S_LV_NY",     x, y + 322, "", clrWhite, 9, "Consolas");
      UiLabel("OBX_S_LV_OWN",    x, y + 337, "", clrWhite, 9, "Consolas");
}

void BuildWindowList(string p, string title, int x, int y, int &page, string &names[], int &starts[], int &ends[],
                     string &edName, string &edFrom, string &edTo)
{
      int n = ArraySize(names);
      int maxPage = (n > 0) ? (n - 1) / ROWS_PER_PAGE : 0;
      if (page > maxPage) page = maxPage;
      if (page < 0) page = 0;

      UiLabel("OBX_S_" + p + "H", x, y, title + " (" + IntegerToString(n) + ")", clrGold, 9, "Arial Bold");
      UiButton("OBX_S_" + p + "UP", x + 230, y - 3, 26, 20, "^", COL_BTN, clrWhite, 8);
      UiButton("OBX_S_" + p + "DN", x + 260, y - 3, 26, 20, "v", COL_BTN, clrWhite, 8);

      for (int r = 0; r < ROWS_PER_PAGE; r++)
      {
            int idx = page * ROWS_PER_PAGE + r;
            if (idx >= n) break;
            string nm = names[idx];
            if (StringLen(nm) > 16) nm = StringSubstr(nm, 0, 16) + "..";
            UiLabel("OBX_S_" + p + "N_" + IntegerToString(r), x, y + 24 + r * 22, nm, clrWhite, 9);
            UiLabel("OBX_S_" + p + "T_" + IntegerToString(r), x + 125, y + 24 + r * 22, FmtHM(starts[idx]) + " - " + FmtHM(ends[idx]), clrSilver, 9);
            UiButton("OBX_S_" + p + "DEL_" + IntegerToString(idx), x + 252, y + 22 + r * 22, 26, 18, "X", C'120,40,40', clrWhite, 8);
      }

      UiLabel("OBX_S_" + p + "A0", x, y + 164, "Add:  name  |  from (HH:MM)  |  to (HH:MM)", clrSilver, 8);
      UiEdit("OBX_S_ED_" + p + "NAME", x, y + 182, 105, 22, edName);
      UiEdit("OBX_S_ED_" + p + "FROM", x + 110, y + 182, 55, 22, edFrom);
      UiEdit("OBX_S_ED_" + p + "TO", x + 170, y + 182, 55, 22, edTo);
      UiButton("OBX_S_" + p + "ADD", x + 232, y + 181, 50, 24, "+ Add", clrForestGreen, clrWhite, 9);
      UiButton("OBX_S_" + p + "RESET", x, y + 212, 160, 22, "Reset to defaults", COL_BTN, clrWhite, 8);
}

void BuildTabSessions(int x, int y)
{
      BuildWindowList("S", "Sessions (NY time)", x, y, g_sessPage, g_sessName, g_sessStart, g_sessEnd, g_edSName, g_edSFrom, g_edSTo);
      BuildWindowList("M", "Macros (NY time)", x + 300, y, g_macroPage, g_macroName, g_macroStart, g_macroEnd, g_edMName, g_edMFrom, g_edMTo);
      UiNote("OBX_S_N1", x, y + 250,
             "Times are New York time. Sessions: start included, end excluded (24:00 = midnight). Macros: start and end minutes are both included. The first matching row wins. A window may cross midnight (e.g. 22:00 - 02:00). Changes are saved automatically.",
             clrGray, 8, 13);
}

void BuildTabAdvanced(int x, int y)
{
      UiLabel("OBX_S_AH1", x, y, "Timeframe written to the 'timeframe' field", clrGold, 9, "Arial Bold");
      UiButton("OBX_S_TFMODE", x, y + 24, 420, 24,
               "Mode: " + ((g_tfMode == 0) ? "Auto - taken from your chart when the trade opens" : "Manual - always the timeframe chosen below"),
               COL_BTN, clrWhite, 8);
      if (g_tfMode == 1)
      {
            UiLabel("OBX_S_AL1", x, y + 62, "Timeframe:", clrWhite, 9);
            UiButton("OBX_S_TFDEC", x + 100, y + 58, 26, 24, "<", COL_BTN, clrWhite, 9);
            UiLabel("OBX_S_AL2", x + 138, y + 62, TfNames[g_tfManual], clrWhite, 10, "Arial Bold");
            UiButton("OBX_S_TFINC", x + 190, y + 58, 26, 24, ">", COL_BTN, clrWhite, 9);
      }
      else
      {
            UiLabel("OBX_S_AL1", x, y + 62, "If it cannot be detected use:", clrWhite, 9);
            UiButton("OBX_S_FBDEC", x + 190, y + 58, 26, 24, "<", COL_BTN, clrWhite, 9);
            UiLabel("OBX_S_AL2", x + 228, y + 62, (g_tfFallback < 0) ? "(empty)" : TfNames[g_tfFallback], clrWhite, 10, "Arial Bold");
            UiButton("OBX_S_FBINC", x + 300, y + 58, 26, 24, ">", COL_BTN, clrWhite, 9);
      }
      UiNote("OBX_S_AN1", x, y + 94,
             "MT5 does not store the timeframe of a trade. Auto only knows trades that opened while MET was running and a chart of that symbol was open (the smallest timeframe of those charts is used). Others get the fallback.",
             clrGray, 8, 13);

      UiLabel("OBX_S_AH2", x, y + 164, "Panel theme", clrGold, 9, "Arial Bold");
      string th[3] = {"Dark", "Light", "Auto"};
      for (int i = 0; i < 3; i++)
            UiButton("OBX_S_THEME_" + IntegerToString(i), x + i * 112, y + 188, 106, 26, th[i],
                     (g_theme == i) ? clrDodgerBlue : COL_BTN, clrWhite, 9);
      UiNote("OBX_S_AN3", x, y + 224, "Auto follows the chart background colour (light chart = light panel).", clrGray, 8, 13);
}

void BuildTabAbout(int x, int y)
{
      UiLabel("OBX_S_BH1", x, y, EA_TITLE, clrGold, 16, "Arial Bold");
      int n = UiNote("OBX_S_BH2", x, y + 30, "Export MT5 trades to Markdown notes for your Obsidian trading journal.", clrSilver, 9, 14);
      UiLabel("OBX_S_BH3", x, y + 34 + n * 14, "Settings: MQL5\\Files\\" + SETTINGS_FILE, clrGray, 8);

      int y2 = y + 34 + n * 14 + 26;
      UiLabel("OBX_S_BL1", x, y2, "Telegram", clrWhite, 9, "Arial Bold");
      UiEditRO("OBX_S_ED_TG", x, y2 + 18, 340, 22, URL_TELEGRAM);
      UiLabel("OBX_S_BL2", x, y2 + 50, "GitHub", clrWhite, 9, "Arial Bold");
      UiEditRO("OBX_S_ED_GH", x, y2 + 68, 340, 22, URL_GITHUB);
      UiLabel("OBX_S_BL3", x, y2 + 100, "Support the project - EVM wallet address", clrWhite, 9, "Arial Bold");
      UiEditRO("OBX_S_ED_WL", x, y2 + 118, 340, 22, WALLET_ADDR);

      int y3 = y2 + 148;
      int k = UiNote("OBX_S_BN1", x, y3, "Select a box and press Ctrl+C to copy (MT5 cannot open links itself).", clrGray, 8, 13);
      y3 += k * 13 + 2;
      k = UiNote("OBX_S_BN2", x, y3, "Works on Ethereum, BSC, Polygon, Arbitrum, Optimism, Base and other EVM networks.", clrGray, 8, 13);
      y3 += k * 13 + 2;
      UiNote("OBX_S_BN3", x, y3, "Send only on an EVM network - funds sent on other networks (BTC, TRON...) are lost.", clrOrangeRed, 8, 13);

      DrawQR("OBX_S_QR", x + 380, y + 40, 5);
      UiLabel("OBX_S_BN4", x + 395, y + 222, "Scan to donate (EVM)", clrGray, 8);
}

void BuildSettingsUI()
{
      ObjectsDeleteAll(0, "OBX_S_");
      if (!g_settingsOpen)
      {
            ChartRedraw();
            return;
      }

      int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      int x0 = 10;                 // left side of the chart
      int y0 = 10;

      UiRect("OBX_S_BG", x0, y0, WIN_W, WIN_H, COL_BG, COL_BORDER, 10);
      UiLabel("OBX_S_TITLE", x0 + 14, y0 + 8, EA_TITLE + " - Settings", clrGold, 11, "Arial Bold");
      UiButton("OBX_S_CLOSE", x0 + WIN_W - 34, y0 + 6, 26, 22, "X", C'120,40,40', clrWhite, 9);

      string tabs[6] = {"Export", "Fields", "Time Zones", "Sessions", "Advanced", "About"};
      for (int i = 0; i < 6; i++)
      {
            UiButton("OBX_S_TAB_" + IntegerToString(i), x0 + 14 + i * 98, y0 + 38, 94, 26, tabs[i],
                     (g_tab == i) ? clrDodgerBlue : COL_BTN, clrWhite, 9);
      }

      int cx = x0 + 20;
      int cy = y0 + 78;
      switch (g_tab)
      {
            case 0: BuildTabExport(cx, cy);   break;
            case 1: BuildTabFields(cx, cy);   break;
            case 2: BuildTabZones(cx, cy);    break;
            case 3: BuildTabSessions(cx, cy); break;
            case 4: BuildTabAdvanced(cx, cy); break;
            case 5: BuildTabAbout(cx, cy);    break;
      }

      UpdateLiveInfoLabels();
      ChartRedraw();
}

void UpdateUI()
{
      ApplyTheme();
      if (g_panelHidden) g_settingsOpen = false;
      RenderMainPanel();
      UpdateLiveInfoLabels();
      BuildSettingsUI();
      ChartRedraw();
}

//+------------------------------------------------------------------+
//| Settings actions                                                 |
//+------------------------------------------------------------------+
void ZoneAction(bool broker, string act)
{
      int mode   = broker ? g_brokerMode : g_ownMode;
      int std    = broker ? g_brokerStd : g_ownStd;
      int rule   = broker ? g_brokerRule : g_ownRule;
      int preset = broker ? g_brokerPreset : g_ownPreset;

      if (act == "MODE")
            mode = (mode == 0) ? 1 : 0;
      else if (act == "PRESET")
      {
            preset = (preset + 1) % ArraySize(PresetName);
            std = PresetOff[preset];
            rule = PresetRule[preset];
      }
      else if (act == "DEC") { std = StepOffset(std, -1); preset = -1; }
      else if (act == "INC") { std = StepOffset(std, 1);  preset = -1; }
      else if (act == "RULE") { rule = (rule + 1) % 5;    preset = -1; }

      if (broker)
      {
            g_brokerMode = mode; g_brokerStd = std; g_brokerRule = rule; g_brokerPreset = preset;
      }
      else
      {
            g_ownMode = mode; g_ownStd = std; g_ownRule = rule; g_ownPreset = preset;
      }
      SaveSettings();
}

void AddExtraField()
{
      string key = SanitizeKey(g_edFName);
      if (StringLen(key) == 0)
      {
            Alert("Field name is empty or invalid.");
            return;
      }
      if (FieldNameTaken(key))
      {
            Alert("A field named '" + key + "' already exists (default or extra).");
            return;
      }
      int k = ArraySize(g_fieldName);
      ArrayResize(g_fieldName, k + 1);
      ArrayResize(g_fieldVal, k + 1);
      g_fieldName[k] = key;
      g_fieldVal[k]  = CleanText(g_edFVal);
      g_edFName = "";
      g_edFVal = "";
      g_fieldPage = k / FIELD_ROWS;
      SaveSettings();
}

void AddWindowItem(bool isSession)
{
      string nm = CleanText(isSession ? g_edSName : g_edMName);
      string sFrom = isSession ? g_edSFrom : g_edMFrom;
      string sTo = isSession ? g_edSTo : g_edMTo;
      int a, b;
      if (StringLen(nm) == 0)
      {
            Alert("Please enter a name.");
            return;
      }
      if (!ParseHM(sFrom, a) || !(isSession ? ParseHMEnd(sTo, b) : ParseHM(sTo, b)))
      {
            Alert("Time format must be HH:MM (e.g. 09:50). Session end may also be 24:00.");
            return;
      }
      if (isSession)
      {
            AddSession(nm, a, b);
            g_sessPage = (ArraySize(g_sessName) - 1) / ROWS_PER_PAGE;
            g_edSName = ""; g_edSFrom = ""; g_edSTo = "";
      }
      else
      {
            AddMacro(nm, a, b);
            g_macroPage = (ArraySize(g_macroName) - 1) / ROWS_PER_PAGE;
            g_edMName = ""; g_edMFrom = ""; g_edMTo = "";
      }
      SaveSettings();
}

void HandleSettingsClick(string sub)
{
      if (sub == "CLOSE")
            g_settingsOpen = false;
      else if (StringFind(sub, "TAB_") == 0)
            g_tab = (int)StringToInteger(StringSubstr(sub, 4));
      else if (StringFind(sub, "RNG_") == 0)
      {
            CurrentMode = RangeAt((int)StringToInteger(StringSubstr(sub, 4)));
            SaveSettings();
      }
      else if (sub == "EXPORT")
      {
            Print("Exporting trades using range mode: ", EnumToString(CurrentMode));
            ExportPositionsHistory();
      }
      else if (sub == "FADD")
            AddExtraField();
      else if (StringFind(sub, "FDEL_") == 0)
      {
            RemoveField((int)StringToInteger(StringSubstr(sub, 5)));
            SaveSettings();
      }
      else if (sub == "FUP")
            g_fieldPage--;
      else if (sub == "FDN")
            g_fieldPage++;
      else if (sub == "SADD")
            AddWindowItem(true);
      else if (sub == "MADD")
            AddWindowItem(false);
      else if (StringFind(sub, "SDEL_") == 0)
      {
            RemoveSession((int)StringToInteger(StringSubstr(sub, 5)));
            SaveSettings();
      }
      else if (StringFind(sub, "MDEL_") == 0)
      {
            RemoveMacro((int)StringToInteger(StringSubstr(sub, 5)));
            SaveSettings();
      }
      else if (sub == "SUP")
            g_sessPage--;
      else if (sub == "SDN")
            g_sessPage++;
      else if (sub == "MUP")
            g_macroPage--;
      else if (sub == "MDN")
            g_macroPage++;
      else if (sub == "SRESET")
      {
            DefaultSessions();
            g_sessPage = 0;
            SaveSettings();
      }
      else if (sub == "MRESET")
      {
            DefaultMacros();
            g_macroPage = 0;
            SaveSettings();
      }
      else if (sub == "TFMODE")
      {
            g_tfMode = (g_tfMode == 0) ? 1 : 0;
            SaveSettings();
      }
      else if (sub == "TFDEC" || sub == "TFINC")
      {
            g_tfManual += (sub == "TFINC") ? 1 : -1;
            if (g_tfManual < 0) g_tfManual = 0;
            if (g_tfManual >= ArraySize(TfNames)) g_tfManual = ArraySize(TfNames) - 1;
            SaveSettings();
      }
      else if (sub == "FBDEC" || sub == "FBINC")
      {
            g_tfFallback += (sub == "FBINC") ? 1 : -1;
            if (g_tfFallback < -1) g_tfFallback = -1;
            if (g_tfFallback >= ArraySize(TfNames)) g_tfFallback = ArraySize(TfNames) - 1;
            SaveSettings();
      }
      else if (StringFind(sub, "THEME_") == 0)
      {
            g_theme = (int)StringToInteger(StringSubstr(sub, 6));
            if (g_theme < 0 || g_theme > 2) g_theme = 2;
            SaveSettings();
            UpdateUI();
            return;
      }
      else if (StringFind(sub, "BMODE") == 0)   ZoneAction(true, "MODE");
      else if (StringFind(sub, "BPRESET") == 0) ZoneAction(true, "PRESET");
      else if (StringFind(sub, "BDEC") == 0)    ZoneAction(true, "DEC");
      else if (StringFind(sub, "BINC") == 0)    ZoneAction(true, "INC");
      else if (StringFind(sub, "BRULE") == 0)   ZoneAction(true, "RULE");
      else if (StringFind(sub, "OMODE") == 0)   ZoneAction(false, "MODE");
      else if (StringFind(sub, "OPRESET") == 0) ZoneAction(false, "PRESET");
      else if (StringFind(sub, "ODEC") == 0)    ZoneAction(false, "DEC");
      else if (StringFind(sub, "OINC") == 0)    ZoneAction(false, "INC");
      else if (StringFind(sub, "ORULE") == 0)   ZoneAction(false, "RULE");
      else
            return;     // label / edit / background click: nothing to do

      BuildSettingsUI();
}

//+------------------------------------------------------------------+
//| EA events                                                        |
//+------------------------------------------------------------------+
int OnInit()
{
      DefaultSessions();
      DefaultMacros();
      g_custFrom = TimeToString(InpStartDate, TIME_DATE);
      g_custTo   = TimeToString(InpEndDate, TIME_DATE);
      CurrentMode = InpExportRange;

      // default "own time zone" (used only if the user switches it to Manual): PC offset
      int diffSec = (int)(TimeLocal() - TimeGMT());
      g_ownStd = (int)MathRound(diffSec / 900.0) * 15;

      LoadSettings();
      UpdateAutoDetect();

      if (HistorySelect(0, TimeCurrent()))
      {
            int totalDeals = HistoryDealsTotal();
            for (int i = totalDeals - 1; i >= 0; i--)
            {
                  ulong ticket = HistoryDealGetTicket(i);
                  if (ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN)
                  {
                        LastProcessedPositionID = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
                        break;
                  }
            }
      }

      TrackOpenPositions(true);

      g_lastW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      g_lastH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
      UpdateUI();
      EventSetTimer(1);
      return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
      EventKillTimer();
      ObjectsDeleteAll(0, "OBX_");
      ResourceFree("::OBX_QR");
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
      if (id == CHARTEVENT_CHART_CHANGE)
      {
            int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
            int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
            bool themeChanged = false;
            if (g_theme == 2)
            {
                  bool before = g_isLight;
                  ApplyTheme();
                  themeChanged = (before != g_isLight);
            }
            if (w != g_lastW || h != g_lastH || themeChanged)
            {
                  g_lastW = w;
                  g_lastH = h;
                  UpdateUI();
            }
            return;
      }

      if (id == CHARTEVENT_OBJECT_ENDEDIT)
      {
            SyncEdits();
            if (sparam == "OBX_S_ED_CFROM" || sparam == "OBX_S_ED_CTO")
                  SaveSettings();
            return;
      }

      if (id == CHARTEVENT_OBJECT_CLICK)
      {
            if (StringFind(sparam, "OBX_") != 0) return;
            SyncEdits();

            if (sparam == "OBX_BtnHide")
            {
                  g_panelHidden = true;
                  g_settingsOpen = false;
                  SaveSettings();
                  UpdateUI();
                  return;
            }
            if (sparam == "OBX_BtnShow")
            {
                  g_panelHidden = false;
                  SaveSettings();
                  UpdateUI();
                  return;
            }
            if (sparam == "OBX_BtnSettings")
            {
                  ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
                  g_settingsOpen = !g_settingsOpen;
                  BuildSettingsUI();
                  return;
            }
            if (sparam == "OBX_BtnExportNow")
            {
                  Print("Exporting trades using range mode: ", EnumToString(CurrentMode));
                  ExportPositionsHistory();
                  ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
                  ChartRedraw();
                  return;
            }
            if (StringFind(sparam, "OBX_S_") == 0)
                  HandleSettingsClick(StringSubstr(sparam, 6));
      }
}

void OnTimer()
{
      UpdateAutoDetect();
      UpdateLiveInfoLabels();
      TrackOpenPositions(false);

      if (!HistorySelect(0, TimeCurrent())) return;

      int totalDeals = HistoryDealsTotal();
      if (totalDeals == 0) return;

      for (int i = totalDeals - 1; i >= 0; i--)
      {
            ulong ticket = HistoryDealGetTicket(i);
            if (ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN)
            {
                  ulong positionID = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
                  if (positionID > LastProcessedPositionID)
                  {
                        ExportSinglePosition(positionID, false);
                        LastProcessedPositionID = positionID;
                  }
                  break;
            }
      }
}

//+------------------------------------------------------------------+
//| Export Single Position to Obsidian .md File                      |
//+------------------------------------------------------------------+
void ExportSinglePosition(ulong positionID, bool isBulkExport)
{
      HistorySelect(0, TimeCurrent());

      if (!HistorySelectByPosition(positionID)) return;

      int totalDeals = HistoryDealsTotal();
      if (totalDeals == 0) return;

      string symbol = "";
      string direction = "";
      double totalVolume = 0.0;
      double grossProfit = 0.0;
      double commission = 0.0;
      double swap = 0.0;
      
      datetime openTime = 0;
      datetime closeTime = 0;
      double initialEntryPrice = 0.0;
      double finalExitPrice = 0.0;
      
      for (int i = 0; i < totalDeals; i++)
      {
            ulong dealTicket = HistoryDealGetTicket(i);
            if (dealTicket <= 0) continue;

            symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
            long type = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
            long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            
            grossProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            commission += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            swap += HistoryDealGetDouble(dealTicket, DEAL_SWAP);

            if (entry == DEAL_ENTRY_IN)
            {
                  if (openTime == 0) openTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                  if (initialEntryPrice == 0) initialEntryPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
                  direction = (type == DEAL_TYPE_BUY) ? "Buy" : "Sell";
                  totalVolume += HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
            }
            else
            {
                  closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                  finalExitPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            }
      }

      if (closeTime == 0) return;

      double netProfit = grossProfit + commission + swap;
      string result = (netProfit > 0) ? "Win" : ((netProfit < 0) ? "Loss" : "BreakEven");

      double balanceAfter = 0.0;
      if (HistorySelect(0, closeTime))
      {
            int hDeals = HistoryDealsTotal();
            for (int d = 0; d < hDeals; d++)
            {
                  ulong hTicket = HistoryDealGetTicket(d);
                  if (hTicket > 0)
                  {
                        balanceAfter += HistoryDealGetDouble(hTicket, DEAL_PROFIT);
                        balanceAfter += HistoryDealGetDouble(hTicket, DEAL_COMMISSION);
                        balanceAfter += HistoryDealGetDouble(hTicket, DEAL_SWAP);
                  }
            }
      }
      
      if (balanceAfter == 0.0)
            balanceAfter = AccountInfoDouble(ACCOUNT_BALANCE);

      double equityAfter = balanceAfter;
      double balanceBefore = balanceAfter - netProfit;
      long accountID = AccountInfoInteger(ACCOUNT_LOGIN);
      string serverBroker = AccountInfoString(ACCOUNT_COMPANY);

      double initialSL = 0.0;
      double initialTP = 0.0;
      double currentSL = 0.0;
      double currentTP = 0.0;

      HistorySelect(0, TimeCurrent());
      int totalOrders = HistoryOrdersTotal();
      
      for (int o = 0; o < totalOrders; o++)
      {
            ulong orderTicket = HistoryOrderGetTicket(o);
            if (orderTicket > 0)
            {
                  ulong ordPosID = (ulong)HistoryOrderGetInteger(orderTicket, ORDER_POSITION_ID);
                  if (ordPosID == positionID)
                  {
                        double ordSL = HistoryOrderGetDouble(orderTicket, ORDER_SL);
                        double ordTP = HistoryOrderGetDouble(orderTicket, ORDER_TP);
                        
                        if (ordSL > 0 && initialSL == 0.0)
                        {
                              if (MathAbs(ordSL - initialEntryPrice) > 0.00001)
                              {
                                    initialSL = ordSL;
                              }
                        }
                        
                        if (ordTP > 0 && initialTP == 0.0) initialTP = ordTP;
                        if (ordSL > 0) currentSL = ordSL;
                        if (ordTP > 0) currentTP = ordTP;
                  }
            }
      }

      if (initialSL == 0.0)
      {
            for (int i = 0; i < totalDeals; i++)
            {
                  ulong dealTicket = HistoryDealGetTicket(i);
                  if (dealTicket > 0)
                  {
                        double dSL = HistoryDealGetDouble(dealTicket, DEAL_SL);
                        double dTP = HistoryDealGetDouble(dealTicket, DEAL_TP);
                        if (dSL > 0 && MathAbs(dSL - initialEntryPrice) > 0.00001 && initialSL == 0.0) 
                              initialSL = dSL;
                        if (dTP > 0 && initialTP == 0.0) initialTP = dTP;
                        if (dSL > 0) currentSL = dSL;
                        if (dTP > 0) currentTP = dTP;
                  }
            }
      }

      if (initialSL == 0.0) initialSL = currentSL;
      if (initialTP == 0.0) initialTP = currentTP;

      long durationSeconds = (long)(closeTime - openTime);
      string durationStr = "";
      if (durationSeconds < 60)                   durationStr = IntegerToString(durationSeconds) + " seconds";
      else if (durationSeconds < 3600)     durationStr = IntegerToString(durationSeconds / 60) + " minutes";
      else if (durationSeconds < 86400)
      {
            long hours = durationSeconds / 3600;
            long mins = (durationSeconds % 3600) / 60;
            durationStr = IntegerToString(hours) + " hours, " + IntegerToString(mins) + " mins";
      }
      else
      {
            long days = durationSeconds / 86400;
            long hours = (durationSeconds % 86400) / 3600;
            durationStr = IntegerToString(days) + " days, " + IntegerToString(hours) + " hours";
      }

      double rr = 0.0;
      double riskAmount = 0.0;

      double initialRiskDistance = MathAbs(initialEntryPrice - initialSL);

      if (initialSL > 0 && initialRiskDistance > 0.00001)
      {
            double rewardDistance = MathAbs(finalExitPrice - initialEntryPrice);
            
            if (netProfit < 0)
                  rr = -(rewardDistance / initialRiskDistance);
            else if (netProfit > 0)
                  rr = rewardDistance / initialRiskDistance;
            else
                  rr = 0.0;

            double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            double tickValue    = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
            double tickSize     = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
            
            if (tickSize > 0 && tickValue > 0)
                  riskAmount = (initialRiskDistance / tickSize) * tickValue * totalVolume;
            else
                  riskAmount = initialRiskDistance * totalVolume * contractSize;
      }
      else
      {
            rr = 0.0;
            riskAmount = 0.0;
      }

      string timeframe = TimeframeForPosition(positionID);
      
      string nyOpenTimeStr = "";
      string session = "";
      string macro = "";
      GetNYTimeAndDetails(openTime, nyOpenTimeStr, session, macro);

      FolderCreate("Trades");
      string strTicket = IntegerToString(positionID);
      string ticketFolder = "Trades\\" + strTicket;
      FolderCreate(ticketFolder);
      string fileName = ticketFolder + "\\Trade-" + strTicket + ".md";
      
      int fileHandle = FileOpen(fileName, FILE_WRITE|FILE_BIN);
      
      if (fileHandle != INVALID_HANDLE)
      {
            string strOpenTime = TimeToString(openTime, TIME_DATE) + " " + TimeToString(openTime, TIME_MINUTES);
            StringReplace(strOpenTime, ".", "-");
            
            string strCloseTime = TimeToString(closeTime, TIME_DATE) + " " + TimeToString(closeTime, TIME_MINUTES);
            StringReplace(strCloseTime, ".", "-");

            int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

            string content = "";
            content += "---\n";
            content += "ticket: " + strTicket + "\n";
            content += "account: \"" + InpAccountLabel + "\"\n";
            content += "account_id: " + IntegerToString(accountID) + "\n";
            content += "broker: \"" + serverBroker + "\"\n";
            content += "symbol: \"" + symbol + "\"\n";
            content += "direction: \"" + direction + "\"\n";
            content += "volume: " + DoubleToString(totalVolume, 2) + "\n";
            content += "entry_price: " + DoubleToString(initialEntryPrice, digits) + "\n";
            content += "exit_price: " + DoubleToString(finalExitPrice, digits) + "\n";
            content += "sl: " + DoubleToString(initialSL, digits) + "\n";
            content += "tp: " + DoubleToString(initialTP, digits) + "\n";
            content += "risk_amount: " + DoubleToString(riskAmount, 2) + "\n";            
            content += "rr: " + DoubleToString(rr, 2) + "\n";
            content += "open: \"" + strOpenTime + "\"\n";
            content += "close: \"" + strCloseTime + "\"\n";
            content += "ny_open: \"" + nyOpenTimeStr + "\"\n";
            content += "duration: \"" + durationStr + "\"\n";
            content += "balance_before: " + DoubleToString(balanceBefore, 2) + "\n";
            content += "balance_after: " + DoubleToString(balanceAfter, 2) + "\n";
            content += "equity_after: " + DoubleToString(equityAfter, 2) + "\n";
            content += "gross: " + DoubleToString(grossProfit, 2) + "\n";
            content += "commission: " + DoubleToString(commission, 2) + "\n";
            content += "swap: " + DoubleToString(swap, 2) + "\n";
            content += "net: " + DoubleToString(netProfit, 2) + "\n";
            content += "result: \"" + result + "\"\n";
            content += "strategy: \"\"\n";
            content += "setup: \"\"\n";
            content += "session: \"" + session + "\"\n";
            content += "macro: \"" + macro + "\"\n";
            content += "news: \"\"\n";
            content += "timeframe: \"" + timeframe + "\"\n";
            content += "emotion: \"\"\n";
            content += "mistake: \"\"\n";
            content += "grade: \"\"\n";
            content += "review: \"none\"\n";
            content += "notes: \"\"\n";
            content += BuildExtraFieldsYaml();
            content += "entry_images: []\n";
            content += "exit_images: []\n";
            content += "htf_images: []\n";
            content += "tags: []\n";
            content += "---\n\n";
            
            // --- TRADE REVIEW & NOTES ---
            content += "### 📄 Trade Review & Notes\n";
            content += "```dataviewjs\n";
            content += "const currentFilePath = dv.current().file.path;\n";
            content += "const noteFile = app.vault.getAbstractFileByPath(currentFilePath);\n";
            content += "const container = this.container;\n";
            content += "container.empty();\n\n";
            content += "const currentNote = dv.current().notes || \"\";\n\n";
            content += "function renderView() {\n";
            content += "    container.empty();\n";
            content += "    if (!currentNote || currentNote.trim() === \"\" || currentNote === \"none\") {\n";
            content += "        const noteBox = container.createEl(\"div\", {\n";
            content += "            attr: { style: \"border: 1.5px dashed #777; border-radius: 8px; padding: 14px; color: #a1a1aa; background: rgba(255,255,255,0.02); text-align: left; direction: ltr; cursor: pointer;\" },\n";
            content += "            text: \"Click to add or edit note...\"\n";
            content += "        });\n";
            content += "        noteBox.onclick = () => renderEditor();\n";
            content += "    } else {\n";
            content += "        const displayBox = container.createEl(\"div\", {\n";
            content += "            attr: { style: \"border: 1px solid rgba(255,255,255,0.15); border-radius: 8px; padding: 14px; color: #e4e4e7; background: rgba(255,255,255,0.03); text-align: left; direction: ltr; white-space: pre-wrap; cursor: pointer;\" },\n";
            content += "            text: currentNote\n";
            content += "        });\n";
            content += "        displayBox.onclick = () => renderEditor();\n";
            content += "    }\n";
            content += "}\n\n";
            content += "function renderEditor() {\n";
            content += "    container.empty();\n";
            content += "    const wrapper = container.createEl(\"div\", { attr: { style: \"display: flex; flex-direction: column; gap: 8px; direction: ltr;\" } });\n";
            content += "    const textarea = wrapper.createEl(\"textarea\", {\n";
            content += "        attr: {\n";
            content += "            style: \"width: 100%; height: 110px; border-radius: 6px; padding: 10px; background: rgba(0,0,0,0.3); color: #fff; border: 1px solid #555; font-family: inherit; resize: vertical; direction: ltr; text-align: left;\",\n";
            content += "            placeholder: \"Write your trade note here...\"\n";
            content += "        }\n";
            content += "    });\n";
            content += "    textarea.value = (dv.current().notes && dv.current().notes !== \"none\") ? dv.current().notes : \"\";\n\n";
            content += "    const btnRow = wrapper.createEl(\"div\", { attr: { style: \"display: flex; gap: 8px; justify-content: flex-start;\" } });\n";
            content += "    const saveBtn = btnRow.createEl(\"button\", { text: \"Save\", attr: { style: \"padding: 6px 16px; background: #2563eb; color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: bold;\" } });\n";
            content += "    const cancelBtn = btnRow.createEl(\"button\", { text: \"Cancel\", attr: { style: \"padding: 6px 16px; background: #4b5563; color: white; border: none; border-radius: 6px; cursor: pointer;\" } });\n\n";
            content += "    saveBtn.onclick = async () => {\n";
            content += "        const val = textarea.value;\n";
            content += "        await app.fileManager.processFrontMatter(noteFile, (fm) => {\n";
            content += "            fm.notes = val;\n";
            content += "        });\n";
            content += "    };\n";
            content += "    cancelBtn.onclick = () => renderView();\n";
            content += "}\n\n";
            content += "renderView();\n";
            content += "```\n\n";
            content += "---\n\n";
            
            // --- ENTRY SCREENSHOTS ---
            content += "### 📷 Entry Details\n";
            content += "```dataviewjs\n";
            content += "const currentFilePath = dv.current().file.path;\n";
            content += "const noteFile = app.vault.getAbstractFileByPath(currentFilePath);\n";
            content += "const lastSlash = currentFilePath.lastIndexOf('/');\n";
            content += "const targetFolder = lastSlash !== -1 ? currentFilePath.substring(0, lastSlash) : \"\";\n";
            content += "const imgs = dv.current().entry_images || [];\n";
            content += "const container = this.container;\n";
            content += "container.empty();\n";
            content += "function openLightbox(src) {\n";
            content += "    const overlay = document.createElement(\"div\");\n";
            content += "    overlay.style.cssText = \"position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.85); display: flex; align-items: center; justify-content: center; z-index: 9999; cursor: zoom-out;\";\n";
            content += "    const bigImg = document.createElement(\"img\");\n";
            content += "    bigImg.src = src;\n";
            content += "    bigImg.style.cssText = \"max-width: 90%; max-height: 90%; border-radius: 8px; box-shadow: 0 0 30px rgba(0,0,0,0.6);\";\n";
            content += "    overlay.appendChild(bigImg);\n";
            content += "    overlay.onclick = () => overlay.remove();\n";
            content += "    document.body.appendChild(overlay);\n";
            content += "}\n";
            content += "const wrapper = container.createEl(\"div\", { attr: { style: \"display: flex; gap: 10px; flex-wrap: wrap; align-items: center;\" } });\n\n";
            content += "if (imgs.length > 0) {\n";
            content += "    imgs.forEach(img => {\n";
            content += "        let path = typeof img === \"string\" ? img.replace(/^!\\s*\\[\\[/, \"\").replace(/^\\[\\[/, \"\").replace(/\\]\\]$/, \"\").split(\"|\")[0] : img.path;\n";
            content += "        let fileObj = app.vault.getAbstractFileByPath(path) || app.metadataCache.getFirstLinkpathDest(path, currentFilePath);\n";
            content += "        let src = fileObj ? app.vault.getResourcePath(fileObj) : path;\n";
            content += "        const imgEl = wrapper.createEl(\"img\", { attr: { src: src, style: \"max-width: 350px; max-height: 350px; border-radius: 8px; object-fit: contain; cursor: zoom-in;\" } });\n";
            content += "        imgEl.onclick = () => openLightbox(src);\n";
            content += "    });\n";
            content += "}\n\n";
            content += "const box = wrapper.createEl(\"div\", { attr: { style: \"width: 130px; height: 110px; border: 1.5px dashed #777; border-radius: 10px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; color: #d1d5db; background: rgba(255,255,255,0.02); cursor: pointer;\" } });\n";
            content += "box.createEl(\"div\", { text: \"📷\", attr: { style: \"font-size: 24px;\" } });\n";
            content += "box.createEl(\"div\", { text: \"Add image\", attr: { style: \"font-size: 13px; font-weight: 500;\" } });\n\n";
            content += "box.onclick = () => {\n";
            content += "    const input = document.createElement(\"input\");\n";
            content += "    input.type = \"file\";\n";
            content += "    input.accept = \"image/*\";\n";
            content += "    input.onchange = async (e) => {\n";
            content += "        const fileObj = e.target.files[0];\n";
            content += "        if (!fileObj) return;\n";
            content += "        const buffer = await fileObj.arrayBuffer();\n";
            content += "        let fileName = fileObj.name;\n";
            content += "        let counter = 1;\n";
            content += "        let parts = fileName.split(\".\");\n";
            content += "        let ext = parts.pop();\n";
            content += "        let base = parts.join(\".\");\n";
            content += "        async function ensureFolder(folderPath) {\n";
            content += "            if (!folderPath) return;\n";
            content += "            const folders = folderPath.split('/');\n";
            content += "            let current = '';\n";
            content += "            for (let folder of folders) {\n";
            content += "                current = current ? `${current}/${folder}` : folder;\n";
            content += "                if (!app.vault.getAbstractFileByPath(current)) {\n";
            content += "                    try { await app.vault.createFolder(current); } catch (err) {}\n";
            content += "                }\n";
            content += "            }\n";
            content += "        }\n";
            content += "        await ensureFolder(targetFolder);\n";
            content += "        let fullPath = targetFolder ? (targetFolder + \"/\" + fileName) : fileName;\n";
            content += "        while (app.vault.getAbstractFileByPath(fullPath)) {\n";
            content += "            fileName = base + \"_\" + counter + \".\" + ext;\n";
            content += "            fullPath = targetFolder ? (targetFolder + \"/\" + fileName) : fileName;\n";
            content += "            counter++;\n";
            content += "        }\n";
            content += "        const created = await app.vault.createBinary(fullPath, buffer);\n";
            content += "        await app.fileManager.processFrontMatter(noteFile, (fm) => {\n";
            content += "            if (!Array.isArray(fm.entry_images)) fm.entry_images = [];\n";
            content += "            fm.entry_images.push(\"[[\" + created.name + \"]]\");\n";
            content += "        });\n";
            content += "    };\n";
            content += "    input.click();\n";
            content += "};\n";
            content += "```\n\n";
            
            // --- EXIT SCREENSHOTS ---
            content += "### 🚩 Exit Details\n";
            content += "```dataviewjs\n";
            content += "const currentFilePath = dv.current().file.path;\n";
            content += "const noteFile = app.vault.getAbstractFileByPath(currentFilePath);\n";
            content += "const lastSlash = currentFilePath.lastIndexOf('/');\n";
            content += "const targetFolder = lastSlash !== -1 ? currentFilePath.substring(0, lastSlash) : \"\";\n";
            content += "const imgs = dv.current().exit_images || [];\n";
            content += "const container = this.container;\n";
            content += "container.empty();\n";
            content += "function openLightbox(src) {\n";
            content += "    const overlay = document.createElement(\"div\");\n";
            content += "    overlay.style.cssText = \"position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.85); display: flex; align-items: center; justify-content: center; z-index: 9999; cursor: zoom-out;\";\n";
            content += "    const bigImg = document.createElement(\"img\");\n";
            content += "    bigImg.src = src;\n";
            content += "    bigImg.style.cssText = \"max-width: 90%; max-height: 90%; border-radius: 8px; box-shadow: 0 0 30px rgba(0,0,0,0.6);\";\n";
            content += "    overlay.appendChild(bigImg);\n";
            content += "    overlay.onclick = () => overlay.remove();\n";
            content += "    document.body.appendChild(overlay);\n";
            content += "}\n";
            content += "const wrapper = container.createEl(\"div\", { attr: { style: \"display: flex; gap: 10px; flex-wrap: wrap; align-items: center;\" } });\n\n";
            content += "if (imgs.length > 0) {\n";
            content += "    imgs.forEach(img => {\n";
            content += "        let path = typeof img === \"string\" ? img.replace(/^!\\s*\\[\\[/, \"\").replace(/^\\[\\[/, \"\").replace(/\\]\\]$/, \"\").split(\"|\")[0] : img.path;\n";
            content += "        let fileObj = app.vault.getAbstractFileByPath(path) || app.metadataCache.getFirstLinkpathDest(path, currentFilePath);\n";
            content += "        let src = fileObj ? app.vault.getResourcePath(fileObj) : path;\n";
            content += "        const imgEl = wrapper.createEl(\"img\", { attr: { src: src, style: \"max-width: 350px; max-height: 350px; border-radius: 8px; object-fit: contain; cursor: zoom-in;\" } });\n";
            content += "        imgEl.onclick = () => openLightbox(src);\n";
            content += "    });\n";
            content += "}\n\n";
            content += "const box = wrapper.createEl(\"div\", { attr: { style: \"width: 130px; height: 110px; border: 1.5px dashed #777; border-radius: 10px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; color: #d1d5db; background: rgba(255,255,255,0.02); cursor: pointer;\" } });\n";
            content += "box.createEl(\"div\", { text: \"📷\", attr: { style: \"font-size: 24px;\" } });\n";
            content += "box.createEl(\"div\", { text: \"Add image\", attr: { style: \"font-size: 13px; font-weight: 500;\" } });\n\n";
            content += "box.onclick = () => {\n";
            content += "    const input = document.createElement(\"input\");\n";
            content += "    input.type = \"file\";\n";
            content += "    input.accept = \"image/*\";\n";
            content += "    input.onchange = async (e) => {\n";
            content += "        const fileObj = e.target.files[0];\n";
            content += "        if (!fileObj) return;\n";
            content += "        const buffer = await fileObj.arrayBuffer();\n";
            content += "        let fileName = fileObj.name;\n";
            content += "        let counter = 1;\n";
            content += "        let parts = fileName.split(\".\");\n";
            content += "        let ext = parts.pop();\n";
            content += "        let base = parts.join(\".\");\n";
            content += "        async function ensureFolder(folderPath) {\n";
            content += "            if (!folderPath) return;\n";
            content += "            const folders = folderPath.split('/');\n";
            content += "            let current = '';\n";
            content += "            for (let folder of folders) {\n";
            content += "                current = current ? `${current}/${folder}` : folder;\n";
            content += "                if (!app.vault.getAbstractFileByPath(current)) {\n";
            content += "                    try { await app.vault.createFolder(current); } catch (err) {}\n";
            content += "                }\n";
            content += "            }\n";
            content += "        }\n";
            content += "        await ensureFolder(targetFolder);\n";
            content += "        let fullPath = targetFolder ? (targetFolder + \"/\" + fileName) : fileName;\n";
            content += "        while (app.vault.getAbstractFileByPath(fullPath)) {\n";
            content += "            fileName = base + \"_\" + counter + \".\" + ext;\n";
            content += "            fullPath = targetFolder ? (targetFolder + \"/\" + fileName) : fileName;\n";
            content += "            counter++;\n";
            content += "        }\n";
            content += "        const created = await app.vault.createBinary(fullPath, buffer);\n";
            content += "        await app.fileManager.processFrontMatter(noteFile, (fm) => {\n";
            content += "            if (!Array.isArray(fm.exit_images)) fm.exit_images = [];\n";
            content += "            fm.exit_images.push(\"[[\" + created.name + \"]]\");\n";
            content += "        });\n";
            content += "    };\n";
            content += "    input.click();\n";
            content += "};\n";
            content += "```\n\n";

            // --- HTF DETAILS ---
            content += "### 📁 All Details / Higher Timeframes\n";
            content += "```dataviewjs\n";
            content += "const currentFilePath = dv.current().file.path;\n";
            content += "const noteFile = app.vault.getAbstractFileByPath(currentFilePath);\n";
            content += "const lastSlash = currentFilePath.lastIndexOf('/');\n";
            content += "const targetFolder = lastSlash !== -1 ? currentFilePath.substring(0, lastSlash) : \"\";\n";
            content += "const imgs = dv.current().htf_images || [];\n";
            content += "const container = this.container;\n";
            content += "container.empty();\n";
            content += "function openLightbox(src) {\n";
            content += "    const overlay = document.createElement(\"div\");\n";
            content += "    overlay.style.cssText = \"position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.85); display: flex; align-items: center; justify-content: center; z-index: 9999; cursor: zoom-out;\";\n";
            content += "    const bigImg = document.createElement(\"img\");\n";
            content += "    bigImg.src = src;\n";
            content += "    bigImg.style.cssText = \"max-width: 90%; max-height: 90%; border-radius: 8px; box-shadow: 0 0 30px rgba(0,0,0,0.6);\";\n";
            content += "    overlay.appendChild(bigImg);\n";
            content += "    overlay.onclick = () => overlay.remove();\n";
            content += "    document.body.appendChild(overlay);\n";
            content += "}\n";
            content += "const wrapper = container.createEl(\"div\", { attr: { style: \"display: flex; gap: 10px; flex-wrap: wrap; align-items: center;\" } });\n\n";
            content += "if (imgs.length > 0) {\n";
            content += "    imgs.forEach(img => {\n";
            content += "        let path = typeof img === \"string\" ? img.replace(/^!\\s*\\[\\[/, \"\").replace(/^\\[\\[/, \"\").replace(/\\]\\]$/, \"\").split(\"|\")[0] : img.path;\n";
            content += "        let fileObj = app.vault.getAbstractFileByPath(path) || app.metadataCache.getFirstLinkpathDest(path, currentFilePath);\n";
            content += "        let src = fileObj ? app.vault.getResourcePath(fileObj) : path;\n";
            content += "        const imgEl = wrapper.createEl(\"img\", { attr: { src: src, style: \"max-width: 350px; max-height: 350px; border-radius: 8px; object-fit: contain; cursor: zoom-in;\" } });\n";
            content += "        imgEl.onclick = () => openLightbox(src);\n";
            content += "    });\n";
            content += "}\n\n";
            content += "const box = wrapper.createEl(\"div\", { attr: { style: \"width: 130px; height: 110px; border: 1.5px dashed #777; border-radius: 10px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; color: #d1d5db; background: rgba(255,255,255,0.02); cursor: pointer;\" } });\n";
            content += "box.createEl(\"div\", { text: \"📷\", attr: { style: \"font-size: 24px;\" } });\n";
            content += "box.createEl(\"div\", { text: \"Add image\", attr: { style: \"font-size: 13px; font-weight: 500;\" } });\n\n";
            content += "box.onclick = () => {\n";
            content += "    const input = document.createElement(\"input\");\n";
            content += "    input.type = \"file\";\n";
            content += "    input.accept = \"image/*\";\n";
            content += "    input.onchange = async (e) => {\n";
            content += "        const fileObj = e.target.files[0];\n";
            content += "        if (!fileObj) return;\n";
            content += "        const buffer = await fileObj.arrayBuffer();\n";
            content += "        let fileName = fileObj.name;\n";
            content += "        let counter = 1;\n";
            content += "        let parts = fileName.split(\".\");\n";
            content += "        let ext = parts.pop();\n";
            content += "        let base = parts.join(\".\");\n";
            content += "        async function ensureFolder(folderPath) {\n";
            content += "            if (!folderPath) return;\n";
            content += "            const folders = folderPath.split('/');\n";
            content += "            let current = '';\n";
            content += "            for (let folder of folders) {\n";
            content += "                current = current ? `${current}/${folder}` : folder;\n";
            content += "                if (!app.vault.getAbstractFileByPath(current)) {\n";
            content += "                    try { await app.vault.createFolder(current); } catch (err) {}\n";
            content += "                }\n";
            content += "            }\n";
            content += "        }\n";
            content += "        await ensureFolder(targetFolder);\n";
            content += "        let fullPath = targetFolder ? (targetFolder + \"/\" + fileName) : fileName;\n";
            content += "        while (app.vault.getAbstractFileByPath(fullPath)) {\n";
            content += "            fileName = base + \"_\" + counter + \".\" + ext;\n";
            content += "            fullPath = targetFolder ? (targetFolder + \"/\" + fileName) : fileName;\n";
            content += "            counter++;\n";
            content += "        }\n";
            content += "        const created = await app.vault.createBinary(fullPath, buffer);\n";
            content += "        await app.fileManager.processFrontMatter(noteFile, (fm) => {\n";
            content += "            if (!Array.isArray(fm.htf_images)) fm.htf_images = [];\n";
            content += "            fm.htf_images.push(\"[[\" + created.name + \"]]\");\n";
            content += "        });\n";
            content += "    };\n";
            content += "    input.click();\n";
            content += "};\n";
            content += "```\n";

            WritePureString(fileHandle, content);
            FileClose(fileHandle);
      }
}

void ExportPositionsHistory()
{
      datetime startRange = 0;
      datetime endRange = TimeCurrent() + 86400;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      switch(CurrentMode)
      {
            case EXPORT_ALL:
                  startRange = 0;
                  break;

            case EXPORT_TODAY:
                  startRange = TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec);
                  break;

            case EXPORT_THIS_WEEK:
                  {
                     int daysSinceMonday = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
                     datetime todayStart = TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec);
                     startRange = todayStart - (daysSinceMonday * 86400);
                  }
                  break;

            case EXPORT_THIS_MONTH:
                  startRange = DateOnly(dt.year, dt.mon, 1);
                  break;

            case EXPORT_CUSTOM_DATE:
                  {
                     string sFrom = Trim(g_custFrom);
                     string sTo   = Trim(g_custTo);
                     StringReplace(sFrom, "-", ".");
                     StringReplace(sFrom, "/", ".");
                     StringReplace(sTo, "-", ".");
                     StringReplace(sTo, "/", ".");
                     datetime dFrom = StringToTime(sFrom);
                     datetime dTo   = StringToTime(sTo);
                     if (dFrom == 0 || dTo == 0 || dFrom > dTo)
                     {
                        g_statusMsg = "Invalid custom dates (use YYYY.MM.DD, From <= To).";
                        SetLabelText("OBX_S_STATUS", g_statusMsg);
                        Alert(g_statusMsg);
                        return;
                     }
                     startRange = dFrom;
                     endRange = dTo + 86400;     // 'To' date is included
                  }
                  break;
      }

      if (!HistorySelect(startRange, endRange))
      {
            g_statusMsg = "Error reading history for selected range!";
            SetLabelText("OBX_S_STATUS", g_statusMsg);
            Alert("Error reading history for selected range!");
            return;
      }

      int totalDeals = HistoryDealsTotal();
      ulong foundPositions[];
      ArrayResize(foundPositions, 0);

      for (int i = 0; i < totalDeals; i++)
      {
            ulong ticket = HistoryDealGetTicket(i);
            if (ticket <= 0) continue;

            long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            if (entry != DEAL_ENTRY_IN)
            {
                  ulong positionID = (ulong)HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
                  if (positionID <= 0) continue;

                  bool duplicate = false;
                  int size = ArraySize(foundPositions);
                  for (int j = 0; j < size; j++)
                  {
                        if (foundPositions[j] == positionID)
                        {
                              duplicate = true;
                              break;
                        }
                  }

                  if (!duplicate)
                  {
                        int currentSize = ArraySize(foundPositions);
                        ArrayResize(foundPositions, currentSize + 1);
                        foundPositions[currentSize] = positionID;
                  }
            }
      }

      int uniqueCount = ArraySize(foundPositions);
      int exportedCount = 0;

      for (int k = 0; k < uniqueCount; k++)
      {
            ExportSinglePosition(foundPositions[k], true);
            exportedCount++;
      }

      g_statusMsg = "Export finished: " + RangeName(CurrentMode) + " | Extracted trades: " + IntegerToString(exportedCount);
      SetLabelText("OBX_S_STATUS", g_statusMsg);
      Alert("Export finished successfully! Mode: " + EnumToString(CurrentMode) + " | Extracted trades: " + IntegerToString(exportedCount));
}
