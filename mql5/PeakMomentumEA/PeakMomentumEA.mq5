//+------------------------------------------------------------------+
//|                                              PeakMomentumEA.mq5  |
//|  Reconstruction of the observable "peak momentum" scalping       |
//|  behaviour (micro-momentum breakout with dynamic stop orders).   |
//|                                                                  |
//|  THIS IS NOT THE ORIGINAL PROPRIETARY ALGORITHM.                 |
//|  It is a technically defensible reconstruction built from        |
//|  externally observable behaviour only. Every uncertain component |
//|  is exposed as a configurable input.                             |
//+------------------------------------------------------------------+
#property copyright "Peak Momentum reconstruction - reverse engineered from observable behaviour"
#property link      ""
#property version   "1.00"
#property description "Micro-momentum scalper: tick-based momentum engine -> dynamically trailed"
#property description "BUY STOP / SELL STOP -> fixed TP (price units) + peak-momentum-decay trailing stop."
#property description "Reconstruction only. Not the original proprietary algorithm. Test on demo first."

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+
enum StrategyState
  {
   STATE_IDLE        = 0,  // Idle
   STATE_WAITING     = 1,  // Waiting for momentum
   STATE_PENDING_BUY = 2,  // Buy stop working
   STATE_PENDING_SELL= 3,  // Sell stop working
   STATE_BUY_ACTIVE  = 4,  // Long position active
   STATE_SELL_ACTIVE = 5,  // Short position active
   STATE_COOLDOWN    = 6,  // Cooldown after a close
   STATE_HALTED      = 7   // Risk layer halted new entries
  };

enum ENUM_MOMENTUM_DIR
  {
   MOM_NEUTRAL = 0,
   MOM_BUY     = 1,
   MOM_SELL    = -1
  };

enum ENUM_LOT_MODE
  {
   LOT_MODE_FIXED       = 0, // FIXED
   LOT_MODE_RISK_PERCENT= 1  // RISK_PERCENT
  };

enum ENUM_PM_EXIT
  {
   PM_EXIT_NONE      = 0,
   PM_EXIT_TP        = 1,
   PM_EXIT_SL        = 2,
   PM_EXIT_TRAIL     = 3,
   PM_EXIT_BREAKEVEN = 4,
   PM_EXIT_REVERSAL  = 5,
   PM_EXIT_DURATION  = 6,
   PM_EXIT_EMERGENCY = 7,
   PM_EXIT_EXTERNAL  = 8
  };

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "=== GENERAL ==="
input string           TradeSymbol                 = "";            // Symbol ("" = chart symbol)
input ENUM_TIMEFRAMES  SignalTimeframe             = PERIOD_M1;     // Reference timeframe (informational)
input long             MagicNumber                 = 83001;         // Magic number
input bool             EnableTrading               = true;          // Master trading switch
input bool             DebugMode                   = true;          // Verbose [PM] logging
input int              TimerMilliseconds           = 200;           // Housekeeping timer (ms)

input group "=== POINT SCALING ==="
input bool             NormalizePointInputs        = true;          // Scale point inputs to a reference point size
input double           ReferencePointSize          = 0.01;          // Point size the defaults were designed for

input group "=== MOMENTUM ENGINE ==="
input int              MomentumLookbackTicks       = 10;            // Lookback (ticks)
input int              MomentumLookbackMilliseconds= 1000;          // Lookback (milliseconds)
input double           MomentumThreshold           = 0.35;          // |score| needed for a direction
input double           MomentumAccelerationThreshold=0.0;           // Normalised acceleration gate
input double           MinimumPriceVelocity        = 15.0;          // Min |velocity| (points/second)
input double           MomentumSmoothing           = 0.35;          // EMA factor 0<x<=1 (1 = raw)
input double           VelocityWeight              = 0.50;          // Weight: velocity
input double           AccelerationWeight          = 0.25;          // Weight: acceleration
input double           BreakoutWeight              = 0.25;          // Weight: micro-breakout
input double           VelocityNormalization       = 60.0;          // points/sec mapped to 1.0
input double           AccelerationNormalization   = 120.0;         // points/sec^2 mapped to 1.0
input int              ConfirmationTicks           = 3;             // Consecutive qualifying ticks

input group "=== PENDING ORDER (MICRO BREAKOUT) ==="
input double           PendingDistancePoints       = 30.0;          // Offset beyond market (points)
input double           MinimumPendingDistancePoints= 10.0;          // Lower clamp (points)
input double           MaximumPendingDistancePoints= 150.0;         // Upper clamp (points)
input double           PendingModifyThresholdPoints= 5.0;           // Min change before modifying
input int              PendingTimeoutSeconds       = 20;            // Max pending lifetime (0 = off)
input bool             CancelPendingOnMomentumLoss = true;          // Delete when momentum fades
input bool             CancelPendingOnDirectionFlip= true;          // Delete when momentum flips
input bool             UseDistinctPendingComment   = false;         // Use "peak momentum pending" on pendings

input group "=== TAKE PROFIT / INITIAL PROTECTION ==="
input double           TakeProfitPriceUnits        = 10.0;          // Fixed TP in PRICE UNITS (not points)
input double           InitialStopDistancePoints   = 100.0;         // Initial stop (points)

input group "=== PEAK MOMENTUM TRAILING ==="
input bool             EnableTrailing              = true;          // Enable trailing engine
input double           TrailingBaseDistancePoints  = 45.0;          // Base trailing distance (points)
input double           TrailingMinimumDistancePoints=8.0;           // Minimum trailing distance (points)
input double           TrailingMaximumDistancePoints=120.0;         // Maximum trailing distance (points)
input double           MomentumTrailFactor         = 25.0;          // Points removed per 1.0 of decay
input double           ExpansionRoomMultiplier     = 1.5;           // Extra room while momentum expands
input double           SLModifyThresholdPoints     = 3.0;           // Min SL improvement before modify

input group "=== PROFIT PROTECTION ==="
input double           BreakEvenTriggerPoints      = 60.0;          // Profit needed to protect entry
input double           BreakEvenLockPoints         = 2.0;           // Locked points at breakeven
input double           LockProfitTriggerPoints     = 150.0;         // Profit needed for partial lock
input double           LockProfitRatio             = 0.50;          // Fraction of open profit locked
input double           StrongMomentumTriggerPoints = 300.0;         // Profit where a strong run gets room
input double           StrongMomentumScore         = 0.60;          // Directional score = "strong run"

input group "=== MOMENTUM EXIT ==="
input bool             CloseOnMomentumReversal     = true;          // Close at market on reversal
input double           ReversalExitScore           = 0.45;          // Opposite score that triggers exit
input int              ReversalConfirmationTicks   = 2;             // Consecutive opposite readings
input int              MaxTradeDurationSeconds     = 60;            // Max holding time (0 = off)
input bool             CloseOnMaxDuration          = true;          // Close at market when exceeded
input bool             AllowImmediateReverse       = false;         // Reverse an open position instantly

input group "=== EXECUTION FILTERS ==="
input double           MaxSpreadPoints             = 60.0;          // Max spread for new entries (points)
input double           SpreadMultiplier            = 3.0;           // Emergency spread = Max * multiplier
input bool             EnableSpreadEmergencyExit   = false;         // Close position on spread explosion
input int              MaxSlippagePoints           = 20;            // Deviation for market operations
input double           CooldownSeconds             = 1.0;           // Pause after a position closes

input group "=== LOT SIZE ==="
input ENUM_LOT_MODE    LotMode                     = LOT_MODE_FIXED;// Lot mode
input double           FixedLot                    = 0.10;          // Fixed lot
input double           RiskPercent                 = 0.25;          // Risk % (RISK_PERCENT mode)

input group "=== SAFETY LIMITS (RISK LAYER, NOT PART OF THE STRATEGY) ==="
input int              MaxOpenPositions            = 1;             // Max simultaneous EA positions
input int              MaxPendingOrders            = 1;             // Max simultaneous EA pendings
input bool             EnableDailyLossLimit        = true;          // Enable daily loss lock
input double           DailyLossLimitPercent       = 2.0;           // Daily loss limit (% of start equity)
input double           MaxDailyLossMoney           = 0.0;           // Daily loss limit (money, 0 = off)
input bool             EnableDailyProfitTarget     = false;         // Enable daily profit lock
input double           DailyProfitTargetMoney      = 0.0;           // Daily profit target (money)
input int              MaxConsecutiveLosses        = 0;             // Stop after N losses (0 = off)
input double           MaxEquityDrawdownPercent    = 5.0;           // Equity DD vs day start (0 = off)
input bool             CloseAllOnHalt              = false;         // Close open trade when halted

input group "=== DASHBOARD / VISUALS ==="
input bool             ShowDashboard               = true;          // Show dashboard
input bool             ShowMomentumScore           = true;          // Show momentum score
input bool             ShowVelocity                = true;          // Show velocity
input bool             ShowAcceleration            = true;          // Show acceleration
input bool             ShowPendingPrice            = true;          // Show pending price + line
input bool             ShowTrailingDistance        = true;          // Show trailing distance
input bool             ShowState                   = true;          // Show state
input bool             ShowTradeMarkers            = true;          // Draw entry arrows / levels
input int              MaxTradeMarkers             = 60;            // Max arrows kept on chart
input int              DashboardX                  = 12;            // Dashboard X
input int              DashboardY                  = 22;            // Dashboard Y
input color            DashboardColor              = clrGainsboro;  // Dashboard text colour

input group "=== STATISTICS ==="
input bool             EnableStatistics            = true;          // Collect statistics
input bool             PrintStatsOnDeinit          = true;          // Print report when EA stops
input int              StatsPrintIntervalSeconds   = 0;             // Periodic report (0 = off)

//+------------------------------------------------------------------+
//| Global logging helpers                                           |
//+------------------------------------------------------------------+
void PmLog(const string msg)
  {
   if(DebugMode)
      Print("[PM] ", msg);
  }

void PmLogAlways(const string msg)
  {
   Print("[PM] ", msg);
  }

string StateToString(const StrategyState s)
  {
   switch(s)
     {
      case STATE_IDLE:         return "IDLE";
      case STATE_WAITING:      return "WAITING_FOR_MOMENTUM";
      case STATE_PENDING_BUY:  return "PENDING_BUY";
      case STATE_PENDING_SELL: return "PENDING_SELL";
      case STATE_BUY_ACTIVE:   return "BUY_ACTIVE";
      case STATE_SELL_ACTIVE:  return "SELL_ACTIVE";
      case STATE_COOLDOWN:     return "COOLDOWN";
      case STATE_HALTED:       return "HALTED";
     }
   return "UNKNOWN";
  }

string ExitToString(const ENUM_PM_EXIT e)
  {
   switch(e)
     {
      case PM_EXIT_TP:        return "TAKE_PROFIT";
      case PM_EXIT_SL:        return "STOP_LOSS";
      case PM_EXIT_TRAIL:     return "TRAILING_STOP";
      case PM_EXIT_BREAKEVEN: return "BREAKEVEN_STOP";
      case PM_EXIT_REVERSAL:  return "MOMENTUM_REVERSAL";
      case PM_EXIT_DURATION:  return "MAX_DURATION";
      case PM_EXIT_EMERGENCY: return "EMERGENCY";
      case PM_EXIT_EXTERNAL:  return "EXTERNAL";
     }
   return "NONE";
  }

double PmClamp(const double v, const double lo, const double hi)
  {
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
  }

