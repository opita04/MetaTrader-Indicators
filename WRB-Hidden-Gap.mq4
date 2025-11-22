//+------------------------------------------------------------------+
//|                                               WRB-Hidden-Gap.mq4 |
//|                                      Copyright © 2024, EarnForex |
//|                                       https://www.earnforex.com/ |
//|                             Based on the indicator by Akif TOKUZ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2024, EarnForex"
#property link      "https://www.earnforex.com/metatrader-indicators/WRB-Hidden-Gap/"
#property version   "1.11"
#property strict

#property description "Identifies Wide Range Bars and Hidden Gaps. Supports MTF."
#property description "WRB and HG definitions are taken from the WRB Analysis Tutorial-1"
#property description "by M.A.Perry from TheStrategyLab.com."
#property description "Conversion from MQL4 to MQL5, alerts, and optimization by Andriy Moraru."

#property indicator_chart_window
#property indicator_buffers 1

#property indicator_type1 DRAW_ARROW
#property indicator_label1 "WRB"
#property indicator_color1 clrNONE
#property indicator_width1 3

enum TIMEFRAMES
{
    tf_current = 0,    // Current timeframe
    tf_m1      = PERIOD_M1,   // 1 minute
    tf_m5      = PERIOD_M5,   // 5 minutes
    tf_m15     = PERIOD_M15,  // 15 minutes
    tf_m30     = PERIOD_M30,  // 30 minutes
    tf_h1      = PERIOD_H1,   // 1 hour
    tf_h4      = PERIOD_H4,   // 4 hours
    tf_d1      = PERIOD_D1,   // Daily
    tf_w1      = PERIOD_W1,   // Weekly
    tf_mn1     = PERIOD_MN1   // Monthly
};

input TIMEFRAMES Timeframe = tf_current;  // Timeframe
input bool UseWholeBars = false;
input int WRB_LookBackBarCount = 3;
input int WRB_WingDingsSymbol = 115;
input color HGcolorNormalBullishUnbreached       = clrDodgerBlue;
input color HGcolorIntersectionBullishUnbreached = clrBlue;
input color HGcolorNormalBearishUnbreached       = clrIndianRed;
input color HGcolorIntersectionBearishUnbreached = clrRed;
input color HGcolorNormalBullishBreached         = clrPowderBlue;
input color HGcolorIntersectionBullishBreached   = clrSlateBlue;
input color HGcolorNormalBearishBreached         = clrLightCoral;
input color HGcolorIntersectionBearishBreached   = clrSalmon;
input int HGstyle = STYLE_SOLID;
input int StartCalculationFromBar = 1000;
input bool HollowBoxes = false;
input bool AlertBreachesFromBelow = false;
input bool AlertBreachesFromAbove = false;
input bool AlertHG = false;
input bool AlertWRB = false;
input bool AlertHGFill = false;
input bool EnableNativeAlerts = false;
input bool EnableEmailAlerts = false;
input bool EnablePushAlerts = false;
input string ObjectPrefix = "HG_";

double WRB[];

int totalBarCount = -1;
bool DoAlerts = false;
datetime AlertTimeWRB = 0, AlertTimeHG = 0;
string UnfilledPrefix, FilledPrefix;
int counted_bars;

// Cached data
int actual_timeframe;
int bars_per_upper_timeframe_bar;
datetime upper_timeframe_times[];

