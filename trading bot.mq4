//+------------------------------------------------------------------+
//|                                                FOREX_TRADING.mq4 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql4.com |
//+------------------------------------------------------------------+

#property copyright   "2005-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property description "Forex Trading Bot"

#define MAGICNUM 20131111 
// External variables
extern double LotSize = 0.1;
extern double StopLoss = 100;
extern double TakeProfit = 200;
extern int Slippage = 5;
extern int MagicNumber = 123;
extern int FastMAPeriod = 10;
extern int SlowMAPeriod = 20;

// Global variables
int BuyTicket;
int SellTicket;
int TickCount=0;

double UsePoint;
int UseSlippage;
// Init function
int init()
  {
   UsePoint = PipPoint(Symbol());  //get the pip value, which is the smallest price change that the currency can make
   UseSlippage = GetSlippage(Symbol(),Slippage); //used to get the current slippage for the current symbol
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   Print("DeInitialized OK");

   return(0);
 }  
//+------------------------------------------------------------------+
//+ onTick Function                                                  |
//+------------------------------------------------------------------+
int start()
  {
   double balance = AccountBalance();
    int orderType = OP_BUY;
   TickCount++;
   Comment("Current Account Balance: ",balance, "\nTicks Received:", TickCount);
//----- Moving averages
   double FastMA = iMA(NULL,0,FastMAPeriod,0,0,0,0);
   double SlowMA = iMA(NULL,0,SlowMAPeriod,0,0,0,0);
//----- Buy order
   if(FastMA > SlowMA && BuyTicket == 0)
     {
      OrderSelect(SellTicket,SELECT_BY_TICKET);
      // Close order
      if(OrderCloseTime() == 0 && SellTicket > 0)
        {
         double CloseLots = OrderLots();
         double ClosePrice = Ask;
         bool Closed = OrderClose(SellTicket,CloseLots,ClosePrice,UseSlippage,Red);
        }
      double OpenPrice = Ask;
      // Calculate stop loss and take profit
      if(StopLoss > 0)
         double BuyStopLoss = OpenPrice - (StopLoss * UsePoint);
      if(TakeProfit > 0)
         double BuyTakeProfit = OpenPrice + (TakeProfit * UsePoint);
      // Open buy order
      BuyTicket = OrderSend(Symbol(),OP_BUY,LotSize,OpenPrice,UseSlippage,BuyStopLoss,BuyTakeProfit,"Buy Order",MagicNumber,0,Green);
      SellTicket = 0; 
     }
//----- Sell Order
   if(FastMA < SlowMA && SellTicket == 0)
     {
      OrderSelect(BuyTicket,SELECT_BY_TICKET);
      if(OrderCloseTime() == 0 && BuyTicket > 0)
        {
         CloseLots = OrderLots();
         ClosePrice = Bid;
         Closed = OrderClose(BuyTicket,CloseLots,ClosePrice,UseSlippage,Red);
        }
      OpenPrice = Bid;
      if(StopLoss > 0)
         double SellStopLoss = OpenPrice + (StopLoss * UsePoint);
      if(TakeProfit > 0)
         double SellTakeProfit = OpenPrice - (TakeProfit * UsePoint);
      SellTicket = OrderSend(Symbol(),OP_SELL,LotSize,OpenPrice,UseSlippage,SellStopLoss,SellTakeProfit,"Sell Order",MagicNumber,0,Red);
      BuyTicket = 0;
     }
     for (int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if (OrderProfit() < 0) 
         {
            Print("Loss detected, splitting position size and account balance");
            LotSize = LotSize*2;
            balance = balance/2;
            
            if (orderType == OP_BUY)//If the order is buy then the next order will be sell
             {
              orderType = OP_SELL; // after buy, sell order
             }
              else if (orderType == OP_SELL)//If the order is sell then the next order will be sell
             {
               orderType = OP_BUY; //after sell, buy order
             }
             Trade(StopLoss, TakeProfit, orderType, LotSize);
                break;
         }
      }
     }
     
      // If we are in a loss - Try to BreakEven 
      Print("Current Unrealized Profit on Order: ", OrderProfit());
      if(OrderProfit() < 0){
        BreakEven(MAGICNUM);
      }
      
   return(0);
  }
//+------------------------------------------------------------------+
//+ PIPs Function                                                    |
//+------------------------------------------------------------------+
double PipPoint(string Currency)
  {
   int CalcDigits = MarketInfo(Currency,MODE_DIGITS);
   if(CalcDigits == 2 || CalcDigits == 3)
      double CalcPoint = 0.01;
   else
      if(CalcDigits == 4 || CalcDigits == 5)
         CalcPoint = 0.0001;
   return(CalcPoint);
  }
//+------------------------------------------------------------------+
//+ Slippage Function                                                    |
//+------------------------------------------------------------------+
int GetSlippage(string Currency, int SlippagePips)
  {
   int CalcDigits = MarketInfo(Currency,MODE_DIGITS);
   if(CalcDigits == 2 || CalcDigits == 4)
      double CalcSlippage = SlippagePips;
   else
      if(CalcDigits == 3 || CalcDigits == 5)
         CalcSlippage = SlippagePips * 10;
   return(CalcSlippage);
  }
//+------------------------------------------------------------------+
//+ Break Even                                                       |
//+------------------------------------------------------------------+
bool BreakEven(int MN){
  int Ticket;
  for(int i = OrdersTotal() - 1; i >= 0; i--) {
    OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
    if(OrderSymbol() == Symbol() && OrderMagicNumber() == MN){
      Ticket = OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice(), OrderTakeProfit(), 0, Green);
      if(Ticket < 0) Print("Error in Break Even : ", GetLastError());
        break;
      }
    }
  return(Ticket);
}
//+------------------------------------------------------------------+
//+ Split position Size                                                     |
//+------------------------------------------------------------------+
void Trade(double stopLoss, double takeProfit, int orderType, double lotSize)
{
   double price = NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_ASK), _Digits);
   int ticket = OrderSend(Symbol(), orderType, lotSize, price, Slippage, stopLoss, takeProfit, "", MAGICNUM, 0, Red);
    if (ticket > 0) //If the trade is open
    {
        if (OrderSelect(ticket, SELECT_BY_TICKET))
        {
            Print("Order opened successfully");
        }
    }
    else 
    {
        // If there is no open order
        Print("Order send failed with error code ", GetLastError());
    }
}