//+------------------------------------------------------------------+
//| Symbol context - all broker specific conversions live here       |
//+------------------------------------------------------------------+
class CSymbolCtx
  {
public:
   string            name;
   int               digits;
   double            point;
   double            tickSize;
   double            tickValue;
   double            contractSize;
   double            volMin;
   double            volMax;
   double            volStep;
   int               volDigits;
   int               stopsLevel;    // in broker points
   int               freezeLevel;   // in broker points
   double            pointScale;    // multiplier applied to every point based input

                     CSymbolCtx(void)
     {
      name         = "";
      digits       = 2;
      point        = 0.01;
      tickSize     = 0.01;
      tickValue    = 1.0;
      contractSize = 1.0;
      volMin       = 0.01;
      volMax       = 100.0;
      volStep      = 0.01;
      volDigits    = 2;
      stopsLevel   = 0;
      freezeLevel  = 0;
      pointScale   = 1.0;
     }

   bool              Init(const string sym)
     {
      name = sym;
      if(!SymbolSelect(name, true))
        {
         PmLogAlways("ERROR: symbol " + name + " could not be selected in Market Watch");
         return false;
        }
      digits       = (int)SymbolInfoInteger(name, SYMBOL_DIGITS);
      point        = SymbolInfoDouble(name, SYMBOL_POINT);
      tickSize     = SymbolInfoDouble(name, SYMBOL_TRADE_TICK_SIZE);
      tickValue    = SymbolInfoDouble(name, SYMBOL_TRADE_TICK_VALUE);
      contractSize = SymbolInfoDouble(name, SYMBOL_TRADE_CONTRACT_SIZE);
      volMin       = SymbolInfoDouble(name, SYMBOL_VOLUME_MIN);
      volMax       = SymbolInfoDouble(name, SYMBOL_VOLUME_MAX);
      volStep      = SymbolInfoDouble(name, SYMBOL_VOLUME_STEP);

      if(point    <= 0.0) point    = MathPow(10.0, -digits);
      if(tickSize <= 0.0) tickSize = point;
      if(volStep  <= 0.0) volStep  = 0.01;
      if(volMin   <= 0.0) volMin   = volStep;
      if(volMax   <= 0.0) volMax   = 100.0;

      volDigits = (int)MathMax(0.0, MathCeil(-MathLog10(volStep) - 0.0000001));

      pointScale = 1.0;
      if(NormalizePointInputs && ReferencePointSize > 0.0 && point > 0.0)
         pointScale = ReferencePointSize / point;

      Refresh();
      return true;
     }

   void              Refresh(void)
     {
      stopsLevel  = (int)SymbolInfoInteger(name, SYMBOL_TRADE_STOPS_LEVEL);
      freezeLevel = (int)SymbolInfoInteger(name, SYMBOL_TRADE_FREEZE_LEVEL);
      if(stopsLevel  < 0) stopsLevel  = 0;
      if(freezeLevel < 0) freezeLevel = 0;
     }

   //--- scaled points (an input of 30 always means the same PRICE distance)
   double            Pts(const double pts)      const { return pts * pointScale; }
   //--- scaled points converted to a price distance
   double            PtsPrice(const double pts) const { return pts * pointScale * point; }
   //--- price distance converted back to scaled input points
   double            PriceToPts(const double pr)const
     {
      if(point <= 0.0 || pointScale <= 0.0) return 0.0;
      return pr / point / pointScale;
     }
   double            StopsPrice(void)  const { return stopsLevel  * point; }
   double            FreezePrice(void) const { return freezeLevel * point; }

   double            NormalizePrice(const double price) const
     {
      double ts = (tickSize > 0.0 ? tickSize : point);
      if(ts <= 0.0) return NormalizeDouble(price, digits);
      return NormalizeDouble(MathRound(price / ts) * ts, digits);
     }

   double            NormalizeVolume(const double vol) const
     {
      double v = vol;
      if(volStep > 0.0)
         v = MathRound(v / volStep) * volStep;
      if(v < volMin) v = volMin;
      if(v > volMax) v = volMax;
      return NormalizeDouble(v, volDigits);
     }

   double            Bid(void) const { return SymbolInfoDouble(name, SYMBOL_BID); }
   double            Ask(void) const { return SymbolInfoDouble(name, SYMBOL_ASK); }

   //--- raw broker points, unaffected by the scaling layer
   double            SpreadPointsRaw(void) const
     {
      double a = Ask(), b = Bid();
      if(point <= 0.0) return 0.0;
      return (a - b) / point;
     }
   //--- spread expressed in the same scaled units as the inputs
   double            SpreadPointsScaled(void) const
     {
      if(pointScale <= 0.0) return 0.0;
      return SpreadPointsRaw() / pointScale;
     }
  };

//+------------------------------------------------------------------+
//| Tick sample used by the momentum engine                          |
//+------------------------------------------------------------------+
struct PmTickSample
  {
   long              ms;
   double            price;
  };

//+------------------------------------------------------------------+
//| Momentum engine - pure tick based, no candle dependency          |
//+------------------------------------------------------------------+
class CMomentumEngine
  {
private:
   CSymbolCtx       *m_sym;
   PmTickSample      m_buf[];
   int               m_size;
   int               m_head;      // index of the newest sample
   int               m_count;

   double            m_velocity;      // smoothed, points/second (scaled units)
   double            m_prevVelocity;
   double            m_acceleration;  // smoothed, points/second^2 (scaled units)
   double            m_score;
   double            m_normVel;
   double            m_normAcc;
   double            m_breakout;
   long              m_lastComputeMs;
   bool              m_ready;

   int               m_confirmBuy;
   int               m_confirmSell;
   ENUM_MOMENTUM_DIR m_direction;      // confirmed direction
   ENUM_MOMENTUM_DIR m_rawDirection;   // unconfirmed direction

   int               Index(const int back) const
     {
      // back = 0 -> newest
      int idx = m_head - back;
      while(idx < 0) idx += m_size;
      return idx;
     }

public:
                     CMomentumEngine(void)
     {
      m_sym           = NULL;
      m_size          = 0;
      m_head          = -1;
      m_count         = 0;
      m_velocity      = 0.0;
      m_prevVelocity  = 0.0;
      m_acceleration  = 0.0;
      m_score         = 0.0;
      m_normVel       = 0.0;
      m_normAcc       = 0.0;
      m_breakout      = 0.0;
      m_lastComputeMs = 0;
      m_ready         = false;
      m_confirmBuy    = 0;
      m_confirmSell   = 0;
      m_direction     = MOM_NEUTRAL;
      m_rawDirection  = MOM_NEUTRAL;
     }

   bool              Init(CSymbolCtx *sym)
     {
      m_sym  = sym;
      m_size = (int)MathMax(64, MathMin(4096, MomentumLookbackTicks * 8 + 128));
      if(ArrayResize(m_buf, m_size) != m_size)
        {
         PmLogAlways("ERROR: momentum buffer allocation failed");
         return false;
        }
      for(int i = 0; i < m_size; i++)
        {
         m_buf[i].ms    = 0;
         m_buf[i].price = 0.0;
        }
      m_head  = -1;
      m_count = 0;
      return true;
     }

   void              Reset(void)
     {
      m_head          = -1;
      m_count         = 0;
      m_ready         = false;
      m_velocity      = 0.0;
      m_prevVelocity  = 0.0;
      m_acceleration  = 0.0;
      m_score         = 0.0;
      m_confirmBuy    = 0;
      m_confirmSell   = 0;
      m_direction     = MOM_NEUTRAL;
      m_rawDirection  = MOM_NEUTRAL;
      m_lastComputeMs = 0;
     }

   //--- accessors
   bool              IsReady(void)        const { return m_ready; }
   double            Score(void)          const { return m_score; }
   double            Velocity(void)       const { return m_velocity; }
   double            Acceleration(void)   const { return m_acceleration; }
   double            NormVelocity(void)   const { return m_normVel; }
   double            NormAcceleration(void)const{ return m_normAcc; }
   double            Breakout(void)       const { return m_breakout; }
   ENUM_MOMENTUM_DIR Direction(void)      const { return m_direction; }
   ENUM_MOMENTUM_DIR RawDirection(void)   const { return m_rawDirection; }
   int               ConfirmCount(void)   const { return (int)MathMax(m_confirmBuy, m_confirmSell); }

   //--- feed one tick and recompute everything
   void              Update(const MqlTick &tick)
     {
      if(m_sym == NULL || m_size <= 0) return;

      double mid = (tick.bid + tick.ask) * 0.5;
      if(mid <= 0.0) return;

      long ms = (long)tick.time_msc;
      if(ms <= 0) ms = (long)GetTickCount64();

      //--- push. Ticks that are not strictly newer than the last stored sample are
      //--- dropped: they carry no time information and would only pollute the
      //--- buffer (this also makes the timer-driven Process() call harmless).
      if(m_count > 0)
        {
         int last = Index(0);
         if(ms <= m_buf[last].ms)
            return;
        }
      m_head = (m_head + 1) % m_size;
      m_buf[m_head].ms    = ms;
      m_buf[m_head].price = mid;
      if(m_count < m_size) m_count++;

      //--- locate the reference sample: at least N ticks AND M milliseconds back
      int refBack = -1;
      for(int back = 1; back < m_count; back++)
        {
         int  idx  = Index(back);
         long age  = ms - m_buf[idx].ms;
         if(back >= MomentumLookbackTicks && age >= (long)MomentumLookbackMilliseconds)
           {
            refBack = back;
            break;
           }
        }

      if(refBack < 0)
        {
         m_ready        = false;
         m_direction    = MOM_NEUTRAL;
         m_rawDirection = MOM_NEUTRAL;
         m_confirmBuy   = 0;
         m_confirmSell  = 0;
         return;
        }

      int    refIdx  = Index(refBack);
      double delta   = mid - m_buf[refIdx].price;
      double elapsed = (double)(ms - m_buf[refIdx].ms) / 1000.0;
      if(elapsed <= 0.0)
        {
         m_ready        = false;
         m_direction    = MOM_NEUTRAL;
         m_rawDirection = MOM_NEUTRAL;
         m_confirmBuy   = 0;
         m_confirmSell  = 0;
         return;
        }

      //--- velocity in scaled points per second
      double rawVel = (m_sym.PriceToPts(delta)) / elapsed;
      double alpha  = PmClamp(MomentumSmoothing, 0.01, 1.0);
      if(!m_ready)
         m_velocity = rawVel;
      else
         m_velocity = m_velocity + alpha * (rawVel - m_velocity);

      //--- acceleration
      double dt = (m_lastComputeMs > 0 ? (double)(ms - m_lastComputeMs) / 1000.0 : 0.0);
      if(dt < 0.001) dt = 0.001;
      double rawAcc = (m_ready ? (m_velocity - m_prevVelocity) / dt : 0.0);
      if(!m_ready)
         m_acceleration = 0.0;
      else
         m_acceleration = m_acceleration + alpha * (rawAcc - m_acceleration);

      m_prevVelocity  = m_velocity;
      m_lastComputeMs = ms;

      //--- micro breakout strength over the lookback window, current tick excluded
      double hi = -DBL_MAX, lo = DBL_MAX;
      for(int back = 1; back <= refBack; back++)
        {
         int idx = Index(back);
         double p = m_buf[idx].price;
         if(p > hi) hi = p;
         if(p < lo) lo = p;
        }
      m_breakout = 0.0;
      if(hi > lo)
        {
         double midRange = (hi + lo) * 0.5;
         double halfSpan = (hi - lo) * 0.5;
         if(halfSpan > 0.0)
            m_breakout = PmClamp((mid - midRange) / halfSpan, -1.0, 1.0);
        }

      //--- normalisation
      double vn = (VelocityNormalization     > 0.0 ? VelocityNormalization     : 1.0);
      double an = (AccelerationNormalization > 0.0 ? AccelerationNormalization : 1.0);
      m_normVel = PmClamp(m_velocity     / vn, -1.0, 1.0);
      m_normAcc = PmClamp(m_acceleration / an, -1.0, 1.0);

      double wSum = VelocityWeight + AccelerationWeight + BreakoutWeight;
      if(wSum <= 0.0) wSum = 1.0;
      m_score = (m_normVel  * VelocityWeight
                 + m_normAcc  * AccelerationWeight
                 + m_breakout * BreakoutWeight) / wSum;
      m_score = PmClamp(m_score, -1.0, 1.0);

      m_ready = true;

      //--- direction gates
      bool buyGate  = (m_score >=  MomentumThreshold)
                      && (m_velocity >=  MinimumPriceVelocity)
                      && (m_normAcc  >=  MomentumAccelerationThreshold);
      bool sellGate = (m_score <= -MomentumThreshold)
                      && (m_velocity <= -MinimumPriceVelocity)
                      && (m_normAcc  <= -MomentumAccelerationThreshold);

      if(buyGate)
        {
         m_confirmBuy++;
         m_confirmSell  = 0;
         m_rawDirection = MOM_BUY;
        }
      else if(sellGate)
        {
         m_confirmSell++;
         m_confirmBuy   = 0;
         m_rawDirection = MOM_SELL;
        }
      else
        {
         m_confirmBuy   = 0;
         m_confirmSell  = 0;
         m_rawDirection = MOM_NEUTRAL;
        }

      int need = (int)MathMax(1, ConfirmationTicks);
      if(m_confirmBuy  >= need)      m_direction = MOM_BUY;
      else if(m_confirmSell >= need) m_direction = MOM_SELL;
      else                           m_direction = MOM_NEUTRAL;
     }
  };