int init()
{
    if (Timeframe == tf_current)
        actual_timeframe = Period();
    else
        actual_timeframe = (int)Timeframe;
    
    if (actual_timeframe < Period())
        actual_timeframe = Period();

    IndicatorShortName("WRB+HG");

    SetIndexBuffer(0, WRB);
    SetIndexStyle(0, DRAW_ARROW, STYLE_SOLID, 3, clrNONE);
    SetIndexArrow(0, WRB_WingDingsSymbol);
    SetIndexEmptyValue(0, EMPTY_VALUE);
    ArraySetAsSeries(WRB, true);
    
    UnfilledPrefix = ObjectPrefix + "UNFILLED_";
    FilledPrefix = ObjectPrefix + "FILLED_";

    if ((EnableNativeAlerts) || (EnableEmailAlerts) || (EnablePushAlerts)) DoAlerts = true;

    // Initialize cached data
    if (actual_timeframe > Period())
    {
        bars_per_upper_timeframe_bar = (int)MathCeil((double)actual_timeframe / (double)Period());
        int upper_timeframe_bars = (int)MathCeil((double)StartCalculationFromBar / (double)bars_per_upper_timeframe_bar);
        ArrayResize(upper_timeframe_times, upper_timeframe_bars);
        ArraySetAsSeries(upper_timeframe_times, true);
        for (int i = 0; i < upper_timeframe_bars; i++)
        {
            upper_timeframe_times[i] = iTime(Symbol(), actual_timeframe, i);
        }
    }

    return 0;
}

int intersect(double H1, double L1, double H2, double L2)
{
    if ((L1 > H2) || (H1 < L2)) return 0;
    if ((H1 >= H2) && (L1 >= L2)) return 1;
    if ((H1 <= H2) && (L1 <= L2)) return 2;
    if ((H1 >= H2) && (L1 <= L2)) return 3;
    if ((H1 <= H2) && (L1 >= L2)) return 4;
    return 0;
}

void checkHGFilled(int barNumber)
{
    if (barNumber < 0) return;

    string Prefix = UnfilledPrefix;

    int L = StringLen(Prefix);
    int obj_total = ObjectsTotal();
    for (int i = 0; i < obj_total; i++)
    {
        string ObjName = ObjectName(i);
        if (StringSubstr(ObjName, 0, L) != Prefix) continue;
        if (ObjectType(ObjName) != OBJ_RECTANGLE) continue;
        
        double box_H = ObjectGet(ObjName, OBJPROP_PRICE1);
        double box_L = ObjectGet(ObjName, OBJPROP_PRICE2);
        color objectColor = (color)ObjectGet(ObjName, OBJPROP_COLOR);
        datetime startTime = (datetime)ObjectGet(ObjName, OBJPROP_TIME1);

        double HGFillPA_H = iHigh(Symbol(), Period(), barNumber);
        double HGFillPA_L = iLow(Symbol(), Period(), barNumber);

        if ((HGFillPA_H > box_L) && (HGFillPA_L < box_H))
        {
            if (objectColor == HGcolorNormalBullishUnbreached) objectColor = HGcolorNormalBullishBreached;
            else if (objectColor == HGcolorIntersectionBullishUnbreached) objectColor = HGcolorIntersectionBullishBreached;
            else if (objectColor == HGcolorNormalBearishUnbreached) objectColor = HGcolorNormalBearishBreached;
            else if (objectColor == HGcolorIntersectionBearishUnbreached) objectColor = HGcolorIntersectionBearishBreached;
            ObjectSet(ObjName, OBJPROP_COLOR, objectColor);
        }

        int j = 0;
        while ((barNumber + j < Bars) && (startTime < iTime(Symbol(), Period(), barNumber + j)))
        {
            double barHigh = iHigh(Symbol(), Period(), barNumber + j);
            double barLow = iLow(Symbol(), Period(), barNumber + j);
            if (intersect(barHigh, barLow, box_H, box_L) == 0) break;
            
            if (barHigh > HGFillPA_H) HGFillPA_H = barHigh;
            if (barLow  < HGFillPA_L) HGFillPA_L = barLow;
            if ((HGFillPA_H > box_H) && (HGFillPA_L < box_L))
            {
                ObjectDelete(ObjName);
                string ObjectText = FilledPrefix + TimeToString(startTime, TIME_DATE | TIME_MINUTES);
                ObjectCreate(ObjectText, OBJ_RECTANGLE, 0, startTime, box_H, iTime(Symbol(), Period(), barNumber), box_L);
                ObjectSet(ObjectText, OBJPROP_STYLE, HGstyle);
                ObjectSet(ObjectText, OBJPROP_COLOR, objectColor);
                ObjectSet(ObjectText, OBJPROP_BACK, true);
                ObjectSet(ObjectText, OBJPROP_SELECTABLE, false);
                if (!HollowBoxes)
                    ObjectSet(ObjectText, OBJPROP_FILL, true);
                else
                    ObjectSet(ObjectText, OBJPROP_FILL, false);
                
                if ((AlertHGFill) && (counted_bars > 0))
                {
                    string tfStr = "";
                    if (Period() == PERIOD_M1) tfStr = "M1";
                    else if (Period() == PERIOD_M5) tfStr = "M5";
                    else if (Period() == PERIOD_M15) tfStr = "M15";
                    else if (Period() == PERIOD_M30) tfStr = "M30";
                    else if (Period() == PERIOD_H1) tfStr = "H1";
                    else if (Period() == PERIOD_H4) tfStr = "H4";
                    else if (Period() == PERIOD_D1) tfStr = "D1";
                    else if (Period() == PERIOD_W1) tfStr = "W1";
                    else if (Period() == PERIOD_MN1) tfStr = "MN1";
                    
                    string Text = "WRB Hidden Gap: " + Symbol() + " - " + tfStr + " - HG " + TimeToString(startTime, TIME_DATE | TIME_MINUTES) + " Filled.";
                    string TextNative = "WRB Hidden Gap: HG " + TimeToString(startTime, TIME_DATE | TIME_MINUTES) + " Filled.";
                    if (EnableNativeAlerts) Alert(TextNative);
                    if (EnableEmailAlerts) SendMail("WRB HG Alert", Text);
                    if (EnablePushAlerts) SendNotification(Text);
                }
                break;
            }
            j++;
        }
    }
}

