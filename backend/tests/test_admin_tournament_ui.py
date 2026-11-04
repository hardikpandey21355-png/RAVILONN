import importlib.util
import os
from datetime import datetime, timedelta
from pathlib import Path
import re
import unittest
from unittest.mock import MagicMock, patch
from zoneinfo import ZoneInfo

from werkzeug.datastructures import MultiDict


ROOT = Path(__file__).resolve().parents[2]
ADMIN_APP_PATH = ROOT / "ADMIN" / "admin_app.py"
SPEC = importlib.util.spec_from_file_location("ravilon_admin_app", ADMIN_APP_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Could not load admin application module.")
admin_app = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(admin_app)
IST = ZoneInfo("Asia/Kolkata")


class AdminTournamentUiTests(unittest.TestCase):
    def setUp(self) -> None:
        admin_app.app.config.update(TESTING=True, SECRET_KEY="test-session-secret")
        self.client = admin_app.app.test_client()
        with patch.dict(os.environ, {"ADMIN_PASSWORD": "test-admin-password"}):
            login_page = self.client.get("/")
            csrf = re.search(
                rb'name="csrf" value="([^"]+)"',
                login_page.data,
            ).group(1).decode()
            response = self.client.post(
                "/",
                data={"csrf": csrf, "password": "test-admin-password"},
            )
        self.assertEqual(response.status_code, 302)

    def test_create_form_calls_shared_firestore_service_and_saves_default(self) -> None:
        start = (datetime.now(IST) + timedelta(days=1)).replace(tzinfo=None)
        with patch.object(admin_app, "create_tournament") as create:
            response = self.client.post(
                "/tournaments/new",
                data=MultiDict(
                    [
                        ("mode", "BR Solo"),
                        ("team", "Solo"),
                        ("map", "Bermuda"),
                        ("fee", "25"),
                        ("slots", "48"),
                        ("duration", "25"),
                        ("start", start.isoformat(timespec="minutes")),
                        ("per_kill", "10"),
                        ("place_amt", "250"),
                        ("save_default", "1"),
                    ]
                ),
                headers={"X-CSRF": self._csrf()},
            )

        self.assertEqual(response.status_code, 302)
        self.assertEqual(response.headers["Location"], "/tournaments")
        create.assert_called_once()
        self.assertTrue(create.call_args.kwargs["save_as_default"])
        self.assertEqual(create.call_args.args[0]["team"], "Solo")

    def test_tournament_delete_uses_shared_service(self) -> None:
        with patch.object(admin_app, "delete_tournament") as delete:
            response = self.client.post(
                "/tournaments/tournament-1/delete",
                data={"csrf": self._csrf()},
            )

        self.assertEqual(response.status_code, 302)
        self.assertEqual(response.headers["Location"], "/tournaments")
        delete.assert_called_once_with("tournament-1")

    def test_tournament_players_page_shows_joined_player_details(self) -> None:
        tournament = {
            "mode": "BR Solo",
            "team": "Solo",
            "map": "Bermuda",
            "joined": 1,
            "slots": 20,
        }
        rows = [{"slot": 3, "ign": "ShadowX", "game_uid": "1234567890"}]
        with patch.object(
            admin_app,
            "list_joined_players",
            return_value=(tournament, rows),
        ):
            response = self.client.get("/tournaments/tournament-1/players")

        self.assertEqual(response.status_code, 200)
        self.assertIn(b"ShadowX", response.data)
        self.assertIn(b"1234567890", response.data)
        self.assertIn(b"<td><b>3</b></td>", response.data)

    def test_dashboard_uses_live_counts_from_shared_service(self) -> None:
        with patch.object(
            admin_app,
            "dashboard_counts",
            return_value={
                "live": 1,
                "upcoming": 2,
                "completed": 3,
                "joined": 4,
                "slots": 40,
                "total": 6,
            },
        ):
            response = self.client.get("/dashboard")

        self.assertEqual(response.status_code, 200)
        self.assertIn(b"<b>1</b>", response.data)
        self.assertIn(b"<b>2</b>", response.data)
        self.assertIn(b"<b>3</b>", response.data)

    def test_accounts_and_deposits_are_blurred_incomplete_placeholders(self) -> None:
        accounts = self.client.get("/accounts")
        deposits = self.client.get("/deposits")

        self.assertEqual(accounts.status_code, 200)
        self.assertEqual(deposits.status_code, 200)
        for response in (accounts, deposits):
            self.assertIn(b"TO BE COMPLETED", response.data)
            self.assertIn(b"filter:blur(7px)", response.data)
        self.assertNotIn(b"ShadowX", accounts.data)
        self.assertNotIn(b"DEMO123456", deposits.data)

    def test_incomplete_pages_are_disabled_at_the_bottom_of_the_sidebar(self) -> None:
        with patch.object(
            admin_app,
            "dashboard_counts",
            return_value={
                "live": 0,
                "upcoming": 0,
                "completed": 0,
                "joined": 0,
                "slots": 0,
                "total": 0,
            },
        ):
            response = self.client.get("/dashboard")

        self.assertEqual(response.status_code, 200)
        sidebar = response.data.split(b'<nav class="nav">', 1)[1].split(
            b"</nav>", 1
        )[0]
        approve = sidebar.index(b">Approve amount<span")
        accounts = sidebar.index(b">Accounts<span")
        self.assertLess(approve, accounts)
        self.assertLess(sidebar.index(b">Notifications</a>"), approve)
        self.assertIn(b'<div class="nav-divider" role="separator"></div>', sidebar)
        self.assertEqual(sidebar.count(b'class="nav-disabled"'), 2)
        self.assertNotIn(b'href="/deposits"', sidebar)
        self.assertNotIn(b'href="/accounts"', sidebar)

    def test_check_and_edit_is_active_below_notifications(self) -> None:
        response = self.client.get("/check-edit")
        self.assertEqual(response.status_code, 200)
        sidebar = response.data.split(b'<nav class="nav">', 1)[1].split(
            b"</nav>", 1
        )[0]
        self.assertLess(
            sidebar.index(b">Notifications</a>"),
            sidebar.index(b">Check and edit</a>"),
        )
        self.assertLess(
            sidebar.index(b">Check and edit</a>"),
            sidebar.index(b'class="nav-divider"'),
        )
        self.assertIn(b"View full details", response.data)
        self.assertIn(b"Deduct and notify player", response.data)
        self.assertIn(
            b"grid-template-columns:repeat(2,minmax(0,1fr))",
            response.data,
        )
        self.assertIn(b"overflow-wrap:anywhere", response.data)
        self.assertIn(b'id="ceIdentity"', response.data)
        self.assertIn(b"word-break:break-all!important", response.data)

    def test_check_and_edit_routes_use_account_services(self) -> None:
        player = {
            "uid": "player-1",
            "name": "TestPlayer",
            "total": 500,
            "deposited": 300,
            "winnings": 200,
            "bonus": 0,
        }
        details = {
            "uid": "player-1",
            "name": "TestPlayer",
            "transactions": [{"id": "tx-1", "amount": 25}],
        }
        with (
            patch.object(admin_app, "find_player", return_value=player) as find,
            patch.object(admin_app, "player_account_details", return_value=details) as full,
            patch.object(
                admin_app,
                "deduct_wallet",
                return_value={"total": 475, "notificationStatus": "sent"},
            ) as deduct,
        ):
            found = self.client.post(
                "/check-edit/find",
                json={"query": "player-1"},
                headers={"X-CSRF": self._csrf()},
            )
            full_response = self.client.post(
                "/check-edit/details",
                json={"uid": "player-1"},
                headers={"X-CSRF": self._csrf()},
            )
            deducted = self.client.post(
                "/check-edit/deduct",
                json={
                    "uid": "player-1",
                    "amount": "25",
                    "bucket": "winnings",
                    "reason": "Suspicious credit",
                },
                headers={"X-CSRF": self._csrf()},
            )

        self.assertEqual(found.json["uid"], "player-1")
        find.assert_any_call("player-1")
        self.assertEqual(full_response.json["transactions"][0]["id"], "tx-1")
        full.assert_called_once_with("player-1")
        self.assertEqual(deducted.json["notified"], "sent")
        deduct.assert_called_once_with("player-1", 25, "winnings", "Suspicious credit")

    def test_check_and_edit_rejects_invalid_deduction_amount(self) -> None:
        with patch.object(admin_app, "deduct_wallet") as deduct:
            response = self.client.post(
                "/check-edit/deduct",
                json={
                    "uid": "player-1",
                    "amount": "1.5",
                    "bucket": "deposited",
                    "reason": "Suspicious credit",
                },
                headers={"X-CSRF": self._csrf()},
            )

        self.assertEqual(response.status_code, 400)
        deduct.assert_not_called()

    def test_result_actions_use_firestore_service(self) -> None:
        csrf = self._csrf()
        rows = [
            {"uid": "player-1", "kills": 2, "place": 1, "amount": 500}
        ]
        with (
            patch.object(admin_app, "save_tournament_results") as save,
            patch.object(admin_app, "approve_tournament_results", return_value=1) as approve,
        ):
            saved = self.client.post(
                "/tournaments/tournament-1/result/save",
                json={"rows": rows},
                headers={"X-CSRF": csrf},
            )
            approved = self.client.post(
                "/tournaments/tournament-1/result/approve",
                json={"rows": rows},
                headers={"X-CSRF": csrf},
            )

        self.assertEqual(saved.status_code, 200)
        self.assertEqual(approved.status_code, 200)
        save.assert_called_once_with("tournament-1", rows)
        approve.assert_called_once()

    def test_result_page_uses_saved_tournament_players_and_results(self) -> None:
        db = MagicMock()
        db.collection.return_value.document.return_value.get.return_value.exists = False
        with (
            patch.object(
                admin_app,
                "tournament_result_rows",
                return_value=(
                    {"status": "completed"},
                    [
                        {
                            "uid": "player-1",
                            "ign": "LivePlayer",
                            "game_uid": "1234567890",
                            "kills": 3,
                            "place": 1,
                            "amount": 500,
                            "paid": False,
                        }
                    ],
                ),
            ),
            patch.object(
                admin_app,
                "list_tournaments",
                return_value=[
                    {
                        "id": "tournament-1",
                        "status": "completed",
                        "mode": "BR Solo",
                        "team": "Solo",
                        "map": "Bermuda",
                        "joined": 1,
                        "slots": 20,
                        "prize": 500,
                        "per_kill": 10,
                        "prizes": [500],
                    }
                ],
            ),
            patch.object(admin_app, "get_db", return_value=db),
        ):
            response = self.client.get("/tournaments/tournament-1/result")

        self.assertEqual(response.status_code, 200)
        self.assertIn(b"LivePlayer", response.data)
        self.assertIn(b"1234567890", response.data)
        self.assertNotIn(b"ShadowX", response.data)

    def test_hold_wallet_credit_and_maintenance_actions_are_connected(self) -> None:
        player = {"uid": "player-1"}
        csrf = self._csrf()
        with (
            patch.object(admin_app, "find_player", return_value=player),
            patch.object(admin_app, "set_account_hold") as set_hold,
        ):
            hold = self.client.post(
                "/holds/add",
                json={"query": "1234567890", "reason": "payment review"},
                headers={"X-CSRF": csrf},
            )
        self.assertEqual(hold.status_code, 200)
        set_hold.assert_called_once_with(
            "player-1",
            True,
            reason="payment review",
        )

        with (
            patch.object(admin_app, "find_player", return_value=player),
            patch.object(
                admin_app,
                "credit_player_wallet",
                return_value={"total": 150},
            ) as credit,
        ):
            wallet = self.client.post(
                "/wallet-credit/add",
                json={
                    "query": "player-1",
                    "amount": "50",
                    "balance": "deposited",
                    "reason": "payment review",
                },
                headers={"X-CSRF": csrf},
            )
        self.assertEqual(wallet.status_code, 200)
        self.assertEqual(wallet.json["total"], 150)
        credit.assert_called_once_with(
            "player-1",
            50,
            "deposited",
            "payment review",
        )

        with patch.object(
            admin_app,
            "update_maintenance",
            return_value={"maintenance": True},
        ) as maintenance:
            response = self.client.post(
                "/maintenance/save",
                json={"on": True, "message": "Back soon", "eta": "10 minutes"},
                headers={"X-CSRF": csrf},
            )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json["maintenance"])
        maintenance.assert_called_once_with(True, "Back soon", "10 minutes")

    def test_holds_page_renders_with_real_hold_count(self) -> None:
        rows = [
            {
                "uid": "player-1",
                "ign": "TestPlayer",
                "game_uid": "1234567890",
                "when": "02 Nov, 08:00 PM",
                "reason": "payment review",
            }
        ]
        with patch.object(admin_app, "list_holds", return_value=rows):
            response = self.client.get("/holds")

        self.assertEqual(response.status_code, 200)
        self.assertIn(b"TestPlayer", response.data)
        self.assertIn(b"payment review", response.data)
        self.assertIn(b"data-uid=\"player-1\"", response.data)

    def test_payment_methods_reads_saved_gateway_and_marks_manual_incomplete(self) -> None:
        with patch.object(
            admin_app,
            "get_settings",
            return_value={"addMoneyMethod": "gateway"},
        ):
            response = self.client.get("/payment-methods")

        self.assertEqual(response.status_code, 200)
        self.assertIn(b'value="gateway" checked', response.data)
        self.assertIn(b"Manual (UPI QR + UTR)", response.data)
        self.assertIn(b"To be completed", response.data)
        self.assertIn(b'value="manual" disabled', response.data)
        self.assertNotIn(b'value="manual" checked', response.data)

    def test_legacy_manual_setting_renders_off_as_the_selectable_fallback(self) -> None:
        with patch.object(
            admin_app,
            "get_settings",
            return_value={"addMoneyMethod": "manual"},
        ):
            response = self.client.get("/payment-methods")

        self.assertEqual(response.status_code, 200)
        self.assertIn(b'value="off" checked', response.data)
        self.assertIn(b'value="manual" disabled', response.data)

    def test_payment_method_save_persists_selected_method(self) -> None:
        with patch.object(
            admin_app,
            "save_add_money_method",
            return_value={"addMoneyMethod": "off"},
        ) as save_method:
            response = self.client.post(
                "/payment-methods/save",
                json={"method": "off"},
                headers={"X-CSRF": self._csrf()},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json,
            {"ok": True, "addMoneyMethod": "off"},
        )
        save_method.assert_called_once_with("off")

    def test_payment_method_save_rejects_unknown_mode(self) -> None:
        with patch.object(admin_app, "save_add_money_method") as save_method:
            response = self.client.post(
                "/payment-methods/save",
                json={"method": "manual"},
                headers={"X-CSRF": self._csrf()},
            )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(
            response.json,
            {"ok": False, "error": "Choose Gateway or Off."},
        )
        save_method.assert_not_called()

    def test_withdrawals_page_uses_real_service_data(self) -> None:
        rows = [
            {
                "id": "withdrawal-1",
                "amount": 75,
                "ign": "TestPlayer",
                "game_uid": "1234567890",
                "uid": "player-1",
                "upi": "player@example",
                "won": 300,
                "added": 100,
                "status": "pending",
                "when": "03 Nov, 08:00 PM",
                "done": "",
                "ref": "",
                "note": "",
                "upi_shot": False,
            }
        ]
        with patch.object(admin_app, "list_withdrawals", return_value=rows):
            response = self.client.get("/withdrawals")

        self.assertEqual(response.status_code, 200)
        self.assertIn(b"TestPlayer", response.data)
        self.assertIn(b"player@example", response.data)
        self.assertIn(b"withdrawal-1", response.data)

    def test_withdrawal_actions_call_transactional_service(self) -> None:
        csrf = self._csrf()
        with patch.object(
            admin_app,
            "settle_withdrawal",
            return_value={"notificationStatus": "sent"},
        ) as settle:
            paid = self.client.post(
                "/withdrawals/withdrawal-1/paid",
                json={"ref": "UPI-REF-1"},
                headers={"X-CSRF": csrf},
            )
        self.assertEqual(paid.status_code, 200)
        self.assertEqual(paid.json["notified"], "sent")
        settle.assert_called_once_with("withdrawal-1", "paid", ref="UPI-REF-1")

        with patch.object(admin_app, "settle_withdrawal") as settle:
            rejected = self.client.post(
                "/withdrawals/withdrawal-1/reject",
                json={"reason": "UPI details issue"},
                headers={"X-CSRF": csrf},
            )
        self.assertEqual(rejected.status_code, 200)
        settle.assert_called_once_with(
            "withdrawal-1",
            "rejected",
            reason="UPI details issue",
        )

        with patch.object(admin_app, "delete_settled_withdrawal") as delete:
            deleted = self.client.post(
                "/withdrawals/withdrawal-1/delete",
                json={},
                headers={"X-CSRF": csrf},
            )
        self.assertEqual(deleted.status_code, 200)
        delete.assert_called_once_with("withdrawal-1")

        with patch.object(
            admin_app,
            "clear_settled_withdrawals",
            return_value=2,
        ) as clear:
            cleared = self.client.post(
                "/withdrawals/clear",
                json={},
                headers={"X-CSRF": csrf},
            )
        self.assertEqual(cleared.status_code, 200)
        self.assertEqual(cleared.json["deleted"], 2)
        clear.assert_called_once_with()

    def test_notification_page_sends_to_the_selected_player_only(self) -> None:
        counts = {"sent": 1, "failed": 0, "no_device": 0, "inbox_saved": 1}
        with (
            patch.object(admin_app, "find_player", return_value={"uid": "player-1"}),
            patch.object(admin_app, "notify_users", return_value=counts) as notify,
        ):
            response = self.client.post(
                "/notify/send",
                json={
                    "target": "1234567890",
                    "title": "Account update",
                    "body": "Please review your account information.",
                    "link": "/profile",
                },
                headers={"X-CSRF": self._csrf()},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["inbox_saved"], 1)
        notify.assert_called_once_with(
            ["player-1"],
            "Account update",
            "Please review your account information.",
            "/profile",
        )

    def test_notification_page_can_send_to_all_players(self) -> None:
        counts = {"sent": 2, "failed": 0, "no_device": 0, "inbox_saved": 2}
        with (
            patch.object(admin_app, "user_ids", return_value=["player-1", "player-2"]),
            patch.object(admin_app, "notify_users", return_value=counts) as notify,
        ):
            response = self.client.post(
                "/notify/send",
                json={
                    "target": "all",
                    "title": "Service update",
                    "body": "A new update is available in your account.",
                    "link": "/",
                },
                headers={"X-CSRF": self._csrf()},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["inbox_saved"], 2)
        notify.assert_called_once_with(
            ["player-1", "player-2"],
            "Service update",
            "A new update is available in your account.",
            "/",
        )

    def test_notification_page_uses_real_history_and_device_count(self) -> None:
        with (
            patch.object(admin_app, "enabled_device_count", return_value=3),
            patch.object(
                admin_app,
                "recent_admin_notifications",
                return_value=[
                    {
                        "when": "02 Nov, 08:00 PM",
                        "ign": "TestPlayer",
                        "game_uid": "1234567890",
                        "title": "Account update",
                        "body": "Please review your account information.",
                        "push_status": "sent",
                        "error": "",
                    }
                ],
            ),
        ):
            response = self.client.get("/notify")

        self.assertEqual(response.status_code, 200)
        self.assertIn(b"TestPlayer", response.data)
        self.assertIn(b"Players with push notifications enabled", response.data)
        self.assertIn(b"Saved in Firebase inbox", response.data)
        self.assertIn(b"Account update", response.data)

    def test_room_save_reports_notifications_only_for_changed_room(self) -> None:
        counts = {"sent": 2, "failed": 0, "no_device": 1, "inbox_saved": 3}
        with patch.object(
            admin_app,
            "save_room_details",
            return_value=(
                {"roomId": "room-1", "roomPass": "pass-1", "notificationCounts": counts},
                True,
            ),
        ) as save:
            response = self.client.post(
                "/tournaments/tournament-1/room",
                json={"room_id": "room-1", "room_pass": "pass-1"},
                headers={"X-CSRF": self._csrf()},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["notified"], counts)
        save.assert_called_once_with("tournament-1", "room-1", "pass-1")

    def _csrf(self) -> str:
        with self.client.session_transaction() as session:
            return session["csrf"]


if __name__ == "__main__":
    unittest.main()