//+------------------------------------------------------------------+
//| Order manager - every broker interaction is validated here       |
//+------------------------------------------------------------------+
class COrderManager
  {
private:
   CTrade            m_trade;
   CSymbolCtx       *m_sym;
   ulong             m_magic;

   void              LogResult(const string what, const bool ok)
     {
      uint   rc     = m_trade.ResultRetcode();
      string rcDesc = m_trade.ResultRetcodeDescription();
      if(ok)
        {
         PmLog(StringFormat("%s OK  retcode=%u (%s) order=%I64u deal=%I64u price=%s vol=%.2f",
                            what, rc, rcDesc, m_trade.ResultOrder(), m_trade.ResultDeal(),
                            DoubleToString(m_trade.ResultPrice(), m_sym.digits), m_trade.ResultVolume()));
        }
      else
        {
         PmLogAlways(StringFormat("%s FAILED retcode=%u (%s) lastError=%d price=%s vol=%.2f",
                                  what, rc, rcDesc, GetLastError(),
                                  DoubleToString(m_trade.ResultPrice(), m_sym.digits), m_trade.ResultVolume()));
        }
     }

   //--- MaxSlippagePoints is given in the same scaled units as every other point
   //--- input, but the terminal expects raw broker points here.
   ulong             DeviationPoints(void)
     {
      double d = m_sym.Pts((double)MathMax(0, MaxSlippagePoints));
      return (ulong)MathMax(0.0, MathRound(d));
     }

public:
                     COrderManager(void) { m_sym = NULL; m_magic = 0; }

   void              Init(CSymbolCtx *sym, const ulong magic)
     {
      m_sym   = sym;
      m_magic = magic;
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(DeviationPoints());
      m_trade.SetAsyncMode(false);
      m_trade.SetTypeFillingBySymbol(sym.name);
      m_trade.LogLevel(DebugMode ? LOG_LEVEL_ERRORS : LOG_LEVEL_NO);
     }

   uint              LastRetcode(void)  { return m_trade.ResultRetcode(); }
   double            LastPrice(void)    { return m_trade.ResultPrice();   }
   ulong             LastOrder(void)    { return m_trade.ResultOrder();   }

   //--- discovery -------------------------------------------------
   int               FindStrategyPositions(ulong &tickets[])
     {
      ArrayResize(tickets, 0);
      int total = PositionsTotal();
      for(int i = total - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != (long)m_magic) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_sym.name)    continue;
         int n = ArraySize(tickets);
         ArrayResize(tickets, n + 1);
         tickets[n] = t;
        }
      return ArraySize(tickets);
     }

   int               FindStrategyOrders(ulong &tickets[])
     {
      ArrayResize(tickets, 0);
      int total = OrdersTotal();
      for(int i = total - 1; i >= 0; i--)
        {
         ulong t = OrderGetTicket(i);
         if(t == 0) continue;
         if(OrderGetInteger(ORDER_MAGIC) != (long)m_magic) continue;
         if(OrderGetString(ORDER_SYMBOL) != m_sym.name)    continue;
         long type = OrderGetInteger(ORDER_TYPE);
         if(type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP) continue;
         int n = ArraySize(tickets);
         ArrayResize(tickets, n + 1);
         tickets[n] = t;
        }
      return ArraySize(tickets);
     }

   //--- placement -------------------------------------------------
   bool              PlaceStopOrder(const bool isBuy, const double volume, const double price,
                                    const double sl, const double tp, const string comment, ulong &ticket)
     {
      ticket = 0;
      ENUM_ORDER_TYPE type = (isBuy ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP);
      double p  = m_sym.NormalizePrice(price);
      double s  = (sl > 0.0 ? m_sym.NormalizePrice(sl) : 0.0);
      double t  = (tp > 0.0 ? m_sym.NormalizePrice(tp) : 0.0);
      double v  = m_sym.NormalizeVolume(volume);

      bool ok = m_trade.OrderOpen(m_sym.name, type, v, 0.0, p, s, t,
                                  ORDER_TIME_GTC, 0, comment);
      LogResult(StringFormat("%s STOP place @ %s (sl=%s tp=%s)",
                             (isBuy ? "BUY" : "SELL"),
                             DoubleToString(p, m_sym.digits),
                             DoubleToString(s, m_sym.digits),
                             DoubleToString(t, m_sym.digits)), ok);
      if(!ok) return false;

      uint rc = m_trade.ResultRetcode();
      if(rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_PLACED)
        {
         PmLogAlways("Pending order rejected, retcode " + IntegerToString(rc));
         return false;
        }
      ticket = m_trade.ResultOrder();
      if(ticket == 0)
        {
         PmLogAlways("Pending order returned ticket 0 - state will be rebuilt from the terminal");
         return false;
        }
      return true;
     }

   bool              ModifyPending(const ulong ticket, const double price, const double sl, const double tp)
     {
      double p = m_sym.NormalizePrice(price);
      double s = (sl > 0.0 ? m_sym.NormalizePrice(sl) : 0.0);
      double t = (tp > 0.0 ? m_sym.NormalizePrice(tp) : 0.0);
      bool ok  = m_trade.OrderModify(ticket, p, s, t, ORDER_TIME_GTC, 0, 0.0);
      LogResult(StringFormat("Pending #%I64u modify -> %s", ticket, DoubleToString(p, m_sym.digits)), ok);
      return ok;
     }

   bool              DeletePending(const ulong ticket)
     {
      bool ok = m_trade.OrderDelete(ticket);
      LogResult(StringFormat("Pending #%I64u delete", ticket), ok);
      return ok;
     }

   bool              ModifyStopLoss(const ulong ticket, const double sl, const double tp)
     {
      double s = (sl > 0.0 ? m_sym.NormalizePrice(sl) : 0.0);
      double t = (tp > 0.0 ? m_sym.NormalizePrice(tp) : 0.0);
      bool ok  = m_trade.PositionModify(ticket, s, t);
      LogResult(StringFormat("Position #%I64u modify sl=%s tp=%s",
                             ticket, DoubleToString(s, m_sym.digits), DoubleToString(t, m_sym.digits)), ok);
      return ok;
     }

   bool              ClosePosition(const ulong ticket)
     {
      bool ok = m_trade.PositionClose(ticket, DeviationPoints());
      LogResult(StringFormat("Position #%I64u close", ticket), ok);
      return ok;
     }
  };