bool checkWRB(int i)
{
    if (i < 0 || i >= Bars) return false;

    double body, bodyPrior;
    int upper_timeframe_i = i;
    int period = PERIOD_CURRENT;
    if (actual_timeframe > Period())
    {
        upper_timeframe_i = (int)MathFloor((double)i / (double)bars_per_upper_timeframe_bar);
        if (upper_timeframe_i + WRB_LookBackBarCount >= ArraySize(upper_timeframe_times))
        {
            return false;
        }
        period = actual_timeframe;
    }
    
    if (upper_timeframe_i >= Bars)
    {
        return false;
    }
    
    if (UseWholeBars) 
        body = iHigh(Symbol(), period, upper_timeframe_i) - iLow(Symbol(), period, upper_timeframe_i);
    else 
        body = MathAbs(iOpen(Symbol(), period, upper_timeframe_i) - iClose(Symbol(), period, upper_timeframe_i));
        
    for (int j = 1; j <= WRB_LookBackBarCount; j++)
    {
        if (upper_timeframe_i + j >= Bars)
        {
            return false;
        }
        if (UseWholeBars) 
            bodyPrior = iHigh(Symbol(), period, upper_timeframe_i + j) - iLow(Symbol(), period, upper_timeframe_i + j);
        else 
            bodyPrior = MathAbs(iOpen(Symbol(), period, upper_timeframe_i + j) - iClose(Symbol(), period, upper_timeframe_i + j));
            
        if (bodyPrior > body)
        {
            WRB[i] = EMPTY_VALUE;
            return false;
        }
    }
    
    if (UseWholeBars) 
        WRB[i] = (iHigh(Symbol(), Period(), i) + iLow(Symbol(), Period(), i)) / 2.0;
    else 
        WRB[i] = (iOpen(Symbol(), Period(), i) + iClose(Symbol(), Period(), i)) / 2.0;
    
    return true;
}

