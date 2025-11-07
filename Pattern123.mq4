#property strict
#property indicator_chart_window
#property indicator_buffers 0

//===========================
// Inputs (match your dialog)
//===========================
input int      InpBarsToScan          = 1000;       // Number of bars for the indicator calculation
input int      InpZigZagDepth         = 12;         // Depth of ZigZag
input int      InpZigZagDeviation     = 5;          // Deviation (fixed in original UI; make editable)
input int      InpZigZagBackstep      = 3;          // Backstep (fixed in original UI; make editable)

// Visuals
input bool     InpShowProfitZones     = true;       // Show "Awesome Profit Zones"
input color    InpBuyColor            = clrTeal;    // Color to BUY
input color    InpSellColor           = clrMaroon;  // Color to SELL
input double   InpTP1                 = 138.2;      // Profit target #1
input double   InpTP2                 = 161.8;      // Profit target #2
input double   InpTP3                 = 200.0;      // Profit target #3
input double   InpTP4                 = 0.0;        // Profit target #4
input double   InpTP5                 = 0.0;        // Profit target #5
input color    InpBuyLineColor        = clrTeal;    // Color of lines BUY
input color    InpSellLineColor       = clrMaroon;  // Color of lines SELL
input ENUM_LINE_STYLE InpLineStyle    = STYLE_DOT;  // Style line of the Profit Levels
input bool     InpShowPoints123       = true;       // Show points #1,2,3
input int      InpPointSize           = 11;         // Points size

// Notifications & sounds
input bool     InpEnableSound         = true;                   // ON/OFF – Sound when the signal
input string   InpSoundBreak          = "vong.wav";             // Signal (pattern 123 complete)
input string   InpSoundPre            = "vrequest.wav";         // Pre-alarm (pattern 123 forming)
input bool     InpAlert               = false;                  // Alert
input bool     InpEmail               = false;                  // E-Mail
input bool     InpPush                = false;                  // Push-notification

//===========================
// Internal
//===========================
#define MAX_SWINGS  200
#define MAX_TPS     5

datetime last_bar_time = 0;

string KeyPrefix(bool bull, int i2) {
   return(StringFormat("P123_%s_%d_", bull?"B":"S", i2));
}

string TimeframeToString(int period) {
   switch(period) {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return StringFormat("%d", period);
   }
}

void DrawPointLabel(string name, int index, double price, color c) {
   if(!InpShowPoints123) return;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_ARROW,0,Time[index],price);
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE,159);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,InpPointSize);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectMove(0,name,0,Time[index],price);
}

void DrawHLine(string name, double price, color c) {
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_STYLE,InpLineStyle);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
}

void DrawZone(string name, int i_from, int i_to, double p1, double p2, color c) {
   if(!InpShowProfitZones) return;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE,0,Time[i_from],p1,Time[i_to],p2);
   ObjectMove(0,name,0,Time[i_from],p1);
   ObjectMove(0,name,1,Time[i_to],p2);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
}

double TargetPrice(bool bull, double p2, double p3, double ratioPerc) {
   double leg = MathAbs(p2 - p3);
   double k   = ratioPerc/100.0 - 1.0;   // 138.2% -> +0.382 from p2
   if(bull) return (p2 + k*leg);
   return (p2 - k*leg);
}

void NotifyAll(string msg) {
   if(InpEnableSound && StringLen(InpSoundBreak)>0) PlaySound(InpSoundBreak);
   if(InpAlert) Alert(msg);
   if(InpPush)  SendNotification(msg);
   if(InpEmail) SendMail("Pattern 1-2-3 "+Symbol(), msg);
}

int OnInit() { return(INIT_SUCCEEDED); }
void OnDeinit(const int reason) { /* keep drawings */ }