//+------------------------------------------------------------------+
//| Statistics manager                                               |
//+------------------------------------------------------------------+
class CStatisticsManager
  {
private:
   CSymbolCtx       *m_sym;
   ulong             m_magic;
   datetime          m_from;

   int               m_total, m_buys, m_sells, m_wins, m_losses;
   double            m_grossProfit, m_grossLoss;
   double            m_largestWin, m_largestLoss;
   double            m_maxDrawdown, m_peakEquityCurve, m_equityCurve;
   int               m_maxConsecLosses, m_curConsecLosses;
   double            m_totalDurationSec;
   double            m_netProfit;

public:
   int               exitTP;
   int               exitTrail;
   int               exitBreakeven;
   int               exitSL;
   int               exitReversal;
   int               exitDuration;
   int               exitEmergency;
   int               exitExternal;

                     CStatisticsManager(void)
     {
      m_sym = NULL; m_magic = 0; m_from = 0;
      ResetAll();
     }

   void              ResetAll(void)
     {
      m_total = 0; m_buys = 0; m_sells = 0; m_wins = 0; m_losses = 0;
      m_grossProfit = 0.0; m_grossLoss = 0.0;
      m_largestWin = 0.0; m_largestLoss = 0.0;
      m_maxDrawdown = 0.0; m_peakEquityCurve = 0.0; m_equityCurve = 0.0;
      m_maxConsecLosses = 0; m_curConsecLosses = 0;
      m_totalDurationSec = 0.0; m_netProfit = 0.0;
      exitTP = 0; exitTrail = 0; exitBreakeven = 0; exitSL = 0;
      exitReversal = 0; exitDuration = 0; exitEmergency = 0; exitExternal = 0;
     }

   void              Init(CSymbolCtx *sym, const ulong magic, const datetime from)
     {
      m_sym   = sym;
      m_magic = magic;
      m_from  = from;
     }

   int               CurrentConsecutiveLosses(void) const { return m_curConsecLosses; }

   //--- cheap incremental update, used on every close so the hot path never
   //--- has to walk the whole trade history (that only happens in Report()).
   void              RegisterClosedTrade(const double profit)
     {
      if(profit >= 0.0)
         m_curConsecLosses = 0;
      else
        {
         m_curConsecLosses++;
         if(m_curConsecLosses > m_maxConsecLosses) m_maxConsecLosses = m_curConsecLosses;
        }
     }
   double            NetProfit(void)                const { return m_netProfit; }
   int               TotalTrades(void)              const { return m_total; }

   //--- rebuild everything from the terminal history
   void              Rebuild(void)
     {
      int keepTP = exitTP, keepTrail = exitTrail, keepBE = exitBreakeven, keepSL = exitSL;
      int keepRev = exitReversal, keepDur = exitDuration, keepEmg = exitEmergency, keepExt = exitExternal;
      ResetAll();
      exitTP = keepTP; exitTrail = keepTrail; exitBreakeven = keepBE; exitSL = keepSL;
      exitReversal = keepRev; exitDuration = keepDur; exitEmergency = keepEmg; exitExternal = keepExt;

      if(m_sym == NULL) return;
      if(!HistorySelect(m_from, TimeCurrent() + 86400))
         return;

      long   openIds[];
      long   openTimes[];
      ArrayResize(openIds, 0);
      ArrayResize(openTimes, 0);

      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong dt = HistoryDealGetTicket(i);
         if(dt == 0) continue;
         if(HistoryDealGetInteger(dt, DEAL_MAGIC) != (long)m_magic) continue;
         if(HistoryDealGetString(dt, DEAL_SYMBOL) != m_sym.name)    continue;

         long entry  = HistoryDealGetInteger(dt, DEAL_ENTRY);
         long posId  = HistoryDealGetInteger(dt, DEAL_POSITION_ID);
         long dtime  = HistoryDealGetInteger(dt, DEAL_TIME);
         long dtype  = HistoryDealGetInteger(dt, DEAL_TYPE);

         if(entry == DEAL_ENTRY_IN)
           {
            int n = ArraySize(openIds);
            ArrayResize(openIds,   n + 1);
            ArrayResize(openTimes, n + 1);
            openIds[n]   = posId;
            openTimes[n] = dtime;
            if(dtype == DEAL_TYPE_BUY) m_buys++;
            else                       m_sells++;
           }
         else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
           {
            double profit = HistoryDealGetDouble(dt, DEAL_PROFIT)
                            + HistoryDealGetDouble(dt, DEAL_SWAP)
                            + HistoryDealGetDouble(dt, DEAL_COMMISSION);

            long tIn = 0;
            int  pos = -1;
            for(int k = ArraySize(openIds) - 1; k >= 0; k--)
               if(openIds[k] == posId) { pos = k; break; }
            if(pos >= 0)
              {
               tIn = openTimes[pos];
               int last = ArraySize(openIds) - 1;
               openIds[pos]   = openIds[last];
               openTimes[pos] = openTimes[last];
               ArrayResize(openIds,   last);
               ArrayResize(openTimes, last);
              }

            m_total++;
            m_netProfit += profit;
            if(tIn > 0 && dtime >= tIn)
               m_totalDurationSec += (double)(dtime - tIn);

            if(profit >= 0.0)
              {
               m_wins++;
               m_grossProfit += profit;
               if(profit > m_largestWin) m_largestWin = profit;
               m_curConsecLosses = 0;
              }
            else
              {
               m_losses++;
               m_grossLoss += MathAbs(profit);
               if(profit < m_largestLoss) m_largestLoss = profit;
               m_curConsecLosses++;
               if(m_curConsecLosses > m_maxConsecLosses) m_maxConsecLosses = m_curConsecLosses;
              }

            m_equityCurve += profit;
            if(m_equityCurve > m_peakEquityCurve) m_peakEquityCurve = m_equityCurve;
            double dd = m_peakEquityCurve - m_equityCurve;
            if(dd > m_maxDrawdown) m_maxDrawdown = dd;
           }
        }
     }

   double            WinRate(void)      const { return (m_total > 0 ? (double)m_wins / m_total : 0.0); }
   double            AverageWin(void)   const { return (m_wins   > 0 ? m_grossProfit / m_wins   : 0.0); }
   double            AverageLoss(void)  const { return (m_losses > 0 ? m_grossLoss   / m_losses : 0.0); }
   double            ProfitFactor(void) const { return (m_grossLoss > 0.0 ? m_grossProfit / m_grossLoss : (m_grossProfit > 0.0 ? DBL_MAX : 0.0)); }
   double            Expectancy(void)   const
     {
      if(m_total <= 0) return 0.0;
      double wr = WinRate();
      return wr * AverageWin() - (1.0 - wr) * AverageLoss();
     }
   double            RecoveryFactor(void) const { return (m_maxDrawdown > 0.0 ? m_netProfit / m_maxDrawdown : 0.0); }
   double            MaxDrawdown(void)    const { return m_maxDrawdown; }
   double            AvgDuration(void)    const { return (m_total > 0 ? m_totalDurationSec / m_total : 0.0); }

   string            Report(void)
     {
      Rebuild();
      double pf = ProfitFactor();
      string pfs = (pf == DBL_MAX ? "inf" : DoubleToString(pf, 3));
      string s = "\n===================== PEAK MOMENTUM STATISTICS =====================\n";
      s += StringFormat("Symbol / Magic          : %s / %I64u\n", m_sym.name, m_magic);
      s += StringFormat("Total Trades            : %d\n",   m_total);
      s += StringFormat("BUY / SELL Trades       : %d / %d\n", m_buys, m_sells);
      s += StringFormat("Winning / Losing        : %d / %d\n", m_wins, m_losses);
      s += StringFormat("Win Rate                : %.2f %%\n", WinRate() * 100.0);
      s += StringFormat("Average Win             : %.2f\n",  AverageWin());
      s += StringFormat("Average Loss            : %.2f\n",  AverageLoss());
      s += StringFormat("Largest Win             : %.2f\n",  m_largestWin);
      s += StringFormat("Largest Loss            : %.2f\n",  m_largestLoss);
      s += StringFormat("Net Profit              : %.2f\n",  m_netProfit);
      s += StringFormat("Profit Factor           : %s\n",    pfs);
      s += StringFormat("Expectancy / trade      : %.4f\n",  Expectancy());
      s += StringFormat("Average Profit / trade  : %.4f\n",  (m_total > 0 ? m_netProfit / m_total : 0.0));
      s += StringFormat("Max Drawdown (closed)   : %.2f\n",  m_maxDrawdown);
      s += StringFormat("Recovery Factor         : %.3f\n",  RecoveryFactor());
      s += StringFormat("Max Consecutive Losses  : %d\n",    m_maxConsecLosses);
      s += StringFormat("Average Trade Duration  : %.1f sec\n", AvgDuration());
      s += "-------------------- EXIT REASONS (this session) -------------------\n";
      s += StringFormat("Take Profit hits        : %d\n", exitTP);
      s += StringFormat("Trailing stop exits     : %d\n", exitTrail);
      s += StringFormat("Break-even exits        : %d\n", exitBreakeven);
      s += StringFormat("Initial stop exits      : %d\n", exitSL);
      s += StringFormat("Momentum reversal exits : %d\n", exitReversal);
      s += StringFormat("Max duration exits      : %d\n", exitDuration);
      s += StringFormat("Emergency exits         : %d\n", exitEmergency);
      s += StringFormat("External/manual exits   : %d\n", exitExternal);
      s += "NOTE: a high win rate alone proves nothing. Judge expectancy, profit\n";
      s += "factor, drawdown and the size of the worst losses together.\n";
      s += "====================================================================\n";
      return s;
     }
  };

//+------------------------------------------------------------------+
//| Risk manager - safety layer, explicitly NOT part of the strategy |
//+------------------------------------------------------------------+
class CRiskManager
  {
private:
   double            m_dayStartEquity;
   double            m_dayStartBalance;
   int               m_currentDay;
   bool              m_halted;
   string            m_haltReason;

   int               DayOf(const datetime t) const
     {
      MqlDateTime dt;
      TimeToStruct(t, dt);
      return dt.year * 10000 + dt.mon * 100 + dt.day;
     }

public:
                     CRiskManager(void)
     {
      m_dayStartEquity  = 0.0;
      m_dayStartBalance = 0.0;
      m_currentDay      = -1;
      m_halted          = false;
      m_haltReason      = "";
     }

   void              Init(void)
     {
      NewDay();
     }

   void              NewDay(void)
     {
      m_currentDay      = DayOf(TimeCurrent());
      m_dayStartEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
      m_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_halted          = false;
      m_haltReason      = "";
      PmLog(StringFormat("New trading day. Start equity %.2f balance %.2f",
                         m_dayStartEquity, m_dayStartBalance));
     }

   bool              IsHalted(void)   const { return m_halted; }
   string            HaltReason(void) const { return m_haltReason; }
   double            DayStartEquity(void) const { return m_dayStartEquity; }

   void              Halt(const string reason)
     {
      if(!m_halted)
        {
         m_halted     = true;
         m_haltReason = reason;
         PmLogAlways("RISK HALT: " + reason);
        }
     }

   //--- returns true when new entries are allowed
   bool              Check(const int consecutiveLosses)
     {
      if(DayOf(TimeCurrent()) != m_currentDay)
         NewDay();

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double dayPL  = equity - m_dayStartEquity;

      if(EnableDailyLossLimit && DailyLossLimitPercent > 0.0 && m_dayStartEquity > 0.0)
        {
         double limit = m_dayStartEquity * DailyLossLimitPercent / 100.0;
         if(dayPL <= -limit)
            Halt(StringFormat("daily loss limit reached (%.2f <= -%.2f)", dayPL, limit));
        }

      if(MaxDailyLossMoney > 0.0 && dayPL <= -MaxDailyLossMoney)
         Halt(StringFormat("daily loss money limit reached (%.2f)", dayPL));

      if(EnableDailyProfitTarget && DailyProfitTargetMoney > 0.0 && dayPL >= DailyProfitTargetMoney)
         Halt(StringFormat("daily profit target reached (%.2f)", dayPL));

      if(MaxEquityDrawdownPercent > 0.0 && m_dayStartEquity > 0.0)
        {
         double ddPct = (m_dayStartEquity - equity) / m_dayStartEquity * 100.0;
         if(ddPct >= MaxEquityDrawdownPercent)
            Halt(StringFormat("equity drawdown %.2f%% >= %.2f%%", ddPct, MaxEquityDrawdownPercent));
        }

      if(MaxConsecutiveLosses > 0 && consecutiveLosses >= MaxConsecutiveLosses)
         Halt(StringFormat("max consecutive losses reached (%d)", consecutiveLosses));

      return !m_halted;
     }
  };

//+------------------------------------------------------------------+
//| Dashboard / visual manager                                       |
//+------------------------------------------------------------------+
class CDashboardManager
  {
private:
   string            m_prefix;
   CSymbolCtx       *m_sym;
   int               m_lineCount;
   int               m_markerCount;
   bool              m_active;

   void              Label(const string key, const string text, const int row)
     {
      string name = m_prefix + "lbl_" + key;
      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, DashboardX);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, DashboardY + row * 15);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
        }
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, DashboardY + row * 15);
      ObjectSetInteger(0, name, OBJPROP_COLOR, DashboardColor);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
     }

   void              HLine(const string key, const double price, const color clr, const ENUM_LINE_STYLE style)
     {
      string name = m_prefix + "line_" + key;
      if(price <= 0.0)
        {
         if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
         return;
        }
      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        }
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
     }

