//+------------------------------------------------------------------+
//|                             mql5_market_structure_identifier.mq5 |
//|                                  Copyright 2024, Given Makhobela |
//|     https://github.com/gmakhobe/MQL5_Market_Structure_Identifier |
//+------------------------------------------------------------------+
//--- Indicator Properties
#property indicator_buffers 2

//--- input parameters
input double   UserDefinedPriceChange=0.10625;
input int      UserDefinedSharpness=20;
input ENUM_TIMEFRAMES UserDefinedTimeframe=PERIOD_CURRENT;

//--- Tracking Variables
struct Tracker_CurrentState
  {
   double            simpleMovingAverageLatestHigh;
   double            simpleMovingAverageLatestLow;
   int               simpleMovingAverageLatestHighIndex;
   int               simpleMovingAverageLatestLowIndex;
   bool              didPriceChangeBearishGreaterThanUserDefinedPriceChange;
   bool              didPriceChangeBullishGreaterThanUserDefinedPriceChange;
   bool              hasRetracementFromHighStarted;
  };

//--- Terminal Indicator Variables
double Indicator_SimpleMovingAverage_Data[];
int Indicator_SimpleMovingAverage_Handler;

Tracker_CurrentState BullishStateTracker;


//--- Indicaor Buffers
double BufferOfIndicesWithHighs[]; // Records which candles formed highs
double BufferOfIndicesWithLows[]; // Records which candles formed low

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferOfIndicesWithHighs, INDICATOR_DATA);
   SetIndexBuffer(1, BufferOfIndicesWithLows, INDICATOR_DATA);

   Indicator_SimpleMovingAverage_Handler = iMA(Symbol(), UserDefinedTimeframe, UserDefinedSharpness, 0, MODE_SMA, PRICE_CLOSE);