void checkHG(int i)
{
    if (i < 0) return;

    color HGcolor = clrNONE;
    int i_to_check = i;
    int i_upper_bar = i;
    int period = PERIOD_CURRENT;
    if (actual_timeframe > Period())
    {
        i_upper_bar = (int)MathFloor((double)i / (double)bars_per_upper_timeframe_bar);
        i_to_check = i_upper_bar * bars_per_upper_timeframe_bar + bars_per_upper_timeframe_bar - 1;
        if (i_upper_bar + 2 >= ArraySize(upper_timeframe_times))
        {
            return;
        }
        period = actual_timeframe;
    }
    
    if (i_to_check + 1 >= ArraySize(WRB) || i_upper_bar + 2 >= Bars)
    {
        return;
    }
    
    if (WRB[i_to_check + 1] != EMPTY_VALUE)
    {
        double H, L, A, B;
        double H2, L2, H1, L1;

        H2 = iHigh(Symbol(), period, i_upper_bar + 2);
        L2 = iLow(Symbol(), period, i_upper_bar + 2);
        H1 = iHigh(Symbol(), period, i_upper_bar);
        L1 = iLow(Symbol(), period, i_upper_bar);

        if (UseWholeBars)
        {
            H = iHigh(Symbol(), period, i_upper_bar + 1);
            L = iLow(Symbol(), period, i_upper_bar + 1);
        }
        else if (iOpen(Symbol(), period, i_upper_bar + 1) > iClose(Symbol(), period, i_upper_bar + 1))
        {
            H = iOpen(Symbol(), period, i_upper_bar + 1);
            L = iClose(Symbol(), period, i_upper_bar + 1);
        }
        else
        {
            H = iClose(Symbol(), period, i_upper_bar + 1);
            L = iOpen(Symbol(), period, i_upper_bar + 1);
        }

        if (iOpen(Symbol(), period, i_upper_bar + 1) > iClose(Symbol(), period, i_upper_bar + 1)) 
            HGcolor = HGcolorNormalBearishUnbreached;
        else 
            HGcolor = HGcolorNormalBullishUnbreached;

        if (L2 > H1)
        {
            A = MathMin(L2, H);
            B = MathMax(H1, L);
        }
        else if (L1 > H2)
        {
            A = MathMin(L1, H);
            B = MathMax(H2, L);
        }
        else return;

        if (A > B)
        {
            string ObjectText;
            int Length = StringLen(UnfilledPrefix);

            int obj_total = ObjectsTotal();
            for (int j = 0; j < obj_total; j++)
            {
                ObjectText = ObjectName(j);
                if (StringSubstr(ObjectText, 0, Length) != UnfilledPrefix) continue;
                if (ObjectType(ObjectText) != OBJ_RECTANGLE) continue;
                
                double objPrice1 = ObjectGet(ObjectText, OBJPROP_PRICE1);
                double objPrice2 = ObjectGet(ObjectText, OBJPROP_PRICE2);
                if (intersect(objPrice1, objPrice2, A, B) != 0)
                {
                    if (HGcolor == HGcolorNormalBearishUnbreached) HGcolor = HGcolorIntersectionBearishUnbreached;
                    else if (HGcolor == HGcolorNormalBullishUnbreached) HGcolor = HGcolorIntersectionBullishUnbreached;
                    break;
                }
            }

            ObjectText = UnfilledPrefix + TimeToString(iTime(Symbol(), Period(), i_to_check + 1), TIME_DATE | TIME_MINUTES);
            if ((ObjectFind(ObjectText) >= 0) || (ObjectFind(ObjectText + "A") >= 0)) return;
            
            datetime endTime = TimeCurrent() + 10 * 365 * 24 * 60 * 60;
            if(!ObjectCreate(ObjectText, OBJ_RECTANGLE, 0, iTime(Symbol(), Period(), i_to_check + 1), A, endTime, B))
            {
                return;
            }
            
            ObjectSet(ObjectText, OBJPROP_STYLE, HGstyle);
            ObjectSet(ObjectText, OBJPROP_COLOR, HGcolor);
            ObjectSet(ObjectText, OBJPROP_BACK, true);
            ObjectSet(ObjectText, OBJPROP_SELECTABLE, false);
            if (!HollowBoxes)
                ObjectSet(ObjectText, OBJPROP_FILL, true);
            else
                ObjectSet(ObjectText, OBJPROP_FILL, false);
        }
    }
}

void deinit(const int reason)
{
    ObjectsDeleteAll(0, ObjectPrefix);
    WindowRedraw();
}

