"""
BWTraders MT5 Connector
-----------------------
API bridge between the BWTraders AI backend and an MT5 terminal/EA.

IMPORTANT:
- This service runs as an API server.
- Render cannot directly run the MetaTrader 5 desktop terminal.
- An MT5 Expert Advisor/local bridge will later communicate with this API.
- Default mode is DEMO for safety.
"""

import os
import time
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


# ============================================================
# CONFIGURATION
# ============================================================

APP_NAME = "BWTraders MT5 Connector"
MODEL_NAME = "BW-AI-001"

MODE = os.getenv("BWTRADERS_MODE", "DEMO").upper()
API_KEY = os.getenv("BWTRADERS_API_KEY", "")

START_TIME = time.time()


# ============================================================
# APP
# ============================================================

app = FastAPI(
    title=APP_NAME,
    description="BWTraders AI ↔ MT5 communication bridge",
    version="1.0.0",
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# DATA MODELS
# ============================================================

class MarketData(BaseModel):
    symbol: str = Field(..., min_length=1)
    timeframe: str = "M5"

    bid: Optional[float] = None
    ask: Optional[float] = None
    price: Optional[float] = None

    open: Optional[float] = None
    high: Optional[float] = None
    low: Optional[float] = None
    close: Optional[float] = None

    volume: Optional[float] = None

    timestamp: Optional[str] = None


class SignalRequest(BaseModel):
    symbol: str
    timeframe: str = "M5"

    trend: Optional[str] = None
    signal: Optional[str] = None

    confidence: float = Field(
        default=0.0,
        ge=0.0,
        le=100.0
    )

    price: Optional[float] = None


class TradeRequest(BaseModel):
    symbol: str
    action: str
    volume: float = Field(..., gt=0)

    price: Optional[float] = None
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None

    comment: str = "BWTraders"


class AccountData(BaseModel):
    balance: Optional[float] = None
    equity: Optional[float] = None
    margin: Optional[float] = None
    free_margin: Optional[float] = None
    currency: Optional[str] = None

    login: Optional[str] = None
    server: Optional[str] = None


# ============================================================
# SECURITY
# ============================================================

def check_api_key(
    authorization: Optional[str],
    x_api_key: Optional[str]
):
    """
    If BWTRADERS_API_KEY is configured, clients must provide it.

    Accepted formats:
      X-API-Key: YOUR_KEY

    or:

      Authorization: Bearer YOUR_KEY
    """

    # During initial setup, allow requests if no key has been configured.
    if not API_KEY:
        return

    supplied_key = x_api_key

    if not supplied_key and authorization:
        if authorization.lower().startswith("bearer "):
            supplied_key = authorization[7:].strip()

    if supplied_key != API_KEY:
        raise HTTPException(
            status_code=401,
            detail="Invalid or missing BWTraders API key."
        )


# ============================================================
# ROOT
# ============================================================

@app.get("/")
def root() -> Dict[str, Any]:
    return {
        "message": "BWTraders MT5 Connector is running",
        "name": APP_NAME,
        "model": MODEL_NAME,
        "mode": MODE,
        "status": "ONLINE",
        "version": "1.0.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


# ============================================================
# HEALTH CHECK
# ============================================================

@app.get("/health")
def health() -> Dict[str, Any]:
    return {
        "status": "healthy",
        "service": APP_NAME,
        "mode": MODE,
        "uptime_seconds": round(time.time() - START_TIME, 2),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


# ============================================================
# MT5 CONNECTION STATUS
# ============================================================

@app.get("/mt5/status")
def mt5_status(
    authorization: Optional[str] = Header(default=None),
    x_api_key: Optional[str] = Header(default=None)
):
    check_api_key(authorization, x_api_key)

    return {
        "connected": False,
        "mode": MODE,
        "message": (
            "Waiting for the MT5 Expert Advisor/local bridge."
        ),
        "note": (
            "The Render API does not run the MT5 desktop terminal."
        ),
    }


# ============================================================
# RECEIVE MARKET DATA
# ============================================================

@app.post("/mt5/market")
def receive_market_data(
    data: MarketData,
    authorization: Optional[str] = Header(default=None),
    x_api_key: Optional[str] = Header(default=None)
):
    check_api_key(authorization, x_api_key)

    return {
        "success": True,
        "received": True,
        "symbol": data.symbol.upper(),
        "timeframe": data.timeframe.upper(),
        "price": data.price,
        "bid": data.bid,
        "ask": data.ask,
        "timestamp": data.timestamp,
        "server_timestamp": datetime.now(
            timezone.utc
        ).isoformat(),
    }


# ============================================================
# RECEIVE AI SIGNAL
# ============================================================

@app.post("/mt5/signal")
def receive_signal(
    data: SignalRequest,
    authorization: Optional[str] = Header(default=None),
    x_api_key: Optional[str] = Header(default=None)
):
    check_api_key(authorization, x_api_key)

    signal = (data.signal or "NONE").upper()

    return {
        "success": True,
        "symbol": data.symbol.upper(),
        "timeframe": data.timeframe.upper(),
        "signal": signal,
        "trend": data.trend,
        "confidence": data.confidence,
        "price": data.price,
        "mode": MODE,
        "timestamp": datetime.now(
            timezone.utc
        ).isoformat(),
    }


# ============================================================
# TRADE REQUEST
# ============================================================

@app.post("/mt5/trade")
def trade_request(
    data: TradeRequest,
    authorization: Optional[str] = Header(default=None),
    x_api_key: Optional[str] = Header(default=None)
):
    check_api_key(authorization, x_api_key)

    action = data.action.upper()

    allowed_actions = {
        "BUY",
        "SELL",
        "CLOSE",
        "CLOSE_ALL"
    }

    if action not in allowed_actions:
        raise HTTPException(
            status_code=400,
            detail=(
                "Invalid action. Use BUY, SELL, "
                "CLOSE or CLOSE_ALL."
            )
        )

    # Safety: the initial connector is DEMO only.
    if MODE != "LIVE":
        return {
            "success": True,
            "executed": False,
            "mode": "DEMO",
            "action": action,
            "symbol": data.symbol.upper(),
            "volume": data.volume,
            "message": (
                "Demo mode: trade request accepted "
                "but no real order was sent."
            ),
        }

    # LIVE execution will be implemented through
    # the MT5 Expert Advisor/local bridge.
    return {
        "success": True,
        "executed": False,
        "mode": "LIVE",
        "action": action,
        "symbol": data.symbol.upper(),
        "volume": data.volume,
        "message": (
            "LIVE mode requires the connected MT5 bridge."
        ),
    }


# ============================================================
# ACCOUNT INFORMATION
# ============================================================

@app.post("/mt5/account")
def receive_account_data(
    data: AccountData,
    authorization: Optional[str] = Header(default=None),
    x_api_key: Optional[str] = Header(default=None)
):
    check_api_key(authorization, x_api_key)

    return {
        "success": True,
        "account": {
            "balance": data.balance,
            "equity": data.equity,
            "margin": data.margin,
            "free_margin": data.free_margin,
            "currency": data.currency,
            "login": data.login,
            "server": data.server,
        },
        "timestamp": datetime.now(
            timezone.utc
        ).isoformat(),
    }


# ============================================================
# AI COMMAND
# ============================================================

@app.get("/mt5/command")
def get_command(
    authorization: Optional[str] = Header(default=None),
    x_api_key: Optional[str] = Header(default=None)
):
    check_api_key(authorization, x_api_key)

    return {
        "command": "WAIT",
        "symbol": None,
        "action": None,
        "volume": None,
        "stop_loss": None,
        "take_profit": None,
        "reason": "No trading command available.",
        "mode": MODE,
        "timestamp": datetime.now(
            timezone.utc
        ).isoformat(),
    }


# ============================================================
# SYSTEM INFORMATION
# ============================================================

@app.get("/info")
def info() -> Dict[str, Any]:
    return {
        "project": "BWTraders",
        "service": APP_NAME,
        "model": MODEL_NAME,
        "mode": MODE,
        "api_version": "1.0.0",
        "status": "ONLINE",
        "timeframes": {
            "trend": "H1",
            "setup": "M15",
            "entry": "M5"
        },
        "markets": [
            "EURUSD",
            "XAUUSD"
        ],
}
@app.get("/debug/auth")
def debug_auth():
    return {
        "api_key_configured": bool(API_KEY),
        "mode": MODE,
        "status": "OK"
    }
