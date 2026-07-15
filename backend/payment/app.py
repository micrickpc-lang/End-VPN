import base64
import json
import os
import random
import re
import sqlite3
import string
import threading
import time
import urllib.error
import urllib.request
import uuid
from collections import deque
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


SHOP_ID = os.environ["YOOKASSA_SHOP_ID"]
SECRET_KEY = os.environ["YOOKASSA_SECRET_KEY"]
REMNAWAVE_URL = os.environ["REMNAWAVE_URL"].rstrip("/")
REMNAWAVE_TOKEN = os.environ["REMNAWAVE_TOKEN"]
DEFAULT_SQUAD_UUID = os.environ["DEFAULT_SQUAD_UUID"]
RETURN_URL = os.getenv("PAYMENT_RETURN_URL", "endvpn://payment/success")
DB_PATH = os.getenv("PAYMENT_DB_PATH", "/data/payments.sqlite3")
PORT = int(os.getenv("PORT", "8080"))

# "CODE1:365,CODE2:30" -> {"CODE1": 365, "CODE2": 30}
PROMO_CODES = {
    pair.split(":")[0].strip().upper(): int(pair.split(":")[1])
    for pair in os.getenv("PROMO_CODES", "").split(",")
    if ":" in pair
}

FREE_TRAFFIC_LIMIT_BYTES = 15 * 1024 * 1024 * 1024
FREE_TRAFFIC_STRATEGY = "MONTH"

PLANS = {
    "1m": (224, 30, "1 месяц"),
    "3m": (566, 90, "3 месяца"),
    "6m": (1079, 180, "6 месяцев"),
    "12m": (1979, 365, "1 год"),
}
UUID_RE = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
)
APPLY_LOCK = threading.Lock()

RATE_LOCK = threading.Lock()
RATE_BUCKETS = {}
RATE_LIMIT = int(os.getenv("APP_RATE_LIMIT", "30"))
RATE_WINDOW = 60.0


def rate_allow(ip):
    now = time.monotonic()
    with RATE_LOCK:
        bucket = RATE_BUCKETS.setdefault(ip, deque())
        while bucket and now - bucket[0] > RATE_WINDOW:
            bucket.popleft()
        if len(bucket) >= RATE_LIMIT:
            return False
        bucket.append(now)
        if len(RATE_BUCKETS) > 10000:
            for key in [k for k, v in RATE_BUCKETS.items() if not v]:
                del RATE_BUCKETS[key]
        return True