int start()
{
    int rates_total = Bars;
    if (rates_total <= StartCalculationFromBar) return 0;

    if ((DoAlerts) && ((AlertBreachesFromBelow) || (AlertBreachesFromAbove))) CheckAlert();

    int end_bar = 0, wrb_alert_bar, hg_alert_bar;
    if (totalBarCount != rates_total)
    {
        counted_bars = IndicatorCounted();
        int start_bar = MathMin(StartCalculationFromBar - 1, rates_total - 1);
        
        if (actual_timeframe > Period())
        {
            int latest_sub_bar = start_bar % bars_per_upper_timeframe_bar;
            int oldest_sub_bar = start_bar - latest_sub_bar;
            start_bar = oldest_sub_bar;
            end_bar = latest_sub_bar;
            wrb_alert_bar = oldest_sub_bar;
            hg_alert_bar = oldest_sub_bar + 1;
        }
        else
        {
            end_bar = 1;
            wrb_alert_bar = 1;
            hg_alert_bar = end_bar + 1;
        }

        int bars_left_to_count = rates_total - counted_bars;
        start_bar = (int)MathMax(start_bar, bars_left_to_count - 1);

        for (int i = start_bar; i >= end_bar; i--)
        {
            checkWRB(i);
            checkHG(i);
            checkHGFilled(i);
        }

        if ((DoAlerts) && (AlertWRB) && (wrb_alert_bar >= 0) && (wrb_alert_bar < ArraySize(WRB)) && (WRB[wrb_alert_bar] != EMPTY_VALUE))
        {
            datetime wrbTime = iTime(Symbol(), Period(), wrb_alert_bar);
            if (AlertTimeWRB < wrbTime)
            {
                string tfStr = "";
                if (Period() == PERIOD_M1) tfStr = "M1";
                else if (Period() == PERIOD_M5) tfStr = "M5";
                else if (Period() == PERIOD_M15) tfStr = "M15";
                else if (Period() == PERIOD_M30) tfStr = "M30";
                else if (Period() == PERIOD_H1) tfStr = "H1";
                else if (Period() == PERIOD_H4) tfStr = "H4";
                else if (Period() == PERIOD_D1) tfStr = "D1";
                else if (Period() == PERIOD_W1) tfStr = "W1";
                else if (Period() == PERIOD_MN1) tfStr = "MN1";
                
                string Text = "WRB Hidden Gap: " + Symbol() + " - " + tfStr + " - New WRB.";
                string TextNative = "WRB Hidden Gap: New WRB.";
                if (EnableNativeAlerts) Alert(TextNative);
                if (EnableEmailAlerts) SendMail("WRB HG Alert", Text);
                if (EnablePushAlerts) SendNotification(Text);
                AlertTimeWRB = wrbTime;
            }
        }
        
        if ((DoAlerts) && (AlertHG) && (hg_alert_bar >= 0) && (hg_alert_bar < Bars))
        {
            datetime hgTime = iTime(Symbol(), Period(), hg_alert_bar);
            string hgObjName = UnfilledPrefix + TimeToString(hgTime, TIME_DATE | TIME_MINUTES);
            if ((ObjectFind(hgObjName) >= 0) && (AlertTimeHG < hgTime))
            {
                string tfStr = "";
                if (Period() == PERIOD_M1) tfStr = "M1";
                else if (Period() == PERIOD_M5) tfStr = "M5";
                else if (Period() == PERIOD_M15) tfStr = "M15";
                else if (Period() == PERIOD_M30) tfStr = "M30";
                else if (Period() == PERIOD_H1) tfStr = "H1";
                else if (Period() == PERIOD_H4) tfStr = "H4";
                else if (Period() == PERIOD_D1) tfStr = "D1";
                else if (Period() == PERIOD_W1) tfStr = "W1";
                else if (Period() == PERIOD_MN1) tfStr = "MN1";
                
                string Text = "WRB Hidden Gap: " + Symbol() + " - " + tfStr + " - New HG.";
                string TextNative = "WRB Hidden Gap: New HG.";
                if (EnableNativeAlerts) Alert(TextNative);
                if (EnableEmailAlerts) SendMail("WRB HG Alert", Text);
                if (EnablePushAlerts) SendNotification(Text);
                AlertTimeHG = hgTime;
            }
        }

        totalBarCount = rates_total;
    }
    
    if (actual_timeframe > Period())
    {
        for (int i = end_bar - 1; i >= 0; i--)
        {
            WRB[i] = EMPTY_VALUE;
            checkHGFilled(i);
        }
    }
    else 
    {
        checkHGFilled(0);
        WRB[0] = EMPTY_VALUE;
    }
    
    WindowRedraw();
    return 0;
}

