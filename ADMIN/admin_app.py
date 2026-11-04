"""Admin UI backed by the shared Firestore tournament service."""

import secrets
import threading
import webbrowser
import os
from pathlib import Path
import sys
from types import SimpleNamespace

from dotenv import load_dotenv
from flask import Flask, abort, jsonify, redirect, render_template, request, session, url_for
from werkzeug.datastructures import MultiDict


ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = ROOT / "backend"
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

load_dotenv(BACKEND_DIR / ".env")

from app.core.firestore import get_db, get_storage_bucket
from app.services.admin_service import (
    AdminOperationError,
    PlayerNotFound,
    approve_tournament_results,
    clear_settled_withdrawals,
    credit_wallet as credit_player_wallet,
    deduct_wallet,
    delete_settled_withdrawal,
    find_player,
    get_maintenance,
    list_holds,
    list_wallet_credits,
    list_withdrawals,
    player_account_details,
    save_tournament_results,
    settle_withdrawal,
    set_account_hold,
    tournament_result_rows,
    update_maintenance,
)
from app.services.notification_service import (
    NotificationInputError,
    clear_admin_notification_history,
    enabled_device_count,
    notify_users,
    recent_admin_notifications,
    user_ids,
)
from app.services.settings_service import (
    get_add_money_method,
    get_settings,
    save_add_money_method,
)
from app.services.tournament_service import (
    TournamentInputError,
    create_from_default,
    create_tournament,
    dashboard_counts,
    delete_default,
    delete_tournament,
    list_joined_players,
    list_defaults,
    list_tournaments,
    save_room_details,
)


app = Flask(
    __name__,
    template_folder=str(Path(__file__).resolve().parent / "templates"),
    static_folder=str(Path(__file__).resolve().parent / "static"),
    static_url_path="/admin-static",
)
app.secret_key = os.environ.get("ADMIN_SESSION_SECRET") or secrets.token_hex(32)
app.config.update(
    FIREBASE_PROJECT_ID=os.environ.get("FIREBASE_PROJECT_ID", "ravilon-19a47"),
    FIREBASE_CREDENTIALS=os.environ.get("FIREBASE_CREDENTIALS", ""),
    STORAGE_BUCKET=os.environ.get("STORAGE_BUCKET", ""),
    MAX_CONTENT_LENGTH=5 * 1024 * 1024,
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
    SESSION_COOKIE_SECURE=os.environ.get("ADMIN_COOKIE_SECURE", "").lower()
    in {"1", "true", "yes"},
)
ADMIN_URL = "http://127.0.0.1:5001/"


@app.before_request
def require_admin_login():
    if request.endpoint in {"login", "static"}:
        return None
    if not session.get("admin_authenticated"):
        return redirect(url_for("login"))
    if request.method == "POST":
        supplied = request.headers.get("X-CSRF") or request.form.get("csrf", "")
        expected = session.get("csrf", "")
        if not expected or not secrets.compare_digest(supplied, expected):
            abort(400)
    return None


@app.context_processor
def inject_csrf_token():
    def csrf_token():
        return session.setdefault("csrf", secrets.token_urlsafe(32))

    return {"csrf_token": csrf_token}


def obj(**values):
    return SimpleNamespace(**values)


def demo_tournament(identifier="demo-1", status="upcoming", loot=False):
    return obj(
        id=identifier,
        mode="BR Ranked Solo",
        name="BR Ranked Solo",
        team="Solo",
        map="Bermuda",
        prize=1200,
        fee=50 if not loot else 0,
        per_kill=10,
        slots=48,
        joined=24,
        duration_min=25,
        when="Today, 6:30 PM",
        status=status,
        loot=loot,
        room_id="",
        room_pass="",
    )


def render_page(template, active, **context):
    page_context = {
        "active": active,
        "dp_pending": 0,
        "wd_pending": 0,
        "holds_count": 0,
        **context,
    }
    return render_template(
        template,
        **page_context,
    )


@app.template_filter("inr")
def inr(value):
    try:
        return f"{int(value):,}"
    except (TypeError, ValueError):
        return "0"