public:
                     CDashboardManager(void)
     {
      m_prefix      = "PM_";
      m_sym         = NULL;
      m_lineCount   = 0;
      m_markerCount = 0;
      m_active      = false;
     }

   void              Init(CSymbolCtx *sym)
     {
      m_sym    = sym;
      m_prefix = StringFormat("PM_%I64u_", (ulong)MagicNumber);
      //--- chart objects only make sense on the chart of the traded symbol, and
      //--- they are pure overhead in a non-visual optimisation run.
      bool testerNoVisual = (bool)MQLInfoInteger(MQL_TESTER) && !(bool)MQLInfoInteger(MQL_VISUAL_MODE);
      m_active = (sym != NULL && sym.name == _Symbol && !testerNoVisual);
      Clear();
     }

   bool              Active(void) const { return m_active; }

   void              Clear(void)
     {
      ObjectsDeleteAll(0, m_prefix);
      ChartRedraw();
     }

   void              Update(const string &text[], const int count)
     {
      if(!m_active || !ShowDashboard) return;
      for(int i = 0; i < count; i++)
         Label(IntegerToString(i), text[i], i);
      //--- remove leftovers from a longer previous frame
      for(int i = count; i < m_lineCount; i++)
        {
         string name = m_prefix + "lbl_" + IntegerToString(i);
         if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
        }
      m_lineCount = count;
      ChartRedraw();
     }

   void              UpdateLevels(const double pending, const double entry, const double tp, const double sl)
     {
      if(!m_active) return;
      HLine("pending", (ShowPendingPrice ? pending : 0.0), clrDeepSkyBlue, STYLE_DOT);
      HLine("entry",   entry,                              clrSilver,      STYLE_DOT);
      HLine("tp",      tp,                                 clrLimeGreen,   STYLE_DASH);
      HLine("sl",      sl,                                 clrOrangeRed,   STYLE_DASH);
      ChartRedraw();
     }

   void              PendingLine(const bool isBuy, const double price)
     {
      if(!m_active) return;
      HLine("pending", (ShowPendingPrice ? price : 0.0),
            (isBuy ? clrDeepSkyBlue : clrRed), STYLE_DOT);
     }

   void              Marker(const bool isBuy, const datetime t, const double price)
     {
      if(!m_active || !ShowTradeMarkers) return;
      string name = StringFormat("%sarr_%d_%I64u", m_prefix, m_markerCount, (ulong)t);
      if(ObjectCreate(0, name, (isBuy ? OBJ_ARROW_BUY : OBJ_ARROW_SELL), 0, t, price))
        {
         ObjectSetInteger(0, name, OBJPROP_COLOR, (isBuy ? clrDodgerBlue : clrRed));
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        }
      m_markerCount++;
      //--- housekeeping: drop the oldest arrows
      if(MaxTradeMarkers > 0 && m_markerCount > MaxTradeMarkers)
        {
         int cutoff = m_markerCount - MaxTradeMarkers;
         int total  = ObjectsTotal(0, -1, -1);
         for(int i = total - 1; i >= 0; i--)
           {
            string on = ObjectName(0, i, -1, -1);
            if(StringFind(on, m_prefix + "arr_") != 0) continue;
            string rest = StringSubstr(on, StringLen(m_prefix) + 4);
            int    usc  = StringFind(rest, "_");
            if(usc <= 0) continue;
            int idx = (int)StringToInteger(StringSubstr(rest, 0, usc));
            if(idx < cutoff) ObjectDelete(0, on);
           }
        }
     }
  };

