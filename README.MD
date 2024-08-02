# Indicator Overview
### Name:
Market Structure Identifier.

### Purpose:
Identifies highs and lows using paverage price change.

### Concept:
#### Utility Indicator(s):
##### Simple Moving Average
Indicator Options:
- 1: Lookback of 20

##### Custom Calculations
Calculations Logic:
- Price change of 10.6 on 4 hour timeframe

The idea is to use a simple moving average with the above specified lookback and user preferred price change to identify market structure (Market Structure is a series of prices in a price time series forming higher highs and higher lows or lower lows and lower highs at a specific time range).

#### Identifying Market Structure
##### Typical Way (How a person identify market structure or price trend)
Higher Highs and Higher Lows: The most basic definition of an uptrend is a series of price movements where each successive peak (high) and trough (low) is higher than the previous ones.

###### Trendlines:
- Drawing a line connecting the rising lows confirms the uptrend.
- A valid uptrend line should have at least two touchpoints.
###### Broken Down
- On price printing there has to be price peaks in a way that the previous peak is lower than the next peak and this includes the troughs in price formation,
- A strong trend to the upside has at least 2 peaks and two troughs that follows the above rules.
This is the same when identifying a down trend however the rules are different in this case we expect the recent peaks and troughs to be lower than the previous ones.

##### How the idea is when translated into codebase (In this case we are going to use pseudocode to remove unnecessary complications)
The logic on a 4 hour timeframe Pound Dollar Pair:
- Take Simple Moving Average with a lookback period of 20
- When the Simple Moving Average experiences a 10.6% price change then that marks a reversal point.
- This will record the index of an array which carries Simple Moving Average calculations.
- The index will be used so that we get the current price.
- We take the current price index so that we identify the current price
- On the current price, we loop back so that we identify the highest candle between the current price change when price forms a high and the previous price change when price formed a low.
- Once the high is identified we create an object that puts an annotation on the chart and that also adds a value to a buffer which can later be accessed via an indicator.

### Indicator Outputs:
#### Visually
Prints highs and lows on a chart to show current price behaviour including the triggure candle. The triggure candle is a candle in which price change take effects when it closes/opens. 
#### Data-wise
Since I was not sure about what data should be accessed programmatically, I have exposed 2 buffers that have access to highs and lows indices.

### Trading Signals:
This indicator does not give any trade signals it is an instrument to be used nto validate the identification of highs and lows on a pricetime series.

### Interpretation and Usage:
REDACTED!!!

### Installation Instructions:
1. Locate the Downloaded Indicator: Find the indicator file (usually with a .mq5 or .ex5 extension) in your computer's "Downloads" folder or wherever you saved it.
2. Open the MQL5 Data Folder:
    - MetaTrader 5: Open your MetaTrader 5 platform.
    - File Menu: Go to the "File" menu and select "Open Data Folder."   
    - MQL5 Folder: In the folder that opens, navigate to the "MQL5" folder.
3. Indicators Folder: Inside the "MQL5" folder, find and open the "Indicators" folder.
4. Copy the Indicator:

    - Copy the downloaded indicator file (.mq5 or .ex5).
    - Paste it directly into the "Indicators" folder.
5. Restart MetaTrader 5: Close and then reopen MetaTrader 5.
6. Refresh the Navigator:
    - Navigator Window: Make sure the "Navigator" window is visible (usually on the left side of the platform).
    - Right-Click: Right-click on "Indicators" in the Navigator window.   
    - Refresh: Select "Refresh" from the context menu.
7. Find Your Indicator: Your newly installed indicator should now appear in the "Indicators" list under the "Custom" category in the Navigator window.

8. Add to Chart: Double-click on the indicator's name in the Navigator window to add it to the current chart, or drag and drop it onto the chart.

