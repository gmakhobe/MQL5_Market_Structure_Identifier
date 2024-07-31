//+------------------------------------------------------------------+
//|                             mql5_market_structure_identifier.mq5 |
//|                                  Copyright 2024, Given Makhobela |
//|     https://github.com/gmakhobe/MQL5_Market_Structure_Identifier |
//+------------------------------------------------------------------+
//--- Indicator Properties
#property indicator_buffers 2

//--- input parameters
input double          UserDefinedPriceChange     = 0.10625;
input int             UserDefinedSharpness       = 20;
input ENUM_TIMEFRAMES UserDefinedTimeframe       = PERIOD_H1;
input color           UserDefinedAnnotationColor = clrRed;

//--- Tracking Variables
struct Tracker_CurrentState {
    double simpleMovingAverageLatestHigh;
    double simpleMovingAverageLatestLow;
    int    simpleMovingAverageLatestHighIndex;
    int    simpleMovingAverageLatestLowIndex;
    bool   didPriceChangeToBearish;
    bool   didPriceChangeToBullish;
    bool   hasRetracementFromHighStarted;
};

struct Tracker_PrintingState {
    bool canPrintUpperObject;
    bool canPrintLowerObject;
};
//--- Terminal Indicator Variables
double Indicator_SimpleMovingAverage_Data[];
int    Indicator_SimpleMovingAverage_Handler;

Tracker_CurrentState  BullishStateTracker;
Tracker_PrintingState printingStateTracker;

bool IsFirstTimeExecution        = true;
bool IsOverallFirstTimeExecution = true;

//--- Indicaor Buffers
double BufferOfIndicesWithHighs[];   // Records which candles formed highs
double BufferOfIndicesWithLows[];    // Records which candles formed low

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {

    ObjectsDeleteAll(ChartID(), 0, -1);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
    onSetLoadingMessageOninit();
    SetIndexBuffer(0, BufferOfIndicesWithHighs, INDICATOR_DATA);
    SetIndexBuffer(1, BufferOfIndicesWithLows, INDICATOR_DATA);

    Indicator_SimpleMovingAverage_Handler = iMA(Symbol(), UserDefinedTimeframe, UserDefinedSharpness, 0, MODE_SMA, PRICE_CLOSE);

    //--- Initialize tracker
    BullishStateTracker.simpleMovingAverageLatestHigh      = 0.0;
    BullishStateTracker.simpleMovingAverageLatestHighIndex = 0;
    BullishStateTracker.simpleMovingAverageLatestLow       = 0.0;
    BullishStateTracker.simpleMovingAverageLatestLowIndex  = 0;
    BullishStateTracker.didPriceChangeToBearish            = false;
    BullishStateTracker.didPriceChangeToBullish            = false;
    BullishStateTracker.hasRetracementFromHighStarted      = NULL;

    printingStateTracker.canPrintLowerObject = false;
    printingStateTracker.canPrintUpperObject = false;

    if(!Indicator_SimpleMovingAverage_Handler) {
        return INIT_FAILED;
    }

    return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int       rates_total,
                const int       prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[]) {

    if (UserDefinedTimeframe == Period()) {
        double copyOfHigh[];
        double copyOfLow[];

        datetime copyOfTime[];

        ArraySetAsSeries(high, false);
        ArraySetAsSeries(low, false);
        ArraySetAsSeries(time, false);
        ArrayCopy(copyOfHigh, high);
        ArrayCopy(copyOfLow, low);
        ArrayCopy(copyOfTime, time);

        onCalculateAccordingUserDefinedChartTimeframe(rates_total, prev_calculated, copyOfHigh, copyOfLow, copyOfTime);

    }
    else
    {
        
        MqlRates timePriceSeries[];

        datetime startDate = time[0];
        datetime endDate = time[rates_total - 1];

        double copyOfHigh[];
        double copyofLow[];

        datetime copyOfTime[];

        if (!CopyRates(Symbol(), UserDefinedTimeframe, startDate, endDate, timePriceSeries))
        {
            Print("Failed to copy time price series.");
            return rates_total;
        }

        int custom_rates_total = ArraySize(timePriceSeries);
        
        ArrayResize(copyOfHigh, custom_rates_total);
        ArrayResize(copyofLow, custom_rates_total);
        ArrayResize(copyOfTime, custom_rates_total);

        onCopyMqlRatesToArrays(timePriceSeries, copyOfHigh, copyofLow, copyOfTime);

    }
    
    
    if (IsFirstTimeExecution == false)
    {
        onRemoveLoadingMessageDeinit();
    }
    return (rates_total);
}

