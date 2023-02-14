//+------------------------------------------------------------------+
//|                                                                  |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#define SLEEP_OK     250
#define SLEEP_ERR    250
//---- input parameters
extern int     Magic = 12346;
extern int     slippage = 3; //the maximum allowed deviation from the requested price for an order
extern int     Profit = 50;
extern int     StopLoss = 100;
extern double  LotSize = 0.10;
extern bool    StpMode = TRUE; //the order will be sent as a Stop Order

int Digitss;
int Stops;
double Points;
double ProfitPerPip;
int pips;

bool Initialized = FALSE;
bool Running = FALSE;
int OrderNumber;
double PositionSize;
double LastBid;
double LastAsk;
color  buyClr = Yellow;
color  sellClr = Green;

//+------------------------------------------------------------------+
//| Utility functions                                                |
//+------------------------------------------------------------------+
#include <stdlib.mqh>
#include <stderror.mqh>
#include <WinUser32.mqh>
//+------------------------------------------------------------------+
//| Calculates a position size                      |
//+------------------------------------------------------------------+
double sizeOfLot()
  {
   int Index;
   double lotSIze = 0.10;
   double Loss = 0;

   for(Index = OrdersHistoryTotal() - 1; Index >= 0; Index--)
     {
      if(OrderSelect(Index, SELECT_BY_POS, MODE_HISTORY) == TRUE)
         continue;
      if((OrderSymbol() == Symbol()) && (OrderMagicNumber() == Magic))
        {
         if(OrderProfit() <= 0)
           {
            Loss = Loss - OrderProfit();  // Add up our previous losses
            lotSIze = 1 + MathRound(0.5 + Loss / (ProfitPerPip * LotSize * Profit));
           }
         else
           {
            break;
           }

        }
     }
   Print("Loss = ", Loss, ", lotSize = ", lotSIze);
   return (LotSize * lotSIze);
  }

//+------------------------------------------------------------------+
//| Place an order                                                  |
//+------------------------------------------------------------------+
int Order(string symbol, int Type, double Entry, double Quantity, double TargetPrice, double StopPrice, string comment="ORDER")
  {
   string TypeStr;
   color  TypeColor;
   int    ErrorCode, Ticket;
   double Price, FillPrice;

   Price = NormalizeDouble(Entry, Digitss);

   switch(Type)
     {
      case OP_BUY:
         TypeStr = "BUY";
         TypeColor = buyClr;
         break;
      case OP_SELL:
         TypeStr = "SELL";
         TypeColor = sellClr;
         break;
      default:
         Print("Unknown order type ", Type);
         break;
     }

   if(StpMode)
     {
      Ticket = OrderSend(symbol, Type, Quantity, Price, slippage, 0, 0, "ORDER", Magic, 0, TypeColor);
     }
   else
     {
      Ticket = OrderSend(symbol, Type, Quantity, Price, slippage, StopPrice, TargetPrice, "ORDER", Magic, 0, TypeColor);
     }
   if(Ticket >= 0)
     {
      Sleep(SLEEP_OK);
      if(OrderSelect(Ticket, SELECT_BY_TICKET) == TRUE)
        {
         FillPrice = OrderOpenPrice();
         if(Entry != FillPrice)
           {
            RefreshRates();
            Print("slippage on order ", Ticket, " - Requested = ",
                  Entry, ", Fill = ", FillPrice, ", Current Bid = ",
                  Bid, ", Current Ask = ", Ask);
           }
         if(StpMode && ((StopPrice > 0) || (TargetPrice > 0)))
           {
            if(OrderModify(Ticket, FillPrice, StopPrice, TargetPrice, 0, TypeColor))
              {
               Sleep(SLEEP_OK);
               return (Ticket);
              }
           }
        }
      else
        {
         ErrorCode = GetLastError();
         Print("Error selecting new order ", Ticket, ": ",
               ErrorDescription(ErrorCode), " (", ErrorCode, ")");
        }
      return (Ticket);
     }

   ErrorCode = GetLastError();
   RefreshRates();
   Print("Error opening ", TypeStr, " order: ", ErrorDescription(ErrorCode),
         " (", ErrorCode, ")", ", Entry = ", Price, ", Target = ",
         TargetPrice, ", Stop = ", StopPrice, ", Current Bid = ", Bid,
         ", Current Ask = ", Ask);
   Sleep(SLEEP_ERR);

   return (-1);
  }

//+------------------------------------------------------------------+
//| Performs system initialisation                                   |
//+------------------------------------------------------------------+
void InitSystem()
  {
   Running = FALSE;

   PositionSize = sizeOfLot();

   RefreshRates();
   LastBid = Bid;
   LastAsk = Ask;

   Initialized = TRUE;
  }

//+------------------------------------------------------------------+
//| Checks for entry to a trade                                      |
//+------------------------------------------------------------------+
int CheckEntry(double Size)
  {
   if(Ask > LastAsk)     //BUY Order
     {
      OrderNumber = Order(Symbol(), OP_BUY, Ask, Size, Ask + (Points * Profit), Bid - (Points * StopLoss));
      if(OrderNumber > 0)
         return(1);
     }
   else
      if(Bid < LastBid)     //SELL Order
        {
         OrderNumber = Order(Symbol(), OP_SELL, Bid, Size, Bid - (Points * Profit), Ask + (Points * StopLoss));
         if(OrderNumber > 0)
            return(1);
        }
   return(0);
  }

//+------------------------------------------------------------------+
//| Checks for exit from a trade                                     |
//+------------------------------------------------------------------+
int CheckExit()
  {
   int ErrorCode;

   if(OrderSelect(OrderNumber, SELECT_BY_TICKET) != TRUE)
     {
      ErrorCode = GetLastError();
      Print("Error selecting order ", OrderNumber, ": ", ErrorDescription(ErrorCode), " (", ErrorCode, ")");
      return(-1);
     }
   else
      if(OrderCloseTime() > 0)
        {
         Print("Order ", OrderNumber, " closed: ", OrderClosePrice(), ", at ", TimeToStr(OrderCloseTime()));
         return(1);
        }
      else
        {
         return(0);
        }
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   if(tickSize == 0.00001 || tickSize == 0.001)
      pips = tickSize*10;
   else
      pips = tickSize;
      
   Digitss = MarketInfo(Symbol(), MODE_DIGITS);
   Points = MarketInfo(Symbol(), MODE_POINT);
   Stops = MarketInfo(Symbol(), MODE_STOPLEVEL);
   ProfitPerPip = 100000 / MathPow(10, Digitss);

   Print("Profit per pip per lot = ", ProfitPerPip, ", Stops = ", Stops, ", Digits = ", Digitss, ", Points = ", DoubleToStr(Points, 5));

   if(!IsDemo() && !IsTesting())
     {
      Print("Initialization Failure");
      return(-1);
     }

   InitSystem();

   Print("Initialized OK");

   return(0);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
   Print("DeInitialized OK");

   return(0);
  }

//+------------------------------------------------------------------+
//| Expert start function                                            |
//| Executed on every tick                                           |
//+------------------------------------------------------------------+
int start()
  {
   if(!Initialized)
     {
      return(-1);
     }
   else
      if(Running)
        {
         if(CheckExit() > 0)
           {
            Initialized = FALSE;
            InitSystem();
           }
        }
      else
        {
         if(CheckEntry(PositionSize) > 0)
           {
            Running = TRUE;
           }
        }
   return(0);
  }

//+------------------------------------------------------------------+

