from decimal import Decimal, InvalidOperation
import re
import secrets
from typing import Any
from urllib.parse import parse_qsl, urlencode, urlparse, urlsplit, urlunsplit

import requests
from firebase_admin import firestore
from flask import current_app

from app.core.firestore import get_db, run_transaction
from app.services.wallet_service import apply, wallet_for


class TranzUPIError(Exception):
    pass


def create_payment_order(
    uid: str,
    amount: int,
    *,
    customer_mobile: str = "",
    db: Any = None,
) -> dict[str, Any]:
    database = db or get_db()
    api_key, base_url, redirect_url = _configuration()
    if isinstance(amount, bool) or not isinstance(amount, int) or amount < 1:
        raise TranzUPIError("Amount must be a whole number of rupees.")
    if customer_mobile and (
        len(customer_mobile) > 20
        or not re.fullmatch(r"[0-9+(). -]+", customer_mobile)
    ):
        raise TranzUPIError("Enter a valid mobile number.")

    order_id = f"RV{secrets.token_hex(16).upper()}"
    redirect_url = _redirect_url_for_order(redirect_url, order_id)
    order_ref = database.collection("paymentOrders").document(order_id)
    user_snapshot = database.collection("users").document(uid).get()
    if not user_snapshot.exists:
        raise TranzUPIError("User profile was not found. Please sign in again.")
    user = user_snapshot.to_dict() or {}
    if not customer_mobile:
        saved_mobile = user.get("phoneNumber") or user.get("phone")
        if isinstance(saved_mobile, str) and len(saved_mobile) <= 20:
            customer_mobile = saved_mobile

    def create_pending(tx: Any) -> None:
        tx.create(
            order_ref,
            {
                "uid": uid,
                "amount": amount,
                "status": "pending",
                "provider": "tranzupi",
                "createdAt": firestore.SERVER_TIMESTAMP,
            },
        )

    run_transaction(database, create_pending)

    form = {
        "user_token": api_key,
        "amount": f"{amount}.00",
        "order_id": order_id,
        "redirect_url": redirect_url,
        "remark1": "Ravilon wallet top-up",
    }
    if customer_mobile:
        form["customer_mobile"] = customer_mobile
    try:
        response = requests.post(
            f"{base_url}/api/create-order",
            data=form,
            timeout=20,
        )
        response.raise_for_status()
        payload = response.json()
    except (requests.RequestException, ValueError):
        order_ref.update({"status": "create_failed"})
        raise TranzUPIError(
            "Could not start the payment. Please try again."
        ) from None

    result = payload.get("result") if isinstance(payload, dict) else None
    payment_url = result.get("payment_url") if isinstance(result, dict) else None
    returned_order_id = result.get("orderId") if isinstance(result, dict) else None
    if (
        not isinstance(payload, dict)
        or payload.get("status") is not True
        or returned_order_id != order_id
        or not _is_provider_url(payment_url)
    ):
        order_ref.update({"status": "create_failed"})
        raise TranzUPIError(
            "The payment provider did not return a valid payment link."
        )

    order_ref.update(
        {
            "paymentUrl": payment_url,
            "providerOrderId": returned_order_id,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
    )
    return {"orderId": order_id, "paymentUrl": payment_url, "status": "pending"}


def check_payment_order(
    order_id: str,
    *,
    uid: str | None = None,
    db: Any = None,
) -> dict[str, Any]:
    database = db or get_db()
    order_ref = database.collection("paymentOrders").document(order_id)
    snapshot = order_ref.get()
    if not snapshot.exists:
        raise TranzUPIError("Payment order was not found.")
    order = snapshot.to_dict() or {}
    if uid is not None and order.get("uid") != uid:
        raise TranzUPIError("Payment order was not found.")
    if order.get("status") in {"paid", "failed", "create_failed"}:
        return _order_result(order_id, order, database)
    api_key, base_url, _ = _configuration()

    try:
        response = requests.post(
            f"{base_url}/api/check-order-status",
            data={"user_token": api_key, "order_id": order_id},
            timeout=20,
        )
        response.raise_for_status()
        payload = response.json()
    except (requests.RequestException, ValueError):
        raise TranzUPIError(
            "Could not verify the payment yet. Please try again."
        ) from None

    provider_state, result = _payment_state(payload)
    if provider_state == "pending":
        return _order_result(order_id, order, database)

    if provider_state == "paid":
        reported_order_id = result.get("orderId")
        if reported_order_id is not None and reported_order_id != order_id:
            raise TranzUPIError("Payment details did not match this order.")
        if not _amount_matches(result.get("amount"), order.get("amount")):
            raise TranzUPIError("Payment amount did not match this order.")

        updated_wallet: dict[str, Any] = {}

        def credit_if_pending(tx: Any) -> None:
            current = order_ref.get(transaction=tx)
            if not current.exists:
                raise TranzUPIError("Payment order was not found.")
            current_order = current.to_dict() or {}
            if current_order.get("status") == "paid":
                updated_wallet["ledgerId"] = current_order.get("ledgerId", "")
                return
            if current_order.get("status") != "pending":
                return
            if not _amount_matches(result.get("amount"), current_order.get("amount")):
                raise TranzUPIError("Payment amount did not match this order.")

            credited = apply(
                current_order["uid"],
                {
                    "deltas": {"deposited": current_order["amount"]},
                    "kind": "added",
                    "title": "Wallet top-up",
                    "amt": current_order["amount"],
                    "dir": "in",
                    "status": "paid",
                    "ref": order_id,
                },
                tx,
            )
            updated_wallet["ledgerId"] = credited["ledgerId"]
            tx.update(
                order_ref,
                {
                    "status": "paid",
                    "ledgerId": credited["ledgerId"],
                    "utr": result.get("utr", ""),
                    "paidAt": firestore.SERVER_TIMESTAMP,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                },
            )

        run_transaction(database, credit_if_pending)
    else:
        def mark_failed(tx: Any) -> None:
            current = order_ref.get(transaction=tx)
            if current.exists and (current.to_dict() or {}).get("status") == "pending":
                tx.update(
                    order_ref,
                    {
                        "status": "failed",
                        "updatedAt": firestore.SERVER_TIMESTAMP,
                    },
                )

        run_transaction(database, mark_failed)

    latest = order_ref.get()
    final_order = latest.to_dict() or {}
    return _order_result(order_id, final_order, database)


def _configuration() -> tuple[str, str, str]:
    api_key = current_app.config.get("TRANZUPI_API_KEY", "").strip()
    base_url = current_app.config.get(
        "TRANZUPI_BASE_URL", "https://www.tranzupi.com"
    ).strip().rstrip("/")
    redirect_url = current_app.config.get("TRANZUPI_REDIRECT_URL", "").strip()
    parsed_base = urlparse(base_url)
    parsed_redirect = urlparse(redirect_url)
    if (
        not api_key
        or parsed_base.scheme != "https"
        or not parsed_base.netloc
        or parsed_redirect.scheme != "https"
        or not parsed_redirect.netloc
    ):
        raise TranzUPIError(
            "Payment gateway is not configured. Contact support."
        )
    return api_key, base_url, redirect_url


def _is_provider_url(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    parsed = urlparse(value)
    hostname = (parsed.hostname or "").lower()
    return (
        parsed.scheme == "https"
        and (hostname == "tranzupi.com" or hostname.endswith(".tranzupi.com"))
    )


def _redirect_url_for_order(redirect_url: str, order_id: str) -> str:
    parts = urlsplit(redirect_url)
    query = dict(parse_qsl(parts.query, keep_blank_values=True))
    query["order_id"] = order_id
    return urlunsplit(
        (parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment)
    )


def _payment_state(payload: Any) -> tuple[str, dict[str, Any]]:
    if not isinstance(payload, dict):
        raise TranzUPIError("Payment provider returned an invalid response.")
    result = payload.get("result")
    if not isinstance(result, dict):
        result = {}
    if str(payload.get("status", "")).upper() in {"FAILURE", "FAILED"}:
        return "failed", result
    state = str(result.get("status") or "").upper()
    transaction_state = str(result.get("txnStatus") or "").upper()
    if (
        str(payload.get("status", "")).upper() == "COMPLETED"
        and (state == "SUCCESS" or (not state and transaction_state == "COMPLETED"))
    ):
        return "paid", result
    if state in {"FAILURE", "FAILED", "CANCELLED"} or transaction_state in {
        "FAILURE",
        "FAILED",
        "CANCELLED",
    }:
        return "failed", result
    return "pending", result


def _amount_matches(reported: Any, expected: Any) -> bool:
    if isinstance(expected, bool) or not isinstance(expected, int):
        return False
    try:
        value = Decimal(str(reported))
    except (InvalidOperation, ValueError):
        return False
    return value.is_finite() and value == Decimal(expected)


def _order_result(order_id: str, order: dict[str, Any], db: Any) -> dict[str, Any]:
    result: dict[str, Any] = {
        "orderId": order_id,
        "status": order.get("status", "pending"),
        "amount": order.get("amount", 0),
    }
    if isinstance(order.get("paymentUrl"), str):
        result["paymentUrl"] = order["paymentUrl"]
    uid = order.get("uid")
    if order.get("status") == "paid" and isinstance(uid, str):
        result["wallet"] = wallet_for(uid, db)
        ledger_id = order.get("ledgerId")
        if isinstance(ledger_id, str) and ledger_id:
            ledger = db.collection("transactions").document(ledger_id).get()
            if ledger.exists:
                result["ledger"] = {
                    "id": ledger_id,
                    **(ledger.to_dict() or {}),
                }
    return result