bool onCopyMqlRatesToArrays(MqlRates &mqlRatesArray[], double &high[], double &low[], datetime &time[])
{

}

//+------------------------------------------------------------------+

int onCalculateAccordingUserDefinedChartTimeframe(int rates_total,
                                              int prev_calculated,
                                              double &copyOfHigh[],
                                              double &copyOfLow[],
                                              datetime &copyOfTime[]
                                              )
{

    int startCountAt;
    int endCountAt;

    if(rates_total < 2 || prev_calculated < 2) {
        return rates_total;
    }

    if(!CopyBuffer(Indicator_SimpleMovingAverage_Handler, 0, 0, rates_total, Indicator_SimpleMovingAverage_Data)) {
        return rates_total;
    }
    //--- Recalculate on new candle

    ArraySetAsSeries(Indicator_SimpleMovingAverage_Data, false);

    if(IsFirstTimeExecution == true) {
        startCountAt         = rates_total / 4;
        endCountAt           = rates_total - 1;
        IsFirstTimeExecution = false;
    } else {
        startCountAt = rates_total - 2;
        endCountAt   = rates_total - 1;
    }

    for(int count = startCountAt; count < endCountAt; count++) {
        double simpleMovingAverageLatestValue = 0;

        int arrayOfIndicesWithHighs[];
        int arrayOfIndicesWithLows[];

        ArraySetAsSeries(BufferOfIndicesWithHighs, false);
        ArraySetAsSeries(BufferOfIndicesWithLows, false);
        ArraySetAsSeries(arrayOfIndicesWithHighs, false);
        ArraySetAsSeries(arrayOfIndicesWithLows, false);

        simpleMovingAverageLatestValue = Indicator_SimpleMovingAverage_Data[count];

        onStateInitialisation(simpleMovingAverageLatestValue, count);
        onRecordNewSimpleMovingAverageHigh(simpleMovingAverageLatestValue, count);
        onPriceRetracementFromSimpleMovingAverageHigh(simpleMovingAverageLatestValue, count);

        if(NormalizeDouble(BufferOfIndicesWithHighs[count], 2) > 1 &&
           printingStateTracker.canPrintUpperObject == true) {
            if(didAddValidValuesFromBuffersToArrays(BufferOfIndicesWithHighs, BufferOfIndicesWithLows, arrayOfIndicesWithHighs, arrayOfIndicesWithLows)) {
                Print("Did Print for highs: ", didDrawAnnotationFromGivenArrayOfHighsAndLows(arrayOfIndicesWithHighs, arrayOfIndicesWithLows, copyOfHigh, copyOfLow, copyOfTime, true, false));
            }
        }
        printingStateTracker.canPrintUpperObject = false;

        if(NormalizeDouble(BufferOfIndicesWithLows[count], 2) > 1 &&
           printingStateTracker.canPrintLowerObject == true) {
            if(didAddValidValuesFromBuffersToArrays(BufferOfIndicesWithHighs, BufferOfIndicesWithLows, arrayOfIndicesWithHighs, arrayOfIndicesWithLows)) {
                Print("Did Print for Lows: ", didDrawAnnotationFromGivenArrayOfHighsAndLows(arrayOfIndicesWithHighs, arrayOfIndicesWithLows, copyOfHigh, copyOfLow, copyOfTime, false, true));
            }
        }
        printingStateTracker.canPrintLowerObject = false;

        ArrayFree(arrayOfIndicesWithHighs);
        ArrayFree(arrayOfIndicesWithLows);
    
    }
    //-- Free array
    ArrayFree(copyOfHigh);
    ArrayFree(copyOfLow);
    ArrayFree(copyOfTime);

    return (rates_total);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void onStateInitialisation(double currentSimpleMovingAverageValue, int currentTotalRates) {
    if(BullishStateTracker.simpleMovingAverageLatestHigh == 0.0 && BullishStateTracker.simpleMovingAverageLatestHighIndex == 0) {
        BullishStateTracker.simpleMovingAverageLatestHigh      = currentSimpleMovingAverageValue;
        BullishStateTracker.simpleMovingAverageLatestHighIndex = currentTotalRates;
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void onRecordNewSimpleMovingAverageHigh(double currentSimpleMovingAverageValue, int currentTotalRates) {
    if(currentSimpleMovingAverageValue > BullishStateTracker.simpleMovingAverageLatestHigh) {
        BullishStateTracker.simpleMovingAverageLatestHigh      = currentSimpleMovingAverageValue;
        BullishStateTracker.simpleMovingAverageLatestHighIndex = currentTotalRates;
        BullishStateTracker.hasRetracementFromHighStarted      = false;
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void onPriceRetracementFromSimpleMovingAverageHigh(double currentSimpleMovingAverageValue, int currentTotalRates) {
    if(currentSimpleMovingAverageValue < BullishStateTracker.simpleMovingAverageLatestHigh) {

        if(BullishStateTracker.hasRetracementFromHighStarted == false) {
            BullishStateTracker.simpleMovingAverageLatestLow      = currentSimpleMovingAverageValue;
            BullishStateTracker.simpleMovingAverageLatestLowIndex = currentTotalRates;
            BullishStateTracker.hasRetracementFromHighStarted     = true;
        }

        if(BullishStateTracker.hasRetracementFromHighStarted == true && currentSimpleMovingAverageValue < BullishStateTracker.simpleMovingAverageLatestLow) {
            BullishStateTracker.simpleMovingAverageLatestLow      = currentSimpleMovingAverageValue;
            BullishStateTracker.simpleMovingAverageLatestLowIndex = currentTotalRates;
        }

        /**
           Calculation to get price change from recorded high.
           : Price Percentage Change = 100 - ([Current Price / Highest Price] * 100)
        **/
        double pricePercentageChangeFromHigh = (100 - (BullishStateTracker.simpleMovingAverageLatestLow / BullishStateTracker.simpleMovingAverageLatestHigh) * 100);
        /**
         * Rules to identify if price is now bullish and high can be set
         **/
        if(pricePercentageChangeFromHigh > UserDefinedPriceChange &&
           BullishStateTracker.didPriceChangeToBearish == false &&
           BullishStateTracker.hasRetracementFromHighStarted == true) {
            BullishStateTracker.didPriceChangeToBearish = true;
            BufferOfIndicesWithHighs[currentTotalRates] = 981105;
            printingStateTracker.canPrintUpperObject    = true;
        }
    }

    double pricePercentageChangeFromLow = (100 - (BullishStateTracker.simpleMovingAverageLatestLow / currentSimpleMovingAverageValue) * 100);

    if(pricePercentageChangeFromLow > UserDefinedPriceChange &&
       BullishStateTracker.simpleMovingAverageLatestLow < currentSimpleMovingAverageValue &&
       BullishStateTracker.didPriceChangeToBearish == true) {
        BullishStateTracker.simpleMovingAverageLatestHigh      = currentSimpleMovingAverageValue;
        BullishStateTracker.simpleMovingAverageLatestHighIndex = currentTotalRates;
        BullishStateTracker.didPriceChangeToBearish            = false;
        BufferOfIndicesWithLows[currentTotalRates]             = 981105;
        printingStateTracker.canPrintLowerObject               = true;
        onRecordNewSimpleMovingAverageHigh(currentSimpleMovingAverageValue, currentTotalRates);
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int onGetTotalOfIndicesWithValidValues(double &array[], int arraySize) {
    int indicesWithValidNumbers = 0;

    for(int count = 0; count < arraySize; count++) {
        if(array[count] == 981105) {
            indicesWithValidNumbers++;
        }
    }

    return indicesWithValidNumbers;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void onSetValidValuesFromBufferToAnArray(int &arrayRef[], double &buffer[], int sizeOfBuffer) {
    int countOf_ArrayRef = 0;

    for(int count = 0; count < sizeOfBuffer; count++) {
        if(buffer[count] == 981105) {
            arrayRef[countOf_ArrayRef] = (int)count;
            countOf_ArrayRef           = countOf_ArrayRef + 1;
        }
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool onDrawHighorLowAnnotation(string objectName, double initialContactPrice, datetime initialContactDate, double lastContactPrice, datetime lastContactDate) {
    long chart_ID = ChartID();
    if(!ObjectCreate(chart_ID, objectName, OBJ_TREND, 0, initialContactDate, initialContactPrice, lastContactDate, lastContactPrice)) {
        Print("Failed to print: ", objectName);
    }

    ObjectSetInteger(chart_ID, objectName, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(chart_ID, objectName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(chart_ID, objectName, OBJPROP_WIDTH, 4);
    ObjectSetInteger(chart_ID, objectName, OBJPROP_RAY, false);
    ObjectSetInteger(chart_ID, objectName, OBJPROP_BACK, false);
    ObjectSetInteger(chart_ID, objectName, OBJPROP_RAY_LEFT, false);
    ObjectSetInteger(chart_ID, objectName, OBJPROP_RAY_RIGHT, false);
    ObjectSetInteger(chart_ID, objectName, OBJPROP_ZORDER, 0);
    ObjectSetInteger(chart_ID, objectName, OBJPROP_COLOR, UserDefinedAnnotationColor);
    ObjectSetString(chart_ID, objectName, OBJPROP_TEXT, "From Market Structure Identifier");

    return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool didAddValidValuesFromBuffersToArrays(double &bufferOfIndicesWithHighs[], double &bufferOfIndicesWithLows[], int &arrayOfIndicesWithHighs[], int &arrayOfIndicesWithLows[]) {
    int numberOfValidIndicesWithHighs   = 0;
    int numberOfValidIndicesWithLows    = 0;
    int sizeOf_BufferOfIndicesWithHighs = ArraySize(bufferOfIndicesWithHighs);
    int sizeOf_BufferOfIndicesWithLows  = ArraySize(bufferOfIndicesWithLows);

    //--- Return indices with valid numbers
    numberOfValidIndicesWithHighs = onGetTotalOfIndicesWithValidValues(bufferOfIndicesWithHighs, sizeOf_BufferOfIndicesWithHighs);
    numberOfValidIndicesWithLows  = onGetTotalOfIndicesWithValidValues(bufferOfIndicesWithLows, sizeOf_BufferOfIndicesWithLows);

    if(!ArrayResize(arrayOfIndicesWithHighs, numberOfValidIndicesWithHighs)) {
        return false;
    }
    if(!ArrayResize(arrayOfIndicesWithLows, numberOfValidIndicesWithLows)) {
        return false;
    }
    //--- Copy Valid indices into an array
    onSetValidValuesFromBufferToAnArray(arrayOfIndicesWithHighs, BufferOfIndicesWithHighs, sizeOf_BufferOfIndicesWithHighs);
    onSetValidValuesFromBufferToAnArray(arrayOfIndicesWithLows, BufferOfIndicesWithLows, sizeOf_BufferOfIndicesWithLows);

    return true;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool didDrawAnnotationFromGivenArrayOfHighsAndLows(int &arrayOfIndicesWithHighs[], int &arrayOfIndicesWithLows[], double &high[], double &low[], datetime &time[], bool isCurrentInstanceForHighs, bool isCurrentInstanceForLows) {
    //--- Get Candle Stick with the highest high on a given range
    int    indexOfTheCandlesHigh = 0;
    double valueOfTheCandlesHigh = 0;
    int    indexOfTheCandlesLow  = 1000000;
    double valueOfTheCandlesLow  = 1000000;

    int calculationsForTheHigh_startingPoint = 0;
    int calculationsForTheHigh_endingPoint   = 0;
    int calculationsForTheLow_startingPoint  = 0;
    int calculationsForTheLow_endingPoint    = 0;
    int arrayOfIndicesWithHighs_Length       = ArraySize(arrayOfIndicesWithHighs);
    int arrayOfIndicesWithLows_Length        = ArraySize(arrayOfIndicesWithLows);

    bool hasExecuted = false;

    if(ArraySize(arrayOfIndicesWithHighs) < 2) {
        return false;
    }
    if(ArraySize(arrayOfIndicesWithLows) < 2) {
        return false;
    }

    if(isCurrentInstanceForHighs) {
        calculationsForTheHigh_startingPoint = arrayOfIndicesWithLows[arrayOfIndicesWithLows_Length - 1];
        calculationsForTheHigh_endingPoint   = arrayOfIndicesWithHighs[arrayOfIndicesWithHighs_Length - 1];

        for(int count = calculationsForTheHigh_startingPoint; count < calculationsForTheHigh_endingPoint; count++) {
            if(high[count] > valueOfTheCandlesHigh) {
                valueOfTheCandlesHigh = high[count];
                indexOfTheCandlesHigh = count;
            }
        }

        string objectName = "High-Index_" + IntegerToString(indexOfTheCandlesHigh);
        return onDrawHighorLowAnnotation(objectName, valueOfTheCandlesHigh, time[indexOfTheCandlesHigh], valueOfTheCandlesHigh, onGetTimeForTheNextCandlesBasedOnTimeframe(time[indexOfTheCandlesHigh], 3));
    }

    if(isCurrentInstanceForLows) {

        calculationsForTheLow_startingPoint = arrayOfIndicesWithHighs[arrayOfIndicesWithHighs_Length - 1];
        calculationsForTheLow_endingPoint   = arrayOfIndicesWithLows[arrayOfIndicesWithLows_Length - 1];

        for(int count = calculationsForTheLow_startingPoint; count < calculationsForTheLow_endingPoint; count++) {
            if(low[count] < valueOfTheCandlesLow) {
                valueOfTheCandlesLow = low[count];
                indexOfTheCandlesLow = count;
            }
        }
        if(calculationsForTheLow_startingPoint == calculationsForTheLow_endingPoint) {
            valueOfTheCandlesLow = low[calculationsForTheLow_startingPoint + 1];
            indexOfTheCandlesLow = calculationsForTheLow_startingPoint + 1;
        }

        string objectName = "Low-Index_" + IntegerToString(indexOfTheCandlesLow);
        return onDrawHighorLowAnnotation(objectName, valueOfTheCandlesLow, time[indexOfTheCandlesLow], valueOfTheCandlesLow, onGetTimeForTheNextCandlesBasedOnTimeframe(time[indexOfTheCandlesLow], 3));
    }
    return false;
}

datetime onGetTimeForTheNextCandlesBasedOnTimeframe(datetime currentDate, int numberOfCandles) {
    if(UserDefinedTimeframe == PERIOD_M5) {
        return currentDate + ((numberOfCandles * 5) * 60);
    } else if(UserDefinedTimeframe == PERIOD_M15) {
        return currentDate + ((numberOfCandles * 15) * 60);
    } else if(UserDefinedTimeframe == PERIOD_M30) {
        return currentDate + ((numberOfCandles * 30) * 60);
    } else if(UserDefinedTimeframe == PERIOD_H1) {
        return currentDate + ((numberOfCandles * 60) * 60);
    } else if(UserDefinedTimeframe == PERIOD_H4) {
        return currentDate + ((numberOfCandles * 240) * 60);
    } else if(UserDefinedTimeframe == PERIOD_D1) {
        return currentDate + ((numberOfCandles * 240) * 60);
    }

    return currentDate;
}

void onRemoveLoadingMessageDeinit() {
    string name = "Loading_Message";
    
    if(!ObjectDelete(ChartID(), name))
     {
      Print(__FUNCTION__, ": failed to delete a text label text label for Loading_Message!");
      return ;
     }
}

void onSetLoadingMessageOninit() {
    string name = "Loading_Message";

    if(!ObjectCreate(ChartID(), name, OBJ_LABEL, 0, 0, 0)) {
        Print(__FUNCTION__, ": failed to create text label for Loading_Message!");
        return;
    }

    long xDistance = 150;
    long yDistance = 150;

    if(!ChartGetInteger(ChartID(), CHART_WIDTH_IN_PIXELS, 0, xDistance)) {
        Print("Failed to get the chart width!");
        return ;
    }
    if(!ChartGetInteger(ChartID(), CHART_HEIGHT_IN_PIXELS, 0, yDistance)) {
        Print("Failed to get the chart height!");
        return ;
    }
    ObjectSetInteger(ChartID(), name, OBJPROP_XDISTANCE, (xDistance / 3.2));
    ObjectSetInteger(ChartID(), name, OBJPROP_YDISTANCE, (yDistance / 2.2));
    ObjectSetInteger(ChartID(), name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetString(ChartID(), name, OBJPROP_TEXT, "Please wait, Loading MSI!");
    ObjectSetString(ChartID(), name, OBJPROP_FONT, "Arial");
    ObjectSetInteger(ChartID(), name, OBJPROP_FONTSIZE, 30);
    ObjectSetDouble(ChartID(), name, OBJPROP_ANGLE, 0.0);
    ObjectSetInteger(ChartID(), name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(ChartID(), name, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(ChartID(), name, OBJPROP_ZORDER, 0);
}
//+------------------------------------------------------------------+