//+------------------------------------------------------------------+
//| The Expert Advisor itself                                        |
//+------------------------------------------------------------------+
class CPeakMomentumEA
  {
private:
   CSymbolCtx        m_sym;
   CMomentumEngine   m_mom;
   COrderManager     m_orders;
   CRiskManager      m_risk;
   CStatisticsManager m_stats;
   CDashboardManager m_dash;

   StrategyState     m_state;
   bool              m_initialised;

   //--- pending order tracking
   ulong             m_pendingTicket;
   bool              m_pendingIsBuy;
   double            m_pendingPrice;
   datetime          m_pendingPlacedAt;

   //--- position tracking
   ulong             m_posTicket;
   long              m_posId;
   bool              m_posIsBuy;
   double            m_entryPrice;
   double            m_posVolume;
   datetime          m_entryTime;
   double            m_tpPrice;
   double            m_slPrice;
   double            m_highestFavorable;
   double            m_lowestFavorable;
   double            m_maxFloatingProfitPts;
   double            m_momentumAtEntry;
   double            m_peakMomentum;
   double            m_currentMomentum;
   double            m_momentumDecay;
   double            m_trailDistancePts;
   int               m_reversalCount;
   ENUM_PM_EXIT      m_intendedExit;

   //--- timing
   ulong             m_cooldownUntilMs;
   ulong             m_lastDashboardMs;
   datetime          m_lastStatsPrint;
   MqlTick           m_tick;

   //--- helpers ---------------------------------------------------
   string            PendingComment(void) const
     {
      return (UseDistinctPendingComment ? "peak momentum pending" : "peak momentum");
     }

   double            DirectionalMomentum(const bool isBuy)
     {
      return (isBuy ? m_mom.Score() : -m_mom.Score());
     }

   double            LotSize(void)
     {
      if(LotMode == LOT_MODE_FIXED)
         return m_sym.NormalizeVolume(FixedLot);

      //--- risk based: size from the actual initial stop distance
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney = balance * RiskPercent / 100.0;
      double stopPrice = m_sym.PtsPrice(InitialStopDistancePoints);
      if(stopPrice <= 0.0 || m_sym.tickSize <= 0.0 || m_sym.tickValue <= 0.0 || riskMoney <= 0.0)
        {
         PmLogAlways("Risk sizing not possible, falling back to FixedLot");
         return m_sym.NormalizeVolume(FixedLot);
        }
      double lossPerLot = stopPrice / m_sym.tickSize * m_sym.tickValue;
      if(lossPerLot <= 0.0)
         return m_sym.NormalizeVolume(FixedLot);
      double lots = riskMoney / lossPerLot;
      return m_sym.NormalizeVolume(lots);
     }

   bool              SpreadOk(void)
     {
      if(MaxSpreadPoints <= 0.0) return true;
      return (m_sym.SpreadPointsScaled() <= MaxSpreadPoints);
     }

   bool              InCooldown(void) const
     {
      return (GetTickCount64() < m_cooldownUntilMs);
     }

   void              StartCooldown(void)
     {
      double sec = MathMax(0.0, CooldownSeconds);
      m_cooldownUntilMs = GetTickCount64() + (ulong)(sec * 1000.0);
     }

   void              SetState(const StrategyState s)
     {
      if(m_state != s)
        {
         PmLog(StringFormat("State %s -> %s", StateToString(m_state), StateToString(s)));
         m_state = s;
        }
     }

   void              ResetPositionTracking(void)
     {
      m_posTicket            = 0;
      m_posId                = 0;
      m_posIsBuy             = false;
      m_entryPrice           = 0.0;
      m_posVolume            = 0.0;
      m_entryTime            = 0;
      m_tpPrice              = 0.0;
      m_slPrice              = 0.0;
      m_highestFavorable     = 0.0;
      m_lowestFavorable      = 0.0;
      m_maxFloatingProfitPts = 0.0;
      m_momentumAtEntry      = 0.0;
      m_peakMomentum         = 0.0;
      m_currentMomentum      = 0.0;
      m_momentumDecay        = 0.0;
      m_trailDistancePts     = 0.0;
      m_reversalCount        = 0;
      m_intendedExit         = PM_EXIT_NONE;
     }

   void              ResetPendingTracking(void)
     {
      m_pendingTicket   = 0;
      m_pendingIsBuy    = false;
      m_pendingPrice    = 0.0;
      m_pendingPlacedAt = 0;
     }

   //--- pending order management ---------------------------------
   double            DesiredPendingPrice(const bool isBuy)
     {
      double dist = PmClamp(PendingDistancePoints,
                            MinimumPendingDistancePoints,
                            MaximumPendingDistancePoints);
      double distPrice = m_sym.PtsPrice(dist);

      //--- respect the broker minimum distance for stop orders
      double minStop = m_sym.StopsPrice();
      if(distPrice < minStop + m_sym.point)
         distPrice = minStop + m_sym.point;

      double price = (isBuy ? m_tick.ask + distPrice : m_tick.bid - distPrice);
      return m_sym.NormalizePrice(price);
     }

   void              PendingProtection(const bool isBuy, const double price, double &sl, double &tp)
     {
      double tpDist = MathAbs(TakeProfitPriceUnits);
      double slDist = m_sym.PtsPrice(InitialStopDistancePoints);
      double minStop = m_sym.StopsPrice();
      if(tpDist < minStop + m_sym.point) tpDist = minStop + m_sym.point;
      if(slDist < minStop + m_sym.point) slDist = minStop + m_sym.point;

      if(isBuy)
        {
         tp = m_sym.NormalizePrice(price + tpDist);
         sl = m_sym.NormalizePrice(price - slDist);
        }
      else
        {
         tp = m_sym.NormalizePrice(price - tpDist);
         sl = m_sym.NormalizePrice(price + slDist);
        }
      if(TakeProfitPriceUnits <= 0.0) tp = 0.0;
      if(InitialStopDistancePoints <= 0.0) sl = 0.0;
     }

   bool              PlacePending(const bool isBuy)
     {
      if(!EnableTrading) return false;
      if(!SpreadOk())
        {
         PmLog(StringFormat("Entry blocked: spread %.1f > %.1f",
                            m_sym.SpreadPointsScaled(), MaxSpreadPoints));
         return false;
        }

      double price = DesiredPendingPrice(isBuy);
      double sl = 0.0, tp = 0.0;
      PendingProtection(isBuy, price, sl, tp);

      double lots = LotSize();
      if(lots <= 0.0)
        {
         PmLogAlways("Invalid lot size, entry aborted");
         return false;
        }

      PmLog(StringFormat("Momentum %s detected | Score: %.3f | Velocity: %.2f | Acceleration: %.2f | Breakout: %.2f",
                         (isBuy ? "BUY" : "SELL"), m_mom.Score(), m_mom.Velocity(),
                         m_mom.Acceleration(), m_mom.Breakout()));

      ulong ticket = 0;
      if(!m_orders.PlaceStopOrder(isBuy, lots, price, sl, tp, PendingComment(), ticket))
         return false;

      m_pendingTicket   = ticket;
      m_pendingIsBuy    = isBuy;
      m_pendingPrice    = price;
      m_pendingPlacedAt = TimeCurrent();

      PmLog(StringFormat("%s STOP placed at %s (#%I64u, tp=%s, sl=%s, lots=%.2f)",
                         (isBuy ? "BUY" : "SELL"), DoubleToString(price, m_sym.digits), ticket,
                         DoubleToString(tp, m_sym.digits), DoubleToString(sl, m_sym.digits), lots));

      m_dash.PendingLine(isBuy, price);
      SetState(isBuy ? STATE_PENDING_BUY : STATE_PENDING_SELL);
      return true;
     }

   bool              PendingStillExists(void)
     {
      if(m_pendingTicket == 0) return false;
      if(!OrderSelect(m_pendingTicket)) return false;
      if(OrderGetInteger(ORDER_MAGIC) != (long)MagicNumber) return false;
      return true;
     }

   void              DeleteCurrentPending(const string reason)
     {
      if(m_pendingTicket == 0) return;
      //--- freeze level guard
      if(OrderSelect(m_pendingTicket))
        {
         double op    = OrderGetDouble(ORDER_PRICE_OPEN);
         double ref   = (m_pendingIsBuy ? m_tick.ask : m_tick.bid);
         double frz   = m_sym.FreezePrice();
         if(frz > 0.0 && MathAbs(op - ref) < frz)
           {
            PmLog("Pending delete postponed: inside freeze level");
            return;
           }
        }
      PmLog(StringFormat("Deleting pending #%I64u (%s)", m_pendingTicket, reason));
      if(m_orders.DeletePending(m_pendingTicket))
        {
         ResetPendingTracking();
         m_dash.PendingLine(true, 0.0);
        }
     }

   void              ManagePending(void)
     {
      if(!PendingStillExists())
         return;   // fill/deletion is resolved by RebuildState()

      //--- read the working price while the order is definitely selected
      double current = OrderGetDouble(ORDER_PRICE_OPEN);

      ENUM_MOMENTUM_DIR dir = m_mom.Direction();

      //--- direction flip
      if(CancelPendingOnDirectionFlip)
        {
         if((m_pendingIsBuy && dir == MOM_SELL) || (!m_pendingIsBuy && dir == MOM_BUY))
           {
            DeleteCurrentPending("momentum direction flip");
            return;
           }
        }

      //--- momentum loss
      if(CancelPendingOnMomentumLoss)
        {
         double dm = DirectionalMomentum(m_pendingIsBuy);
         if(dm < MomentumThreshold)
           {
            DeleteCurrentPending(StringFormat("momentum faded (dir score %.3f < %.3f)", dm, MomentumThreshold));
            return;
           }
        }

      //--- timeout
      if(PendingTimeoutSeconds > 0 && m_pendingPlacedAt > 0)
        {
         if(TimeCurrent() - m_pendingPlacedAt >= PendingTimeoutSeconds)
           {
            DeleteCurrentPending("timeout");
            return;
           }
        }

      //--- follow the market
      double desired = DesiredPendingPrice(m_pendingIsBuy);
      double diff    = MathAbs(desired - current);
      double thresh  = m_sym.PtsPrice(MathMax(1.0, PendingModifyThresholdPoints));

      if(diff >= thresh)
        {
         //--- freeze level guard
         double ref = (m_pendingIsBuy ? m_tick.ask : m_tick.bid);
         double frz = m_sym.FreezePrice();
         if(frz > 0.0 && MathAbs(current - ref) < frz)
            return;

         double sl = 0.0, tp = 0.0;
         PendingProtection(m_pendingIsBuy, desired, sl, tp);
         if(m_orders.ModifyPending(m_pendingTicket, desired, sl, tp))
           {
            PmLog(StringFormat("%s STOP modified to %s",
                               (m_pendingIsBuy ? "BUY" : "SELL"), DoubleToString(desired, m_sym.digits)));
            m_pendingPrice = desired;
            m_dash.PendingLine(m_pendingIsBuy, desired);
           }
        }
     }

   //--- position management --------------------------------------
   void              OnPositionOpened(const ulong ticket)
     {
      if(!PositionSelectByTicket(ticket)) return;

      m_posTicket  = ticket;
      m_posId      = PositionGetInteger(POSITION_IDENTIFIER);
      m_posIsBuy   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      m_entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      m_posVolume  = PositionGetDouble(POSITION_VOLUME);
      m_entryTime  = (datetime)PositionGetInteger(POSITION_TIME);
      m_slPrice    = PositionGetDouble(POSITION_SL);
      m_tpPrice    = PositionGetDouble(POSITION_TP);

      //--- on a fresh fill these equal the entry price; after a restart they are
      //--- seeded with the current market so the trailing engine cannot loosen.
      m_highestFavorable     = MathMax(m_entryPrice, m_tick.bid);
      m_lowestFavorable      = MathMin(m_entryPrice, m_tick.ask);
      m_maxFloatingProfitPts = MathMax(0.0, FloatingProfitPts());
      m_momentumAtEntry      = DirectionalMomentum(m_posIsBuy);
      m_peakMomentum         = m_momentumAtEntry;
      m_currentMomentum      = m_momentumAtEntry;
      m_momentumDecay        = 0.0;
      m_reversalCount        = 0;
      m_intendedExit         = PM_EXIT_NONE;

      PmLog(StringFormat("%s STOP triggered", (m_posIsBuy ? "BUY" : "SELL")));
      PmLog(StringFormat("Entry: %s (lots %.2f, ticket #%I64u)",
                         DoubleToString(m_entryPrice, m_sym.digits), m_posVolume, ticket));

      //--- recompute exact TP/SL from the REAL fill price
      double tpDist  = MathAbs(TakeProfitPriceUnits);
      double slDist  = m_sym.PtsPrice(InitialStopDistancePoints);
      double minStop = m_sym.StopsPrice();
      double bid = m_tick.bid, ask = m_tick.ask;

      double wantTp = 0.0, wantSl = 0.0;
      if(TakeProfitPriceUnits > 0.0)
        {
         wantTp = (m_posIsBuy ? m_entryPrice + tpDist : m_entryPrice - tpDist);
         wantTp = m_sym.NormalizePrice(wantTp);
         //--- broker distance validation against the current market
         if(m_posIsBuy  && wantTp < bid + minStop + m_sym.point) wantTp = m_sym.NormalizePrice(bid + minStop + m_sym.point);
         if(!m_posIsBuy && wantTp > ask - minStop - m_sym.point) wantTp = m_sym.NormalizePrice(ask - minStop - m_sym.point);
        }
      if(InitialStopDistancePoints > 0.0)
        {
         wantSl = (m_posIsBuy ? m_entryPrice - slDist : m_entryPrice + slDist);
         wantSl = m_sym.NormalizePrice(wantSl);
         if(m_posIsBuy  && wantSl > bid - minStop - m_sym.point) wantSl = m_sym.NormalizePrice(bid - minStop - m_sym.point);
         if(!m_posIsBuy && wantSl < ask + minStop + m_sym.point) wantSl = m_sym.NormalizePrice(ask + minStop + m_sym.point);

         //--- RESTART SAFETY: an existing stop that is already better than the
         //--- initial one (trailed before the restart) is never moved backwards.
         if(m_slPrice > 0.0)
           {
            if(m_posIsBuy  && m_slPrice > wantSl) wantSl = m_slPrice;
            if(!m_posIsBuy && m_slPrice < wantSl) wantSl = m_slPrice;
           }
        }

      bool needFix = (MathAbs(wantTp - m_tpPrice) > m_sym.point * 0.5)
                     || (MathAbs(wantSl - m_slPrice) > m_sym.point * 0.5);
      if(needFix)
        {
         if(m_orders.ModifyStopLoss(ticket, wantSl, wantTp))
           {
            m_slPrice = wantSl;
            m_tpPrice = wantTp;
           }
        }

      PmLog(StringFormat("TP: %s | initial SL: %s",
                         DoubleToString(m_tpPrice, m_sym.digits),
                         DoubleToString(m_slPrice, m_sym.digits)));
      PmLog(StringFormat("Peak momentum at entry: %.3f", m_peakMomentum));

      m_dash.Marker(m_posIsBuy, m_entryTime, m_entryPrice);
      SetState(m_posIsBuy ? STATE_BUY_ACTIVE : STATE_SELL_ACTIVE);
     }

   double            ComputeTrailDistancePts(void)
     {
      double dist = TrailingBaseDistancePoints - m_momentumDecay * MomentumTrailFactor;

      //--- momentum expansion: give an accelerating trade more room
      if(m_currentMomentum >= m_peakMomentum - 0.0000001 && m_currentMomentum > 0.0)
         dist = dist * MathMax(1.0, ExpansionRoomMultiplier);

      //--- strong run deep in profit keeps the maximum room
      double profitPts = FloatingProfitPts();
      if(StrongMomentumTriggerPoints > 0.0
         && profitPts >= StrongMomentumTriggerPoints
         && m_currentMomentum >= StrongMomentumScore)
         dist = MathMax(dist, TrailingMaximumDistancePoints);

      return PmClamp(dist, TrailingMinimumDistancePoints, TrailingMaximumDistancePoints);
     }

   double            FloatingProfitPts(void)
     {
      if(m_posTicket == 0 || m_entryPrice <= 0.0) return 0.0;
      double px = (m_posIsBuy ? m_tick.bid : m_tick.ask);
      double d  = (m_posIsBuy ? px - m_entryPrice : m_entryPrice - px);
      return m_sym.PriceToPts(d);
     }

   void              ManagePosition(void)
     {
      if(m_posTicket == 0) return;
      if(!PositionSelectByTicket(m_posTicket))
         return;   // resolved by RebuildState()

      double bid = m_tick.bid, ask = m_tick.ask;
      m_slPrice  = PositionGetDouble(POSITION_SL);
      m_tpPrice  = PositionGetDouble(POSITION_TP);

      //--- favourable excursion tracking
      if(m_posIsBuy)
        {
         if(bid > m_highestFavorable) m_highestFavorable = bid;
        }
      else
        {
         if(m_lowestFavorable <= 0.0 || ask < m_lowestFavorable) m_lowestFavorable = ask;
        }

      double profitPts = FloatingProfitPts();
      if(profitPts > m_maxFloatingProfitPts) m_maxFloatingProfitPts = profitPts;

      //--- momentum tracking
      m_currentMomentum = DirectionalMomentum(m_posIsBuy);
      if(m_currentMomentum > m_peakMomentum)
        {
         m_peakMomentum = m_currentMomentum;
         PmLog(StringFormat("Peak momentum: %.3f", m_peakMomentum));
        }
      double decay = m_peakMomentum - m_currentMomentum;
      if(decay < 0.0) decay = 0.0;
      bool decayStarted = (decay > 0.0 && m_momentumDecay <= 0.0);
      m_momentumDecay = decay;
      if(decayStarted)
         PmLog(StringFormat("Momentum decay detected (peak %.3f -> current %.3f)",
                            m_peakMomentum, m_currentMomentum));

      //--- 1) emergency spread protection
      if(EnableSpreadEmergencyExit && MaxSpreadPoints > 0.0 && SpreadMultiplier > 0.0)
        {
         if(m_sym.SpreadPointsScaled() > MaxSpreadPoints * SpreadMultiplier)
           {
            ClosePositionNow(PM_EXIT_EMERGENCY, "spread explosion");
            return;
           }
        }

      //--- 2) momentum reversal exit
      if(CloseOnMomentumReversal && ReversalExitScore > 0.0)
        {
         if(m_currentMomentum <= -ReversalExitScore) m_reversalCount++;
         else                                        m_reversalCount = 0;

         if(m_reversalCount >= (int)MathMax(1, ReversalConfirmationTicks))
           {
            ClosePositionNow(PM_EXIT_REVERSAL,
                             StringFormat("momentum reversed (dir score %.3f)", m_currentMomentum));
            return;
           }
        }

      //--- 3) maximum holding time
      bool durationExceeded = false;
      if(MaxTradeDurationSeconds > 0 && m_entryTime > 0)
         durationExceeded = ((int)(TimeCurrent() - m_entryTime) >= MaxTradeDurationSeconds);

      if(durationExceeded && CloseOnMaxDuration)
        {
         ClosePositionNow(PM_EXIT_DURATION,
                          StringFormat("max holding time %ds exceeded", MaxTradeDurationSeconds));
         return;
        }

      //--- 4) trailing / profit protection
      if(!EnableTrailing) return;

      m_trailDistancePts = ComputeTrailDistancePts();
      if(durationExceeded)
         m_trailDistancePts = TrailingMinimumDistancePoints;   // tighten instead of closing

      double trailPrice = m_sym.PtsPrice(m_trailDistancePts);
      double candidate  = 0.0;

      if(m_posIsBuy)
        {
         candidate = m_highestFavorable - trailPrice;

         if(BreakEvenTriggerPoints > 0.0 && m_maxFloatingProfitPts >= BreakEvenTriggerPoints)
            candidate = MathMax(candidate, m_entryPrice + m_sym.PtsPrice(BreakEvenLockPoints));

         if(LockProfitTriggerPoints > 0.0 && m_maxFloatingProfitPts >= LockProfitTriggerPoints)
           {
            double lock = m_entryPrice + m_sym.PtsPrice(m_maxFloatingProfitPts * PmClamp(LockProfitRatio, 0.0, 0.95));
            candidate = MathMax(candidate, lock);
           }
        }
      else
        {
         candidate = m_lowestFavorable + trailPrice;

         if(BreakEvenTriggerPoints > 0.0 && m_maxFloatingProfitPts >= BreakEvenTriggerPoints)
            candidate = MathMin(candidate, m_entryPrice - m_sym.PtsPrice(BreakEvenLockPoints));

         if(LockProfitTriggerPoints > 0.0 && m_maxFloatingProfitPts >= LockProfitTriggerPoints)
           {
            double lock = m_entryPrice - m_sym.PtsPrice(m_maxFloatingProfitPts * PmClamp(LockProfitRatio, 0.0, 0.95));
            candidate = MathMin(candidate, lock);
           }
        }

      candidate = m_sym.NormalizePrice(candidate);

      //--- broker constraints
      double minStop = m_sym.StopsPrice();
      double frz     = m_sym.FreezePrice();
      if(m_posIsBuy)
        {
         double maxAllowed = m_sym.NormalizePrice(bid - minStop - m_sym.point);
         if(candidate > maxAllowed) candidate = maxAllowed;
        }
      else
        {
         double minAllowed = m_sym.NormalizePrice(ask + minStop + m_sym.point);
         if(candidate < minAllowed) candidate = minAllowed;
        }

      //--- never move the stop backwards, and only move it meaningfully
      double step = m_sym.PtsPrice(MathMax(1.0, SLModifyThresholdPoints));
      bool   doIt = false;
      if(m_posIsBuy)
         doIt = (m_slPrice <= 0.0 && candidate > 0.0) || (candidate >= m_slPrice + step);
      else
         doIt = (m_slPrice <= 0.0 && candidate > 0.0) || (candidate <= m_slPrice - step);

      if(!doIt) return;

      //--- freeze level: modification of a stop too close to market is rejected
      if(frz > 0.0)
        {
         double ref = (m_posIsBuy ? bid : ask);
         if(MathAbs(candidate - ref) < frz) return;
        }

      if(m_orders.ModifyStopLoss(m_posTicket, candidate, m_tpPrice))
        {
         PmLog(StringFormat("Trailing SL moved to %s (distance %.1f pts, decay %.3f)",
                            DoubleToString(candidate, m_sym.digits), m_trailDistancePts, m_momentumDecay));
         m_slPrice = candidate;
        }
     }

   void              ClosePositionNow(const ENUM_PM_EXIT reason, const string text)
     {
      if(m_posTicket == 0) return;
      m_intendedExit = reason;
      PmLog(StringFormat("Closing position #%I64u: %s (%s)", m_posTicket, ExitToString(reason), text));
      if(!m_orders.ClosePosition(m_posTicket))
         m_intendedExit = PM_EXIT_NONE;   // retry on the next tick
     }

   //--- classify how a closed position ended ----------------------
   void              OnPositionClosed(const ulong ticket, const long posId, const bool wasBuy,
                                      const double entry, const double sl)
     {
      ENUM_PM_EXIT reason = m_intendedExit;
      double profit = 0.0;

      if(HistorySelectByPosition(posId != 0 ? posId : (long)ticket))
        {
         int deals = HistoryDealsTotal();
         for(int i = 0; i < deals; i++)
           {
            ulong dt = HistoryDealGetTicket(i);
            if(dt == 0) continue;
            profit += HistoryDealGetDouble(dt, DEAL_PROFIT)
                      + HistoryDealGetDouble(dt, DEAL_SWAP)
                      + HistoryDealGetDouble(dt, DEAL_COMMISSION);
            if(HistoryDealGetInteger(dt, DEAL_ENTRY) == DEAL_ENTRY_IN) continue;
            long dr = HistoryDealGetInteger(dt, DEAL_REASON);
            if(dr == DEAL_REASON_TP)      reason = PM_EXIT_TP;
            else if(dr == DEAL_REASON_SL)
              {
               bool protectedStop = (sl > 0.0 && ((wasBuy && sl >= entry) || (!wasBuy && sl <= entry)));
               if(protectedStop)                              reason = PM_EXIT_BREAKEVEN;
               else if(MathAbs(sl - InitialStopPrice(wasBuy, entry)) < m_sym.point * 0.5)
                  reason = PM_EXIT_SL;
               else                                           reason = PM_EXIT_TRAIL;
              }
            else if(reason == PM_EXIT_NONE)                   reason = PM_EXIT_EXTERNAL;
           }
        }
      if(reason == PM_EXIT_NONE) reason = PM_EXIT_EXTERNAL;

      switch(reason)
        {
         case PM_EXIT_TP:        m_stats.exitTP++;        break;
         case PM_EXIT_TRAIL:     m_stats.exitTrail++;     break;
         case PM_EXIT_BREAKEVEN: m_stats.exitBreakeven++; break;
         case PM_EXIT_SL:        m_stats.exitSL++;        break;
         case PM_EXIT_REVERSAL:  m_stats.exitReversal++;  break;
         case PM_EXIT_DURATION:  m_stats.exitDuration++;  break;
         case PM_EXIT_EMERGENCY: m_stats.exitEmergency++; break;
         default:                m_stats.exitExternal++;  break;
        }

      PmLog(StringFormat("Position closed #%I64u | reason %s | P/L %.2f | peak momentum %.3f | decay %.3f",
                         ticket, ExitToString(reason), profit, m_peakMomentum, m_momentumDecay));

      ResetPositionTracking();
      StartCooldown();
      if(EnableStatistics) m_stats.RegisterClosedTrade(profit);
     }

   double            InitialStopPrice(const bool isBuy, const double entry)
     {
      double slDist = m_sym.PtsPrice(InitialStopDistancePoints);
      return m_sym.NormalizePrice(isBuy ? entry - slDist : entry + slDist);
     }

   //--- state reconstruction from the terminal --------------------
   void              RebuildState(void)
     {
      ulong positions[];
      ulong orders[];
      int nPos = m_orders.FindStrategyPositions(positions);
      int nOrd = m_orders.FindStrategyOrders(orders);

      //--- a tracked position that disappeared has been closed
      if(m_posTicket != 0)
        {
         bool stillThere = false;
         for(int i = 0; i < nPos; i++)
            if(positions[i] == m_posTicket) { stillThere = true; break; }
         if(!stillThere)
           {
            ulong  t     = m_posTicket;
            long   pid   = m_posId;
            bool   wasB  = m_posIsBuy;
            double entry = m_entryPrice;
            double sl    = m_slPrice;
            OnPositionClosed(t, pid, wasB, entry, sl);
           }
        }

      //--- adopt a position we are not tracking yet (fill or restart)
      if(m_posTicket == 0 && nPos > 0)
        {
         if(m_pendingTicket != 0) { ResetPendingTracking(); m_dash.PendingLine(true, 0.0); }
         OnPositionOpened(positions[0]);
        }

      //--- safety: never keep more than the configured number of positions
      if(nPos > MaxOpenPositions && MaxOpenPositions > 0)
        {
         PmLogAlways(StringFormat("WARNING: %d EA positions found, limit is %d. Extra positions are left untouched.",
                                  nPos, MaxOpenPositions));
        }

      //--- pending bookkeeping
      if(m_pendingTicket != 0)
        {
         bool stillThere = false;
         for(int i = 0; i < nOrd; i++)
            if(orders[i] == m_pendingTicket) { stillThere = true; break; }
         if(!stillThere)
           {
            if(m_posTicket == 0)
               PmLog(StringFormat("Pending #%I64u is gone (filled, deleted or expired)", m_pendingTicket));
            ResetPendingTracking();
            m_dash.PendingLine(true, 0.0);
           }
        }
      else if(nOrd > 0 && m_posTicket == 0)
        {
         //--- adopt an existing pending (restart recovery)
         if(OrderSelect(orders[0]))
           {
            m_pendingTicket   = orders[0];
            m_pendingIsBuy    = (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP);
            m_pendingPrice    = OrderGetDouble(ORDER_PRICE_OPEN);
            m_pendingPlacedAt = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
            PmLog(StringFormat("Adopted existing pending #%I64u %s at %s",
                               m_pendingTicket, (m_pendingIsBuy ? "BUY STOP" : "SELL STOP"),
                               DoubleToString(m_pendingPrice, m_sym.digits)));
            m_dash.PendingLine(m_pendingIsBuy, m_pendingPrice);
           }
        }

      //--- only one strategy cycle at a time: no pendings while a position is active,
      //--- and never more than MaxPendingOrders working pendings.
      bool dropAllPendings = (m_posTicket != 0);
      if(dropAllPendings || (MaxPendingOrders > 0 && nOrd > MaxPendingOrders))
        {
         for(int i = 0; i < nOrd; i++)
           {
            if(!dropAllPendings && orders[i] == m_pendingTicket) continue;
            PmLogAlways(StringFormat("Removing pending #%I64u (%s)", orders[i],
                                     (dropAllPendings ? "position active" : "surplus order")));
            if(m_orders.DeletePending(orders[i]) && orders[i] == m_pendingTicket)
              {
               ResetPendingTracking();
               m_dash.PendingLine(true, 0.0);
              }
           }
        }

      //--- derive the state
      if(m_posTicket != 0)
         SetState(m_posIsBuy ? STATE_BUY_ACTIVE : STATE_SELL_ACTIVE);
      else if(m_pendingTicket != 0)
         SetState(m_pendingIsBuy ? STATE_PENDING_BUY : STATE_PENDING_SELL);
      else if(m_risk.IsHalted())
         SetState(STATE_HALTED);
      else if(InCooldown())
         SetState(STATE_COOLDOWN);
      else
         SetState(m_mom.IsReady() ? STATE_WAITING : STATE_IDLE);
     }

   //--- dashboard -------------------------------------------------
   void              UpdateDashboard(void)
     {
      if(!ShowDashboard || !m_dash.Active()) return;

      //--- redrawing on literally every tick is wasted work
      ulong now = GetTickCount64();
      if(now - m_lastDashboardMs < 200) return;
      m_lastDashboardMs = now;

      string lines[];
      int n = 0;
      ArrayResize(lines, 24);

      lines[n++] = "=== PEAK MOMENTUM EA (reconstruction) ===";
      if(ShowState)
         lines[n++] = StringFormat("State           : %s", StateToString(m_state));
      if(ShowMomentumScore)
         lines[n++] = StringFormat("Momentum score  : %+.3f  (thr %.2f, conf %d/%d)",
                                   m_mom.Score(), MomentumThreshold, m_mom.ConfirmCount(),
                                   (int)MathMax(1, ConfirmationTicks));
      if(ShowVelocity)
         lines[n++] = StringFormat("Velocity        : %+.2f pts/s (norm %+.2f)", m_mom.Velocity(), m_mom.NormVelocity());
      if(ShowAcceleration)
         lines[n++] = StringFormat("Acceleration    : %+.2f pts/s2 (norm %+.2f)", m_mom.Acceleration(), m_mom.NormAcceleration());
      lines[n++] = StringFormat("Micro breakout  : %+.3f", m_mom.Breakout());
      lines[n++] = StringFormat("Spread          : %.1f pts (max %.1f)",
                                m_sym.SpreadPointsScaled(), MaxSpreadPoints);

      if(ShowPendingPrice)
        {
         if(m_pendingTicket != 0)
            lines[n++] = StringFormat("Pending         : %s %s (#%I64u)",
                                      (m_pendingIsBuy ? "BUY STOP" : "SELL STOP"),
                                      DoubleToString(m_pendingPrice, m_sym.digits), m_pendingTicket);
         else
            lines[n++] = "Pending         : -";
        }

      if(m_posTicket != 0)
        {
         lines[n++] = StringFormat("Position        : %s %.2f @ %s",
                                   (m_posIsBuy ? "BUY" : "SELL"), m_posVolume,
                                   DoubleToString(m_entryPrice, m_sym.digits));
         lines[n++] = StringFormat("TP / SL         : %s / %s",
                                   DoubleToString(m_tpPrice, m_sym.digits),
                                   DoubleToString(m_slPrice, m_sym.digits));
         lines[n++] = StringFormat("Peak / current  : %+.3f / %+.3f", m_peakMomentum, m_currentMomentum);
         lines[n++] = StringFormat("Momentum decay  : %.3f", m_momentumDecay);
         if(ShowTrailingDistance)
            lines[n++] = StringFormat("Trail distance  : %.1f pts", m_trailDistancePts);
         double fp = 0.0;
         if(PositionSelectByTicket(m_posTicket))
            fp = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         lines[n++] = StringFormat("Floating P/L    : %.2f  (%.1f pts)", fp, FloatingProfitPts());
        }
      else
        {
         lines[n++] = "Position        : -";
        }

      lines[n++] = StringFormat("Day P/L         : %.2f", AccountInfoDouble(ACCOUNT_EQUITY) - m_risk.DayStartEquity());
      if(m_risk.IsHalted())
         lines[n++] = "HALTED          : " + m_risk.HaltReason();

      m_dash.Update(lines, n);
      m_dash.UpdateLevels((m_pendingTicket != 0 ? m_pendingPrice : 0.0),
                          (m_posTicket != 0 ? m_entryPrice : 0.0),
                          (m_posTicket != 0 ? m_tpPrice    : 0.0),
                          (m_posTicket != 0 ? m_slPrice    : 0.0));
     }

public:
                     CPeakMomentumEA(void)
     {
      m_state           = STATE_IDLE;
      m_initialised     = false;
      m_cooldownUntilMs = 0;
      m_lastDashboardMs = 0;
      m_lastStatsPrint  = 0;
      ResetPendingTracking();
      ResetPositionTracking();
     }

   bool              Init(void)
     {
      string sym = (StringLen(TradeSymbol) > 0 ? TradeSymbol : _Symbol);
      if(!m_sym.Init(sym))
         return false;

      if(!m_mom.Init(GetPointer(m_sym)))
         return false;

      m_orders.Init(GetPointer(m_sym), (ulong)MagicNumber);
      m_risk.Init();
      m_stats.Init(GetPointer(m_sym), (ulong)MagicNumber, TimeCurrent() - 30 * 86400);
      m_dash.Init(GetPointer(m_sym));

      PmLogAlways(StringFormat("Peak Momentum EA start | symbol=%s digits=%d point=%s tickSize=%s tickValue=%.5f contract=%.2f",
                               m_sym.name, m_sym.digits,
                               DoubleToString(m_sym.point, 8), DoubleToString(m_sym.tickSize, 8),
                               m_sym.tickValue, m_sym.contractSize));
      PmLogAlways(StringFormat("Reference timeframe = %s (informational only - all signals are tick based)",
                               EnumToString(SignalTimeframe)));
      PmLogAlways(StringFormat("Broker limits | stopsLevel=%d pts freezeLevel=%d pts volume %.2f..%.2f step %.2f",
                               m_sym.stopsLevel, m_sym.freezeLevel, m_sym.volMin, m_sym.volMax, m_sym.volStep));
      PmLogAlways(StringFormat("Point input scaling factor = %.4f (an input of 1 point = %s price)",
                               m_sym.pointScale, DoubleToString(m_sym.PtsPrice(1.0), m_sym.digits + 2)));
      PmLogAlways(StringFormat("Effective distances | pending=%s initialSL=%s trailBase=%s trailMin=%s TP=%s",
                               DoubleToString(m_sym.PtsPrice(PendingDistancePoints), m_sym.digits),
                               DoubleToString(m_sym.PtsPrice(InitialStopDistancePoints), m_sym.digits),
                               DoubleToString(m_sym.PtsPrice(TrailingBaseDistancePoints), m_sym.digits),
                               DoubleToString(m_sym.PtsPrice(TrailingMinimumDistancePoints), m_sym.digits),
                               DoubleToString(TakeProfitPriceUnits, m_sym.digits)));

      if(!ValidateInputs())
         return false;

      //--- crash / restart recovery
      if(!SymbolInfoTick(m_sym.name, m_tick))
         PmLogAlways("WARNING: no tick available yet for " + m_sym.name);

      if(EnableStatistics)
         m_stats.Rebuild();
      m_lastStatsPrint = TimeCurrent();

      RebuildState();
      PmLogAlways("Recovered state: " + StateToString(m_state)
                  + StringFormat(" | position #%I64u | pending #%I64u", m_posTicket, m_pendingTicket));

      m_initialised = true;
      return true;
     }

   bool              ValidateInputs(void)
     {
      bool ok = true;
      if(MomentumLookbackTicks < 1)                         { PmLogAlways("ERROR: MomentumLookbackTicks must be >= 1"); ok = false; }
      if(MomentumLookbackMilliseconds < 1)                  { PmLogAlways("ERROR: MomentumLookbackMilliseconds must be >= 1"); ok = false; }
      if(MomentumSmoothing <= 0.0 || MomentumSmoothing > 1.0){ PmLogAlways("ERROR: MomentumSmoothing must be within (0,1]"); ok = false; }
      if(MinimumPendingDistancePoints > MaximumPendingDistancePoints)
        { PmLogAlways("ERROR: MinimumPendingDistancePoints > MaximumPendingDistancePoints"); ok = false; }
      if(TrailingMinimumDistancePoints > TrailingMaximumDistancePoints)
        { PmLogAlways("ERROR: TrailingMinimumDistancePoints > TrailingMaximumDistancePoints"); ok = false; }
      if(LotMode == LOT_MODE_FIXED && FixedLot <= 0.0)      { PmLogAlways("ERROR: FixedLot must be > 0"); ok = false; }
      if(LotMode == LOT_MODE_RISK_PERCENT && RiskPercent <= 0.0) { PmLogAlways("ERROR: RiskPercent must be > 0"); ok = false; }
      if(MaxOpenPositions != 1)
         PmLogAlways("NOTE: MaxOpenPositions != 1 - the reference behaviour uses a single position.");
      if(TakeProfitPriceUnits <= 0.0)
         PmLogAlways("NOTE: TakeProfitPriceUnits <= 0 - trades will run without a fixed take profit.");
      return ok;
     }

   void              Deinit(const int reason)
     {
      if(PrintStatsOnDeinit && EnableStatistics)
         PmLogAlways(m_stats.Report());
      m_dash.Clear();
      PmLogAlways("Peak Momentum EA stopped (reason " + IntegerToString(reason) + ")");
     }

   //--- main processing -------------------------------------------
   void              Process(void)
     {
      if(!m_initialised) return;

      if(!SymbolInfoTick(m_sym.name, m_tick))
         return;
      if(m_tick.bid <= 0.0 || m_tick.ask <= 0.0)
         return;

      m_sym.Refresh();
      m_mom.Update(m_tick);

      //--- resolve fills, closes and restarts first
      RebuildState();

      //--- periodic statistics (runs in every state, not only while idle)
      if(EnableStatistics && StatsPrintIntervalSeconds > 0)
        {
         if(TimeCurrent() - m_lastStatsPrint >= StatsPrintIntervalSeconds)
           {
            m_lastStatsPrint = TimeCurrent();
            PmLogAlways(m_stats.Report());
           }
        }

      //--- risk layer
      bool riskOk = m_risk.Check(m_stats.CurrentConsecutiveLosses());
      if(!riskOk)
        {
         if(m_pendingTicket != 0)
            DeleteCurrentPending("risk halt: " + m_risk.HaltReason());
         if(m_posTicket != 0)
           {
            if(CloseAllOnHalt)
               ClosePositionNow(PM_EXIT_EMERGENCY, "risk halt");
            else
               ManagePosition();
           }
         UpdateDashboard();
         return;
        }

      //--- an open position is managed before anything else
      if(m_posTicket != 0)
        {
         ManagePosition();

         //--- optional immediate reversal (disabled by default)
         if(AllowImmediateReverse && m_posTicket != 0)
           {
            ENUM_MOMENTUM_DIR dir = m_mom.Direction();
            if((m_posIsBuy && dir == MOM_SELL) || (!m_posIsBuy && dir == MOM_BUY))
               ClosePositionNow(PM_EXIT_REVERSAL, "immediate reverse requested");
           }

         UpdateDashboard();
         return;
        }

      //--- pending management
      if(m_pendingTicket != 0)
        {
         ManagePending();
         UpdateDashboard();
         return;
        }

      //--- new entries
      if(EnableTrading && !InCooldown() && m_mom.IsReady())
        {
         ENUM_MOMENTUM_DIR dir = m_mom.Direction();
         if(dir == MOM_BUY || dir == MOM_SELL)
           {
            if(MaxPendingOrders > 0)
               PlacePending(dir == MOM_BUY);
           }
        }

      UpdateDashboard();
     }

   void              OnTransaction(const MqlTradeTransaction &trans)
     {
      if(trans.symbol != m_sym.name) return;
      if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
      if(!HistoryDealSelect(trans.deal)) return;
      if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != (long)MagicNumber) return;

      long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      double price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
      if(entry == DEAL_ENTRY_IN)
         PmLog(StringFormat("Deal IN  #%I64u at %s", trans.deal, DoubleToString(price, m_sym.digits)));
      else
         PmLog(StringFormat("Deal OUT #%I64u at %s", trans.deal, DoubleToString(price, m_sym.digits)));
     }

   void              StatsRebuild(void) { m_stats.Rebuild(); }
   string            StatsReport(void) { return m_stats.Report(); }
   double            StatsExpectancy(void) { return m_stats.Expectancy(); }
   double            StatsProfitFactor(void) { return m_stats.ProfitFactor(); }
   double            StatsMaxDrawdown(void) { return m_stats.MaxDrawdown(); }
   double            StatsNetProfit(void) { return m_stats.NetProfit(); }
   int               StatsTrades(void) { return m_stats.TotalTrades(); }
  };