@app.route("/", methods=["GET", "POST"])
def login():
    error = ""
    csrf = session.setdefault("csrf", secrets.token_urlsafe(32))
    if request.method == "POST":
        supplied = request.form.get("csrf", "")
        if not secrets.compare_digest(supplied, csrf):
            abort(400)
        expected = os.environ.get("ADMIN_PASSWORD", "")
        if not expected:
            error = "Admin password is not configured in backend/.env."
        elif secrets.compare_digest(request.form.get("password", ""), expected):
            session["admin_authenticated"] = True
            return redirect(url_for("dashboard"))
        else:
            error = "Incorrect password."
    return render_template(
        "login.html",
        error=error,
    )


@app.get("/dashboard")
def dashboard():
    return render_page("dashboard.html", "dashboard", c=obj(**dashboard_counts()))


@app.get("/accounts")
def accounts():
    return render_page(
        "incomplete.html",
        "accounts",
        heading="Accounts",
        message="Real account analytics are not connected yet.",
    )


@app.get("/tournaments")
def tournaments():
    return render_page(
        "tournaments.html",
        "tournaments",
        items=list_tournaments(),
    )


@app.get("/defaults")
def defaults():
    return render_page("defaults.html", "defaults", items=list_defaults())


@app.route("/loot", methods=["GET", "POST"])
def loot():
    form = request.form if request.method == "POST" else MultiDict()
    error = ""
    if request.method == "POST":
        try:
            create_tournament(
                _tournament_form(form, loot=True),
                save_as_default=form.get("save_default") == "1",
                banner_file=request.files.get("banner"),
            )
            return redirect(url_for("loot"))
        except TournamentInputError as exception:
            error = str(exception)
    return render_page(
        "loot_tournaments.html",
        "loot",
        defaults=list_defaults(loot=True),
        f=form,
        images=_image_options(),
        items=[item for item in list_tournaments() if item["loot"]],
        error=error,
    )


@app.get("/deposits")
def deposits():
    return render_page(
        "incomplete.html",
        "deposits",
        heading="Approve amount",
        message="Deposit approval is not connected yet. No payment requests are shown here.",
    )


@app.get("/withdrawals")
def withdrawals():
    items = list_withdrawals()
    return render_page(
        "withdrawals.html",
        "withdrawals",
        items=items,
        wd_pending=sum(item["status"] == "pending" for item in items),
    )


@app.get("/wallet-credit")
def wallet_credit():
    return render_page(
        "wallet_credit.html",
        "wallet_credit",
        items=list_wallet_credits(),
    )


@app.get("/payment-methods")
def payment_methods():
    settings = get_settings()
    return render_page(
        "payment_methods.html",
        "payment_methods",
        method=get_add_money_method(settings),
    )


@app.post("/payment-methods/save")
def payment_methods_save():
    body, error = _admin_json_body()
    if error:
        return error
    method = body.get("method")
    if not isinstance(method, str) or method not in {"gateway", "off"}:
        return jsonify(
            {"ok": False, "error": "Choose Gateway or Off."}
        ), 400
    result = save_add_money_method(method)
    return jsonify({"ok": True, **result}), 200


@app.get("/holds")
def holds():
    items = list_holds()
    return render_page(
        "holds.html",
        "holds",
        items=items,
        holds_count=len(items),
    )


@app.get("/maintenance")
def maintenance():
    settings = get_maintenance()
    return render_page(
        "maintenance.html",
        "maintenance",
        m=obj(
            on=settings["on"],
            message=settings["message"],
            eta=settings["eta"],
        ),
    )


@app.get("/notify")
def notify():
    return render_page(
        "notify.html",
        "notify",
        devices=enabled_device_count(),
        items=recent_admin_notifications(),
    )


@app.get("/check-edit")
def check_edit():
    return render_page("check_edit.html", "check_edit")


@app.post("/check-edit/find")
def check_edit_find():
    body, error = _admin_json_body()
    if error:
        return error
    try:
        return jsonify({"ok": True, **find_player(_string_field(body, "query"))})
    except PlayerNotFound as exception:
        return jsonify({"ok": False, "error": str(exception)}), 404


@app.post("/check-edit/details")
def check_edit_details():
    body, error = _admin_json_body()
    if error:
        return error
    try:
        return jsonify(
            {"ok": True, **player_account_details(_string_field(body, "uid"))}
        )
    except PlayerNotFound as exception:
        return jsonify({"ok": False, "error": str(exception)}), 404