//--- Initialize tracker
   BullishStateTracker.simpleMovingAverageLatestHigh = 0.0;
   BullishStateTracker.simpleMovingAverageLatestHighIndex = 0;
   BullishStateTracker.simpleMovingAverageLatestLow = 0.0;
   BullishStateTracker.simpleMovingAverageLatestLowIndex = 0;
   BullishStateTracker.didPriceChangeBearishGreaterThanUserDefinedPriceChange = false;
   BullishStateTracker.didPriceChangeBullishGreaterThanUserDefinedPriceChange = false;
   BullishStateTracker.hasRetracementFromHighStarted = NULL;

   if(!Indicator_SimpleMovingAverage_Handler)
     {
      return INIT_FAILED;
     }

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
  {
   double simpleMovingAverageLatestValue = 0;
   int arrayOfIndicesWithHighs[];
   int arrayOfIndicesWithLows[];
   double copyOfHigh[];
   double copyOfLow[];
   datetime copyOfTime[];

   ArraySetAsSeries(BufferOfIndicesWithHighs, false);
   ArraySetAsSeries(BufferOfIndicesWithLows, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(arrayOfIndicesWithHighs, false);
   ArraySetAsSeries(arrayOfIndicesWithLows, false);
   
   ArrayCopy(copyOfHigh, high);
   ArrayCopy(copyOfLow, low);
   ArrayCopy(copyOfTime, time);
   

   //--- Set to zero by default with zero representing empty.
   BufferOfIndicesWithHighs[0] = 0;
   BufferOfIndicesWithLows[0] = 0;
//--- Failed to Copy SMA Data
   if(!CopyBuffer(Indicator_SimpleMovingAverage_Handler, 0, 0, rates_total, Indicator_SimpleMovingAverage_Data))
     {
      return rates_total;
     }
//--- Recalculate on new candle
   if(rates_total == prev_calculated)
     {
      return rates_total;
     }

   ArraySetAsSeries(Indicator_SimpleMovingAverage_Data, true);

   simpleMovingAverageLatestValue = Indicator_SimpleMovingAverage_Data[0];

   onStateInitialisation(simpleMovingAverageLatestValue, rates_total);
   onRecordNewSimpleMovingAverageHigh(simpleMovingAverageLatestValue, rates_total);
   onPriceRetracementFromSimpleMovingAverageHigh(simpleMovingAverageLatestValue, rates_total);

   if (NormalizeDouble(BufferOfIndicesWithHighs[rates_total - 1], 2) > 1)
   {
      if (didAddValidValuesFromBuffersToArrays(BufferOfIndicesWithHighs, BufferOfIndicesWithLows, arrayOfIndicesWithHighs, arrayOfIndicesWithLows))
      {
         Print("Did Print for highs: ", didDrawAnnotationFromGivenArrayOfHighsAndLows(arrayOfIndicesWithHighs, arrayOfIndicesWithLows, copyOfHigh, copyOfLow, copyOfTime, true, false));
      }
   }

   if (NormalizeDouble(BufferOfIndicesWithLows[rates_total - 1], 2) > 1)
   {
      if(didAddValidValuesFromBuffersToArrays(BufferOfIndicesWithHighs, BufferOfIndicesWithLows, arrayOfIndicesWithHighs, arrayOfIndicesWithLows))
      {
         Print("Did Print for Lows: ", didDrawAnnotationFromGivenArrayOfHighsAndLows(arrayOfIndicesWithHighs, arrayOfIndicesWithLows, copyOfHigh, copyOfLow, copyOfTime, false, true));
      }
      
   }

   return(rates_total);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void onStateInitialisation(double currentSimpleMovingAverageValue, int currentTotalRates)
  {
   if(BullishStateTracker.simpleMovingAverageLatestHigh == 0.0 && BullishStateTracker.simpleMovingAverageLatestHighIndex == 0)
     {
      BullishStateTracker.simpleMovingAverageLatestHigh = currentSimpleMovingAverageValue;
      BullishStateTracker.simpleMovingAverageLatestHighIndex = currentTotalRates;
      //Print("==== State Initialized =====");
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void onRecordNewSimpleMovingAverageHigh(double currentSimpleMovingAverageValue, int currentTotalRates)
  {
   if(currentSimpleMovingAverageValue > BullishStateTracker.simpleMovingAverageLatestHigh)
     {
      BullishStateTracker.simpleMovingAverageLatestHigh = currentSimpleMovingAverageValue;
      BullishStateTracker.simpleMovingAverageLatestHighIndex = currentTotalRates;
      BullishStateTracker.hasRetracementFromHighStarted = false;
      BullishStateTracker.didPriceChangeBearishGreaterThanUserDefinedPriceChange = false;
      BullishStateTracker.didPriceChangeBullishGreaterThanUserDefinedPriceChange = false;
      //Print("Reset: hasRetracementFromHighStarted, didPriceChangeBearishGreaterThanUserDefinedPriceChange, didPriceChangeBullishGreaterThanUserDefinedPriceChange has been set to false.");
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void onPriceRetracementFromSimpleMovingAverageHigh(double currentSimpleMovingAverageValue, int currentTotalRates)
  {
   if(currentSimpleMovingAverageValue < BullishStateTracker.simpleMovingAverageLatestHigh)
     {

      if(BullishStateTracker.hasRetracementFromHighStarted == false)
        {
         BullishStateTracker.simpleMovingAverageLatestLow = currentSimpleMovingAverageValue;
         BullishStateTracker.simpleMovingAverageLatestLowIndex = currentTotalRates;
         BullishStateTracker.hasRetracementFromHighStarted = true;
        }

      if(BullishStateTracker.hasRetracementFromHighStarted == true && currentSimpleMovingAverageValue <= BullishStateTracker.simpleMovingAverageLatestLow)
        {
         BullishStateTracker.simpleMovingAverageLatestLow = currentSimpleMovingAverageValue;
         BullishStateTracker.simpleMovingAverageLatestLowIndex = currentTotalRates;
        }

      /**
         Calculation to get price change from recorded high.
         : Price Percentage Change = 100 - ([Current Price / Highest Price] * 100)
      **/
      double pricePercentageChangeFromHigh = (100 - (BullishStateTracker.simpleMovingAverageLatestLow/BullishStateTracker.simpleMovingAverageLatestHigh) * 100);
      double pricePercentageChangeFromLow = (100 - (BullishStateTracker.simpleMovingAverageLatestLow/currentSimpleMovingAverageValue) * 100);

      if(pricePercentageChangeFromHigh > UserDefinedPriceChange && BullishStateTracker.didPriceChangeBearishGreaterThanUserDefinedPriceChange == false)
        {
         Print("High recorded!, Price Change: ", pricePercentageChangeFromHigh);
         BullishStateTracker.didPriceChangeBearishGreaterThanUserDefinedPriceChange = true;
         BufferOfIndicesWithHighs[currentTotalRates - 1] = currentTotalRates;
        }

      if(pricePercentageChangeFromLow > UserDefinedPriceChange && BullishStateTracker.simpleMovingAverageLatestLow < currentSimpleMovingAverageValue && BullishStateTracker.didPriceChangeBullishGreaterThanUserDefinedPriceChange == false)
        {
         BullishStateTracker.simpleMovingAverageLatestHigh = currentSimpleMovingAverageValue;
         BullishStateTracker.simpleMovingAverageLatestHighIndex = currentTotalRates;
         BullishStateTracker.didPriceChangeBullishGreaterThanUserDefinedPriceChange = true;
         BufferOfIndicesWithLows[currentTotalRates - 1] = currentTotalRates;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int onGetTotalOfIndicesWithValidValues(double &array[], int arraySize)
  {
   int indicesWithValidNumbers = 0;

   for(int count = 0; count < arraySize; count++)
     {
      if(NormalizeDouble(array[count], 2) > 1)
        {
         indicesWithValidNumbers++;
        }
     }

   return indicesWithValidNumbers;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void onSetValidValuesFromBufferToAnArray(int &arrayRef[], double &buffer[], int sizeOfBuffer)
  {
   int countOf_ArrayRef = 0;

   for(int count = 0; count < sizeOfBuffer; count++)
     {
      if(NormalizeDouble(buffer[count], 2) > 1)
        {
         arrayRef[countOf_ArrayRef] = buffer[count];
         countOf_ArrayRef++;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool onDrawHighorLowAnnotation(string objectName, double initialContactPrice, datetime initialContactDate, double lastContactPrice, datetime lastContactDate)
  {
   long chart_ID = 0;
   if (!ObjectCreate(chart_ID, objectName, OBJ_TREND, 0, initialContactDate, initialContactPrice, lastContactDate, lastContactPrice)) {
      Print("Failed to print: ", objectName);
   }
   
   ObjectSetInteger(chart_ID,objectName,OBJPROP_COLOR,clrRed);
   ObjectSetInteger(chart_ID,objectName,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(chart_ID,objectName,OBJPROP_WIDTH,4);
   ObjectSetInteger(chart_ID,objectName,OBJPROP_RAY,false);
   ObjectSetInteger(chart_ID,objectName,OBJPROP_BACK,false);
   ObjectSetInteger(chart_ID,objectName,OBJPROP_RAY_LEFT,false);
   ObjectSetInteger(chart_ID,objectName,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(chart_ID,objectName,OBJPROP_ZORDER,0);
   
   return true;
  }
  
bool didAddValidValuesFromBuffersToArrays(double &bufferOfIndicesWithHighs[], double &bufferOfIndicesWithLows[], int &arrayOfIndicesWithHighs[], int &arrayOfIndicesWithLows[])
{
   int numberOfValidIndicesWithHighs = 0;
   int numberOfValidIndicesWithLows = 0;
   int sizeOf_BufferOfIndicesWithHighs = ArraySize(bufferOfIndicesWithHighs);
   int sizeOf_BufferOfIndicesWithLows = ArraySize(bufferOfIndicesWithLows);
   
   //--- Return indices with valid numbers
   numberOfValidIndicesWithHighs = onGetTotalOfIndicesWithValidValues(bufferOfIndicesWithHighs, sizeOf_BufferOfIndicesWithHighs);
   numberOfValidIndicesWithLows = onGetTotalOfIndicesWithValidValues(bufferOfIndicesWithLows, sizeOf_BufferOfIndicesWithLows);

   if (!ArrayResize(arrayOfIndicesWithHighs, numberOfValidIndicesWithHighs)) {
      Print("Failed to resize Array: arrayOfIndicesWithHighs - ArraySize = ", numberOfValidIndicesWithHighs);
      return false;
   }
   if (!ArrayResize(arrayOfIndicesWithLows, numberOfValidIndicesWithLows)) {
      Print("Failed to resize Array: arrayOfIndicesWithLows - ArraySize = ", numberOfValidIndicesWithLows);
      return false;
   }
      //--- Copy Valid indices into an array
   onSetValidValuesFromBufferToAnArray(arrayOfIndicesWithHighs, BufferOfIndicesWithHighs, sizeOf_BufferOfIndicesWithHighs);
   onSetValidValuesFromBufferToAnArray(arrayOfIndicesWithLows, BufferOfIndicesWithLows, sizeOf_BufferOfIndicesWithLows);
   
   return true;
}
//+------------------------------------------------------------------+

bool didDrawAnnotationFromGivenArrayOfHighsAndLows(int &arrayOfIndicesWithHighs[], int &arrayOfIndicesWithLows[], double &high[], double &low[], datetime &time[], bool isCurrentInstanceForHighs, bool isCurrentInstanceForLows)
{
   //--- Get Candle Stick with the highest high on a given range
   int indexOfTheCandlesHigh = 0;
   double valueOfTheCandlesHigh = 0;
   int indexOfTheCandlesLow = 1000000;
   double valueOfTheCandlesLow = 1000000;
   
   int calculationsForTheHigh_startingPoint = 0;
   int calculationsForTheHigh_endingPoint = 0;
   int calculationsForTheLow_startingPoint = 0;
   int calculationsForTheLow_endingPoint = 0;
   
   bool hasExecuted = false;
   
   if (ArraySize(arrayOfIndicesWithHighs) < 2) {
         return false;
      }
      if (ArraySize(arrayOfIndicesWithLows) < 2) {
         return false;
      }
   
   if (isCurrentInstanceForHighs)
   {
      
      calculationsForTheHigh_startingPoint = arrayOfIndicesWithLows[ArraySize(arrayOfIndicesWithLows) - 1];
      calculationsForTheHigh_endingPoint = arrayOfIndicesWithHighs[ArraySize(arrayOfIndicesWithHighs) - 1];
       
      for (int count = calculationsForTheHigh_startingPoint; count < calculationsForTheHigh_endingPoint; count++)
      {
         if (high[count]> valueOfTheCandlesHigh)
         {
            valueOfTheCandlesHigh = high[count];
            indexOfTheCandlesHigh = count;
         }
      }

      string objectName = "High-Index_" + IntegerToString(indexOfTheCandlesHigh);
      return onDrawHighorLowAnnotation(objectName, valueOfTheCandlesHigh, time[indexOfTheCandlesHigh], valueOfTheCandlesHigh, time[indexOfTheCandlesHigh + 3]);
   }
   
   if (isCurrentInstanceForLows)
   {
      calculationsForTheLow_startingPoint = arrayOfIndicesWithHighs[ArraySize(arrayOfIndicesWithHighs) - 1];
      calculationsForTheLow_endingPoint = arrayOfIndicesWithLows[ArraySize(arrayOfIndicesWithLows) - 1];
      
      Print("Selected Starting Point: ", calculationsForTheLow_startingPoint);
      Print("Selected Ending Point: ", calculationsForTheLow_endingPoint);

      for (int count = calculationsForTheLow_startingPoint; count < calculationsForTheLow_endingPoint; count++)
      {
         if ( low[count] < valueOfTheCandlesLow)
         {
            valueOfTheCandlesLow = low[count];
            indexOfTheCandlesLow = count;
         }
      }

      string objectName = "Low-Index_" + IntegerToString(indexOfTheCandlesLow);
      
      Print("When printing low");
      ArrayPrint(arrayOfIndicesWithHighs);
      ArrayPrint(arrayOfIndicesWithLows);
      Print("Index of low: ", indexOfTheCandlesLow);
      return onDrawHighorLowAnnotation(objectName, valueOfTheCandlesLow, time[indexOfTheCandlesLow], valueOfTheCandlesLow, time[indexOfTheCandlesLow + 3]);
   }
   return false;
}