def db():
    connection = sqlite3.connect(DB_PATH, timeout=30)
    connection.execute("PRAGMA journal_mode=WAL")
    connection.execute("PRAGMA busy_timeout=30000")
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS payments (
            payment_id TEXT PRIMARY KEY,
            device_uuid TEXT NOT NULL,
            plan_id TEXT NOT NULL,
            days INTEGER NOT NULL,
            amount INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            applied INTEGER NOT NULL DEFAULT 0,
            sub_url TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    connection.commit()
    return connection


def api_json(method, url, payload=None, headers=None, timeout=20):
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    request_headers = {"Accept": "application/json"}
    if payload is not None:
        request_headers["Content-Type"] = "application/json"
    if headers:
        request_headers.update(headers)
    request = urllib.request.Request(
        url, data=body, headers=request_headers, method=method
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")[:1000]
        raise RuntimeError(f"Upstream HTTP {error.code}: {detail}") from error


def yookassa(method, path, payload=None, idempotence_key=None):
    credentials = base64.b64encode(f"{SHOP_ID}:{SECRET_KEY}".encode()).decode()
    headers = {"Authorization": f"Basic {credentials}"}
    if idempotence_key:
        headers["Idempotence-Key"] = idempotence_key
    return api_json(
        method,
        f"https://api.yookassa.ru/v3{path}",
        payload=payload,
        headers=headers,
    )


def unwrap(data):
    if isinstance(data, dict):
        for key in ("response", "data", "user"):
            if isinstance(data.get(key), dict):
                return data[key]
    return data if isinstance(data, dict) else {}


def remnawave(method, path, payload=None):
    return unwrap(
        api_json(
            method,
            f"{REMNAWAVE_URL}{path}",
            payload=payload,
            headers={"Authorization": f"Bearer {REMNAWAVE_TOKEN}"},
        )
    )


def parse_date(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def subscription_url(user):
    for key in ("subscriptionUrl", "subUrl", "sub_url", "subscription_url"):
        value = user.get(key)
        if isinstance(value, str) and value:
            return value
    short_uuid = user.get("shortUuid") or user.get("short_uuid")
    return f"{REMNAWAVE_URL}/sub/{short_uuid}" if short_uuid else ""


def apply_payment(payment_id, device_uuid, days):
    with APPLY_LOCK:
        connection = db()
        row = connection.execute(
            "SELECT applied, sub_url FROM payments WHERE payment_id = ?",
            (payment_id,),
        ).fetchone()
        if row and row[0]:
            connection.close()
            return row[1]

        current = remnawave("GET", f"/api/users/{device_uuid}")
        now = datetime.now(timezone.utc)
        current_expiry = parse_date(current.get("expireAt"))
        base = current_expiry if current_expiry and current_expiry > now else now
        expiry = (base + timedelta(days=days)).isoformat().replace("+00:00", "Z")
        updated = remnawave(
            "PATCH",
            "/api/users",
            {
                "uuid": device_uuid,
                "expireAt": expiry,
                "trafficLimitBytes": 0,
                "trafficLimitStrategy": "NO_RESET",
                "status": "ACTIVE",
                "activeInternalSquads": [DEFAULT_SQUAD_UUID],
            },
        )
        url = subscription_url(updated) or subscription_url(current)
        connection.execute(
            """
            UPDATE payments
            SET applied = 1, status = 'succeeded', sub_url = ?, updated_at = CURRENT_TIMESTAMP
            WHERE payment_id = ?
            """,
            (url, payment_id),
        )
        connection.commit()
        connection.close()
        return url


def pick_user(user):
    return {
        "uuid": user.get("uuid", ""),
        "username": user.get("username", ""),
        "status": user.get("status", ""),
        "expireAt": user.get("expireAt"),
        "trafficLimitBytes": user.get("trafficLimitBytes", 0),
        "userTraffic": user.get("userTraffic") or {},
        "subscriptionUrl": subscription_url(user),
        "description": user.get("description", ""),
    }


def has_default_squad(user):
    for squad in user.get("activeInternalSquads") or []:
        if squad == DEFAULT_SQUAD_UUID:
            return True
        if isinstance(squad, dict) and squad.get("uuid") == DEFAULT_SQUAD_UUID:
            return True
    return False


def repair_user(user):
    device_uuid = user.get("uuid", "")
    if not device_uuid:
        return user
    limit = int(user.get("trafficLimitBytes") or 0)
    strategy = user.get("trafficLimitStrategy")
    needs_free_repair = limit > 0 and (
        limit != FREE_TRAFFIC_LIMIT_BYTES or strategy != FREE_TRAFFIC_STRATEGY
    )
    if has_default_squad(user) and not needs_free_repair:
        return user
    patch = {"uuid": device_uuid}
    if not has_default_squad(user):
        patch["activeInternalSquads"] = [DEFAULT_SQUAD_UUID]
    if needs_free_repair:
        patch["trafficLimitBytes"] = FREE_TRAFFIC_LIMIT_BYTES
        patch["trafficLimitStrategy"] = FREE_TRAFFIC_STRATEGY
    patched = remnawave("PATCH", "/api/users", patch)
    return patched or user


def create_remnawave_user(username, days, telegram_id=None):
    expire_at = (
        (datetime.now(timezone.utc) + timedelta(days=days))
        .isoformat()
        .replace("+00:00", "Z")
    )
    body = {
        "username": username,
        "expireAt": expire_at,
        "trafficLimitBytes": FREE_TRAFFIC_LIMIT_BYTES,
        "trafficLimitStrategy": FREE_TRAFFIC_STRATEGY,
        "status": "ACTIVE",
        "hwidDeviceLimit": 2,
        "description": "clicks:0",
        "activeInternalSquads": [DEFAULT_SQUAD_UUID],
    }
    if telegram_id is not None:
        body["telegramId"] = telegram_id
    return remnawave("POST", "/api/users", body)


def find_user_by_telegram_id(tg_id):
    try:
        raw = remnawave("GET", f"/api/users?telegramId={tg_id}")
        users = raw.get("users")
        if isinstance(users, list) and users:
            return users[0]
    except RuntimeError:
        pass

    page = 1
    limit = 100
    while True:
        raw = remnawave(
            "GET", f"/api/users?limit={limit}&offset={(page - 1) * limit}"
        )
        users = raw.get("users") or []
        total = int(raw.get("total") or 0)
        for user in users:
            if user.get("telegramId") == tg_id:
                return user
        if len(users) < limit or page * limit >= total:
            return None
        page += 1


class Handler(BaseHTTPRequestHandler):
    server_version = "EndVPNPayment/1.0"

    def log_message(self, _format, *_args):
        return

    def send_json(self, status, payload):
        raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def read_json(self):
        length = min(int(self.headers.get("Content-Length", "0")), 16384)
        return json.loads(self.rfile.read(length) or b"{}")

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"ok": True})
            return
        if self.path.startswith("/app/user/"):
            if not rate_allow(self.client_address[0]):
                self.send_json(429, {"ok": False, "error": "Too many requests"})
                return
            try:
                self.app_get_user(self.path[len("/app/user/"):])
            except Exception:
                self.send_json(502, {"ok": False, "error": "Upstream unavailable"})
            return
        if self.path.startswith("/return"):
            raw = (
                "<!doctype html><meta charset=utf-8><meta name=viewport "
                "content='width=device-width,initial-scale=1'><title>End VPN</title>"
                "<style>body{background:#080b10;color:#eee;font:18px sans-serif;"
                "display:grid;place-items:center;height:100vh;margin:0;text-align:center}"
                "a{color:#ef334f}</style><main><h2>Оплата обрабатывается</h2>"
                "<p>Вернитесь в End VPN — подписка активируется автоматически.</p>"
                "<a href='endvpn://payment/success'>Открыть End VPN</a></main>"
            ).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
            return
        self.send_json(404, {"ok": False, "error": "Not found"})

    def do_POST(self):
        try:
            payload = self.read_json()
            if self.path == "/create":
                self.create_payment(payload)
            elif self.path == "/check":
                self.check_payment(payload)
            elif self.path.startswith("/app/"):
                if not rate_allow(self.client_address[0]):
                    self.send_json(429, {"ok": False, "error": "Too many requests"})
                    return
                if self.path == "/app/anon":
                    self.app_create_anon()
                elif self.path == "/app/tg":
                    self.app_tg_user(payload)
                elif self.path == "/app/clicks":
                    self.app_save_clicks(payload)
                elif self.path == "/app/promo":
                    self.app_apply_promo(payload)
                else:
                    self.send_json(404, {"ok": False, "error": "Not found"})
            else:
                self.send_json(404, {"ok": False, "error": "Not found"})
        except (ValueError, json.JSONDecodeError):
            self.send_json(400, {"ok": False, "error": "Invalid request"})
        except Exception:
            self.send_json(502, {"ok": False, "error": "Payment service unavailable"})

    def app_get_user(self, device_uuid):
        if not UUID_RE.fullmatch(device_uuid):
            self.send_json(400, {"ok": False, "error": "Invalid uuid"})
            return
        try:
            user = remnawave("GET", f"/api/users/{device_uuid}")
        except RuntimeError as error:
            if "HTTP 404" in str(error):
                self.send_json(404, {"ok": False, "error": "User not found"})
                return
            raise
        if not user.get("uuid"):
            self.send_json(404, {"ok": False, "error": "User not found"})
            return
        user = repair_user(user)
        self.send_json(200, {"ok": True, "user": pick_user(user)})

    def app_create_anon(self):
        suffix = "".join(
            random.choices(string.ascii_lowercase + string.digits, k=8)
        )
        user = create_remnawave_user(f"anon_{suffix}", days=36500)
        self.send_json(200, {"ok": True, "user": pick_user(user)})

    def app_tg_user(self, payload):
        tg_id = payload.get("tg_id")
        if not isinstance(tg_id, int) or tg_id <= 0:
            self.send_json(400, {"ok": False, "error": "Invalid tg_id"})
            return
        user = find_user_by_telegram_id(tg_id)
        if user is None:
            username = f"tg{tg_id}_{int(time.time())}"
            user = create_remnawave_user(username, days=3, telegram_id=tg_id)
        else:
            user = repair_user(user)
        self.send_json(200, {"ok": True, "user": pick_user(user)})

    def app_save_clicks(self, payload):
        device_uuid = str(payload.get("uuid", ""))
        clicks = payload.get("clicks")
        if not UUID_RE.fullmatch(device_uuid) or not isinstance(clicks, int):
            self.send_json(400, {"ok": False, "error": "Invalid request"})
            return
        clicks = max(0, min(clicks, 10**9))
        remnawave(
            "PATCH",
            "/api/users",
            {"uuid": device_uuid, "description": f"clicks:{clicks}"},
        )
        self.send_json(200, {"ok": True})

    def app_apply_promo(self, payload):
        device_uuid = str(payload.get("uuid", ""))
        code = str(payload.get("code", "")).strip().upper()
        if not UUID_RE.fullmatch(device_uuid) or not code:
            self.send_json(400, {"ok": False, "error": "Invalid request"})
            return
        days = PROMO_CODES.get(code)
        if days is None:
            self.send_json(404, {"ok": False, "error": "Invalid promo code"})
            return
        current = remnawave("GET", f"/api/users/{device_uuid}")
        now = datetime.now(timezone.utc)
        current_expiry = parse_date(current.get("expireAt"))
        base = current_expiry if current_expiry and current_expiry > now else now
        expiry = (base + timedelta(days=days)).isoformat().replace("+00:00", "Z")
        updated = remnawave(
            "PATCH",
            "/api/users",
            {
                "uuid": device_uuid,
                "expireAt": expiry,
                "trafficLimitBytes": 0,
                "trafficLimitStrategy": "NO_RESET",
                "status": "ACTIVE",
                "description": current.get("description", "clicks:0"),
                "activeInternalSquads": [DEFAULT_SQUAD_UUID],
            },
        )
        self.send_json(200, {"ok": True, "user": pick_user(updated or current)})

    def create_payment(self, payload):
        device_uuid = str(payload.get("device_uuid", ""))
        plan_id = str(payload.get("plan_id", ""))
        if not UUID_RE.fullmatch(device_uuid) or plan_id not in PLANS:
            self.send_json(400, {"ok": False, "error": "Invalid user or plan"})
            return
        amount, days, title = PLANS[plan_id]
        payment = yookassa(
            "POST",
            "/payments",
            {
                "amount": {"value": f"{amount:.2f}", "currency": "RUB"},
                "capture": True,
                "confirmation": {"type": "redirect", "return_url": RETURN_URL},
                "description": f"End VPN — {title}",
                "metadata": {
                    "device_uuid": device_uuid,
                    "plan_id": plan_id,
                    "days": str(days),
                },
            },
            idempotence_key=str(uuid.uuid4()),
        )
        payment_id = str(payment.get("id", ""))
        confirmation_url = str((payment.get("confirmation") or {}).get("confirmation_url", ""))
        if not payment_id or not confirmation_url:
            raise RuntimeError("YooKassa returned no confirmation URL")
        connection = db()
        connection.execute(
            """
            INSERT OR REPLACE INTO payments
            (payment_id, device_uuid, plan_id, days, amount, status)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (payment_id, device_uuid, plan_id, days, amount, payment.get("status", "pending")),
        )
        connection.commit()
        connection.close()
        self.send_json(
            200,
            {"ok": True, "payment_id": payment_id, "url": confirmation_url},
        )

    def check_payment(self, payload):
        payment_id = str(payload.get("payment_id", ""))
        device_uuid = str(payload.get("device_uuid", ""))
        if not payment_id or not UUID_RE.fullmatch(device_uuid):
            self.send_json(400, {"ok": False, "error": "Invalid payment"})
            return
        connection = db()
        row = connection.execute(
            "SELECT device_uuid, days, applied, sub_url FROM payments WHERE payment_id = ?",
            (payment_id,),
        ).fetchone()
        connection.close()
        if not row or row[0] != device_uuid:
            self.send_json(404, {"ok": False, "error": "Payment not found"})
            return
        payment = yookassa("GET", f"/payments/{payment_id}")
        status = str(payment.get("status", "pending"))
        url = row[3]
        if status == "succeeded" and not row[2]:
            url = apply_payment(payment_id, device_uuid, row[1])
        elif status == "canceled":
            connection = db()
            connection.execute(
                "UPDATE payments SET status = 'canceled', updated_at = CURRENT_TIMESTAMP WHERE payment_id = ?",
                (payment_id,),
            )
            connection.commit()
            connection.close()
        self.send_json(200, {"ok": True, "status": status, "sub_url": url})


if __name__ == "__main__":
    db().close()
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