//+------------------------------------------------------------------+
//| Global instance and MT5 event handlers                           |
//+------------------------------------------------------------------+
CPeakMomentumEA g_ea;

int OnInit()
  {
   if(!g_ea.Init())
      return INIT_FAILED;

   if(TimerMilliseconds > 0)
      EventSetMillisecondTimer(TimerMilliseconds);

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_ea.Deinit(reason);
  }

void OnTick()
  {
   g_ea.Process();
  }

void OnTimer()
  {
   //--- keeps pending timeouts, trailing and the dashboard alive between ticks
   g_ea.Process();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   g_ea.OnTransaction(trans);
  }

double OnTester()
  {
   //--- custom optimisation criterion: reward expectancy and profit factor,
   //--- punish drawdown. Deliberately NOT the raw net profit.
   g_ea.StatsRebuild();          // OnTester runs before OnDeinit, so refresh first
   double trades = (double)g_ea.StatsTrades();
   if(trades < 10.0) return 0.0;

   double net = g_ea.StatsNetProfit();
   double pf  = g_ea.StatsProfitFactor();
   if(pf == DBL_MAX) pf = 10.0;
   double dd  = g_ea.StatsMaxDrawdown();
   double exp = g_ea.StatsExpectancy();

   if(net <= 0.0 || exp <= 0.0) return 0.0;
   return net * MathMin(pf, 10.0) / (1.0 + dd);
  }
//+------------------------------------------------------------------+