@app.post("/check-edit/deduct")
def check_edit_deduct():
    body, error = _admin_json_body()
    if error:
        return error
    amount = _whole_rupees(body.get("amount"))
    if amount is None or amount < 1:
        return jsonify(
            {"ok": False, "error": "Enter a whole-rupee amount of at least 1."}
        ), 400
    try:
        player = find_player(_string_field(body, "uid"))
        result = deduct_wallet(
            player["uid"],
            amount,
            _string_field(body, "bucket"),
            _string_field(body, "reason"),
        )
    except (PlayerNotFound, AdminOperationError) as exception:
        return jsonify({"ok": False, "error": str(exception)}), 400
    return jsonify(
        {
            "ok": True,
            "total": result["total"],
            "notified": result["notificationStatus"],
        }
    ), 200


@app.route("/tournaments/new", methods=["GET", "POST"])
def tournament_new():
    form = request.form if request.method == "POST" else MultiDict()
    error = ""
    if request.method == "POST":
        try:
            create_tournament(
                _tournament_form(form, loot=False),
                save_as_default=form.get("save_default") == "1",
                banner_file=request.files.get("banner"),
            )
            return redirect(url_for("tournaments"))
        except TournamentInputError as exception:
            error = str(exception)
    return render_page(
        "tournament_form.html",
        "tournaments",
        f=form,
        images=_image_options(),
        error=error,
    )


@app.post("/tournaments/from-default/<default_id>")
@app.post("/loot/from-default/<default_id>")
def tournament_from_default(default_id):
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return jsonify(ok=False, error="Choose a start date and time."), 400
    try:
        create_from_default(default_id, body.get("start"))
    except TournamentInputError as exception:
        return jsonify(ok=False, error=str(exception)), 400
    return jsonify(ok=True), 201


@app.post("/tournaments/default/<default_id>/delete")
@app.post("/loot/default/<default_id>/delete")
def tournament_default_delete(default_id):
    delete_default(default_id)
    return jsonify(ok=True), 200


@app.get("/tournaments/<tid>/players")
def tournament_players(tid):
    tournament, rows = list_joined_players(tid)
    if tournament is None:
        abort(404)
    return render_page(
        "tournament_players.html",
        "tournaments",
        c=obj(t=obj(**tournament), rows=[obj(**row) for row in rows]),
    )


@app.post("/tournaments/<tid>/delete")
def tournament_delete(tid):
    try:
        delete_tournament(tid)
    except TournamentInputError as exception:
        return render_page(
            "tournaments.html",
            "tournaments",
            items=list_tournaments(),
            error=str(exception),
        ), 400
    return redirect(url_for("tournaments"))


@app.get("/tournaments/<tid>/result")
def tournament_result(tid):
    tournament, rows = tournament_result_rows(tid)
    if tournament is None:
        abort(404)
    tournament_view = next(
        (item for item in list_tournaments() if item["id"] == tid),
        None,
    )
    if tournament_view is None:
        abort(404)
    status = tournament_view["status"]
    prizes_data = tournament_view.get("prizes", [])
    prizes = [
        (f"{index + 1}{'st' if index == 0 else 'nd' if index == 1 else 'rd' if index == 2 else 'th'}", amount)
        for index, amount in enumerate(prizes_data)
        if isinstance(amount, int) and not isinstance(amount, bool)
    ]
    for row in rows:
        user_snapshot = get_db().collection("users").document(row["uid"]).get()
        user = user_snapshot.to_dict() if user_snapshot.exists else {}
        row["ign"] = row["ign"] or (user or {}).get("ign", "")
    return render_page(
        "tournament_result.html",
        "tournaments",
        c=obj(
            t=obj(
                id=tid,
                mode=tournament_view.get("mode", "Tournament"),
                team=tournament_view.get("team", ""),
                map=tournament_view.get("map", ""),
                joined=len(rows),
                slots=tournament_view.get("slots", 0),
                prize=tournament_view.get("prize", 0),
                per_kill=tournament_view.get("per_kill", 0),
                status=status,
            ),
            rows=[obj(**row) for row in rows],
            prizes=prizes,
            amounts=[amount for _, amount in prizes],
            labels=[label for label, _ in prizes],
            screenshot=False,
            unpaid=sum(not row["paid"] for row in rows),
        ),
    )