void CheckAlert()
{
    int Length = StringLen(UnfilledPrefix);
    int total = ObjectsTotal();
    for (int j = 0; j < total; j++)
    {
        string ObjectText = ObjectName(j);
        if (StringSubstr(ObjectText, 0, Length) != UnfilledPrefix) continue;
        if (ObjectType(ObjectText) != OBJ_RECTANGLE) continue;

        if (StringSubstr(ObjectText, StringLen(ObjectText) - 1, 1) == "A")
        {
            string ObjectNameWithoutA = StringSubstr(ObjectText, 0, StringLen(ObjectText) - 1);
            if (ObjectFind(ObjectNameWithoutA) >= 0) ObjectDelete(ObjectNameWithoutA);
            continue;
        }

        double currentAsk = MarketInfo(Symbol(), MODE_ASK);
        double currentBid = MarketInfo(Symbol(), MODE_BID);
        double Price1 = ObjectGet(ObjectText, OBJPROP_PRICE1);
        double Price2 = ObjectGet(ObjectText, OBJPROP_PRICE2);
        double High = MathMax(Price1, Price2);
        double Low = MathMin(Price1, Price2);

        if ((currentAsk > Low) && (currentBid < High))
        {
            string Text = "";
            string TextNative = "";
            double open0 = iOpen(Symbol(), Period(), 0);
            double open1 = iOpen(Symbol(), Period(), 1);
            
            if ((AlertBreachesFromBelow) && ((open0 < Low) || (open1 < Low)))
            {
                string tfStr = "";
                if (Period() == PERIOD_M1) tfStr = "M1";
                else if (Period() == PERIOD_M5) tfStr = "M5";
                else if (Period() == PERIOD_M15) tfStr = "M15";
                else if (Period() == PERIOD_M30) tfStr = "M30";
                else if (Period() == PERIOD_H1) tfStr = "H1";
                else if (Period() == PERIOD_H4) tfStr = "H4";
                else if (Period() == PERIOD_D1) tfStr = "D1";
                else if (Period() == PERIOD_W1) tfStr = "W1";
                else if (Period() == PERIOD_MN1) tfStr = "MN1";
                
                Text = "WRB Hidden Gap: " + Symbol() + " - " + tfStr + " - WRB rectangle breached from below.";
                TextNative = "WRB Hidden Gap: WRB rectangle breached from below.";
            }
            else if ((AlertBreachesFromAbove) && ((open0 > High) || (open1 > High)))
            {
                string tfStr = "";
                if (Period() == PERIOD_M1) tfStr = "M1";
                else if (Period() == PERIOD_M5) tfStr = "M5";
                else if (Period() == PERIOD_M15) tfStr = "M15";
                else if (Period() == PERIOD_M30) tfStr = "M30";
                else if (Period() == PERIOD_H1) tfStr = "H1";
                else if (Period() == PERIOD_H4) tfStr = "H4";
                else if (Period() == PERIOD_D1) tfStr = "D1";
                else if (Period() == PERIOD_W1) tfStr = "W1";
                else if (Period() == PERIOD_MN1) tfStr = "MN1";
                
                Text = "WRB Hidden Gap: " + Symbol() + " - " + tfStr + " - WRB rectangle breached from above.";
                TextNative = "WRB Hidden Gap: WRB rectangle breached from above.";
            }
            if (Text != "")
            {
                if (EnableNativeAlerts) Alert(TextNative);
                if (EnableEmailAlerts) SendMail("WRB HG Alert", Text);
                if (EnablePushAlerts) SendNotification(Text);
                ObjectSet(ObjectText, OBJPROP_NAME, ObjectText + "A");
            }
            return;
        }
    }
}