//===========================
// Main (MT4-style)
//===========================
int start() {
   // run on new bar to keep it light
   if (Time[0] == last_bar_time) return(0);
   last_bar_time = Time[0];

   int bars = MathMin(InpBarsToScan, Bars-100);
   if(bars <= 0) return(0);

   // Collect ZigZag swings
   int    sIdx[MAX_SWINGS];
   double sPrice[MAX_SWINGS];
   bool   sIsHigh[MAX_SWINGS];
   int    n=0;

   // Initialize arrays
   ArrayInitialize(sIdx, 0);
   ArrayInitialize(sPrice, 0.0);
   ArrayInitialize(sIsHigh, false);

   for(int i=bars; i>=0 && n<MAX_SWINGS; i--) {
      double zzH = iCustom(Symbol(),Period(),"ZigZag",InpZigZagDepth,InpZigZagDeviation,InpZigZagBackstep,0,i);
      double zzL = iCustom(Symbol(),Period(),"ZigZag",InpZigZagDepth,InpZigZagDeviation,InpZigZagBackstep,1,i);
      if(zzH != 0.0) { sIdx[n]=i; sPrice[n]=zzH; sIsHigh[n]=true;  n++; }
      if(zzL != 0.0) { sIdx[n]=i; sPrice[n]=zzL; sIsHigh[n]=false; n++; }
   }

   // sort by time asc (simple bubble for small N)
   for(int a=0;a<n-1;a++)
      for(int b=a+1;b<n;b++)
         if(Time[sIdx[a]]>Time[sIdx[b]]) {
            int ti=sIdx[a]; sIdx[a]=sIdx[b]; sIdx[b]=ti;
            double tp=sPrice[a]; sPrice[a]=sPrice[b]; sPrice[b]=tp;
            bool th=sIsHigh[a]; sIsHigh[a]=sIsHigh[b]; sIsHigh[b]=th;
         }

   // Detect 1-2-3
   for(int k=2; k<n; ++k) {
      int i1=sIdx[k-2], i2=sIdx[k-1], i3=sIdx[k];
      double p1=sPrice[k-2], p2=sPrice[k-1], p3=sPrice[k];

      bool bull = (!sIsHigh[k-2] &&  sIsHigh[k-1] && !sIsHigh[k] && p1<p3 && p2>p3);
      bool bear = ( sIsHigh[k-2] && !sIsHigh[k-1] &&  sIsHigh[k] && p1>p3 && p2<p3);
      if(!(bull || bear)) continue;

      // Pre-alarm
      if(InpEnableSound && StringLen(InpSoundPre)>0) PlaySound(InpSoundPre);

      color c = bull?InpBuyColor:InpSellColor;
      string pref = KeyPrefix(bull,i2);

      // Draw points
      DrawPointLabel(pref+"P1", i1, p1, c);
      DrawPointLabel(pref+"P2", i2, p2, c);
      DrawPointLabel(pref+"P3", i3, p3, c);

      // Wait for breakout of #2 after it formed
      bool broken=false; int ibreak=i2-1;
      for(int i=i2-1; i>=0; --i) {
         if(bull && Close[i]>p2) { broken=true; ibreak=i; break; }
         if(bear && Close[i]<p2) { broken=true; ibreak=i; break; }
      }
      if(!broken) continue;

      // Draw targets (lines + zones)
      double tps[MAX_TPS];
      tps[0] = InpTP1;
      tps[1] = InpTP2;
      tps[2] = InpTP3;
      tps[3] = InpTP4;
      tps[4] = InpTP5;
      for(int j=0;j<MAX_TPS;j++){
         if(tps[j]<=0.0) continue;
         double tgt = TargetPrice(bull,p2,p3,tps[j]);
         string nm  = pref + StringFormat("TP_%g",tps[j]);
         DrawHLine(nm, tgt, bull?InpBuyLineColor:InpSellLineColor);
         DrawZone(nm+"_Z", ibreak, 0, p2, tgt, c);
      }

      string dir=bull?"BUY":"SELL";
      string msg=StringFormat("%s %s %s | breakout #2=%.5f | leg=%.1f pips",
                              Symbol(), TimeframeToString(Period()), dir, p2, MathAbs(p2-p3)/_Point);
      NotifyAll(msg);
   }

   return(0);
}