@app.post("/tournaments/<tid>/result/save")
def result_save(tid):
    body, error = _admin_json_body()
    if error:
        return error
    try:
        save_tournament_results(tid, body.get("rows"))
    except (AdminOperationError, PlayerNotFound) as exception:
        return jsonify({"ok": False, "error": str(exception)}), 400
    return jsonify({"ok": True}), 200


@app.post("/tournaments/<tid>/result/approve")
def result_approve(tid):
    body, error = _admin_json_body()
    if error:
        return error
    try:
        approved = approve_tournament_results(
            tid,
            body.get("rows"),
            admin_uid=session.get("admin_uid", "local-admin"),
        )
    except (AdminOperationError, PlayerNotFound) as exception:
        return jsonify({"ok": False, "error": str(exception)}), 400
    return jsonify({"ok": True, "approved": approved}), 200


@app.post("/tournaments/<tid>/room")
def tournament_room_save(tid):
    body, error = _admin_json_body()
    if error:
        return error
    try:
        result, notified = save_room_details(
            tid,
            _string_field(body, "room_id"),
            _string_field(body, "room_pass"),
        )
    except TournamentInputError as exception:
        return jsonify({"ok": False, "error": str(exception)}), 400
    return jsonify(
        {
            "ok": True,
            "notified": result.get(
                "notificationCounts",
                {"sent": 0, "failed": 0, "no_device": 0, "inbox_saved": 0},
            )
            if notified
            else None,
        }
    ), 200


@app.post("/notify/send")
def notification_send():
    body, error = _admin_json_body()
    if error:
        return error
    target = _string_field(body, "target").strip()
    if not target:
        return jsonify({"ok": False, "error": "Choose all players or enter a player UID."}), 400
    try:
        recipients = (
            user_ids()
            if target.casefold() == "all"
            else [find_player(target)["uid"]]
        )
        counts = notify_users(
            recipients,
            body.get("title"),
            body.get("body"),
            body.get("link", "/"),
        )
    except (NotificationInputError, PlayerNotFound) as exception:
        return jsonify({"ok": False, "error": str(exception)}), 400
    return jsonify({"ok": True, **counts}), 200


@app.post("/notify/clear")
def notification_clear():
    return jsonify(
        {
            "ok": True,
            "deleted": clear_admin_notification_history(),
        }
    ), 200


@app.post("/holds/find")
def hold_find():
    body, error = _admin_json_body()
    if error:
        return error
    try:
        return jsonify({"ok": True, **find_player(_string_field(body, "query"))})
    except PlayerNotFound as exception:
        return jsonify({"ok": False, "error": str(exception)}), 404


@app.post("/holds/add")
def hold_add():
    body, error = _admin_json_body()
    if error:
        return error
    try:
        player = find_player(_string_field(body, "query"))
        set_account_hold(
            player["uid"],
            True,
            reason=_string_field(body, "reason"),
        )
    except (PlayerNotFound, AdminOperationError) as exception:
        return jsonify({"ok": False, "error": str(exception)}), 400
    return jsonify({"ok": True}), 200


@app.post("/holds/release")
def hold_release():
    body, error = _admin_json_body()
    if error:
        return error
    try:
        set_account_hold(_string_field(body, "uid"), False)
    except (PlayerNotFound, AdminOperationError) as exception:
        return jsonify({"ok": False, "error": str(exception)}), 400
    return jsonify({"ok": True}), 200


@app.post("/wallet-credit/find")
def wallet_credit_find():
    body, error = _admin_json_body()
    if error:
        return error
    try:
        return jsonify({"ok": True, **find_player(_string_field(body, "query"))})
    except PlayerNotFound as exception:
        return jsonify({"ok": False, "error": str(exception)}), 404


@app.post("/wallet-credit/add")
def wallet_credit_add():
    body, error = _admin_json_body()
    if error:
        return error
    amount = _whole_rupees(body.get("amount"))
    if amount is None:
        return jsonify({"ok": False, "error": "Enter a whole-rupee amount."}), 400
    try:
        player = find_player(_string_field(body, "query"))
        result = credit_player_wallet(
            player["uid"],
            amount,
            _string_field(body, "balance"),
            _string_field(body, "reason"),
        )
    except (PlayerNotFound, AdminOperationError) as exception:
        return jsonify({"ok": False, "error": str(exception)}), 400
    return jsonify({"ok": True, "total": result["total"], "notified": "sent"}), 200


@app.post("/withdrawals/<wid>/paid")
def withdrawal_mark_paid(wid):
    body, error = _admin_json_body()
    if error:
        return error
    try:
        result = settle_withdrawal(
            wid,
            "paid",
            ref=_string_field(body, "ref"),
        )
    except (AdminOperationError, PlayerNotFound) as exception:
        return jsonify({"ok": False, "error": str(exception)}), 400
    return jsonify({"ok": True, "notified": result["notificationStatus"]}), 200


@app.post("/withdrawals/<wid>/reject")
def withdrawal_reject(wid):
    body, error = _admin_json_body()
    if error:
        return error
    try:
        settle_withdrawal(
            wid,
            "rejected",
            reason=_string_field(body, "reason"),
        )
    except (AdminOperationError, PlayerNotFound) as exception:
        return jsonify({"ok": False, "error": str(exception)}), 400
    return jsonify({"ok": True}), 200


@app.post("/withdrawals/<wid>/delete")
def withdrawal_delete(wid):
    try:
        delete_settled_withdrawal(wid)
    except (AdminOperationError, PlayerNotFound) as exception:
        return jsonify({"ok": False, "error": str(exception)}), 400
    return jsonify({"ok": True}), 200


@app.post("/withdrawals/clear")
def withdrawals_clear():
    return jsonify({"ok": True, "deleted": clear_settled_withdrawals()}), 200


@app.post("/maintenance/save")
def maintenance_save():
    body, error = _admin_json_body()
    if error:
        return error
    try:
        result = update_maintenance(
            body.get("on"),
            _string_field(body, "message"),
            _string_field(body, "eta"),
        )
    except AdminOperationError as exception:
        return jsonify({"ok": False, "error": str(exception)}), 400
    return jsonify({"ok": True, **result}), 200


@app.post("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


def _preview_action(*_args, **_kwargs):
    if request.is_json or request.headers.get("X-Requested-With"):
        return jsonify(
            ok=False,
            error="This admin action is not connected yet.",
        ), 501
    return (
        "<!doctype html><title>Not available</title>"
        "<p>This admin action is not connected yet.</p>"
        '<p><a href="/dashboard">Back to dashboard</a></p>',
        501,
    )


def _admin_json_body():
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return None, (jsonify({"ok": False, "error": "A JSON request is required."}), 400)
    return body, None


def _string_field(body, name):
    value = body.get(name, "")
    return value if isinstance(value, str) else ""


def _whole_rupees(value):
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, str) and value.isdigit():
        return int(value)
    return None


for endpoint, rule, methods in [
    ("upi_shot", "/withdrawals/<wid>/upi-shot", ["GET"]),
    ("result_shot", "/tournaments/<tid>/result-shot", ["GET"]),
    ("result_screenshot", "/tournaments/<tid>/result/screenshot", ["POST"]),
]:
    app.add_url_rule(rule, endpoint, _preview_action, methods=methods)


@app.route("/<path:action>", methods=["POST"])
def preview_post(action):
    return _preview_action()


def _tournament_form(form, *, loot):
    return {
        "mode": form.get("mode", ""),
        "team": form.get("team", ""),
        "map": form.get("map", ""),
        "fee": 0 if loot else form.get("fee", ""),
        "slots": form.get("slots", ""),
        "duration": form.get("duration", ""),
        "start": form.get("start", ""),
        "place_amt": form.getlist("place_amt"),
        "per_kill": form.get("per_kill", ""),
        "banner_pick": form.get("banner_pick", ""),
        "loot": loot,
    }


def _image_options():
    images_path = ROOT / "frontend" / "assets" / "images"
    if not images_path.is_dir():
        return []
    return sorted(
        image.name
        for image in images_path.iterdir()
        if image.is_file() and image.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
    )


if __name__ == "__main__":
    threading.Timer(1, webbrowser.open, args=(ADMIN_URL,)).start()
    print(f"Admin panel: {ADMIN_URL}")
    app.run(host="127.0.0.1", port=5001, debug=False)
