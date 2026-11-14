import unittest
from datetime import datetime, timedelta, timezone
import hashlib
from typing import Any
from unittest.mock import patch
from zoneinfo import ZoneInfo

from app.services import tournament_service
from app.services.tournament_service import (
    TournamentInputError,
    TournamentJoinError,
    SlotAlreadyTaken,
    create_from_default,
    create_tournament,
    dashboard_counts,
    delete_tournament,
    joined_matches,
    save_room_details,
    slots_for_tournament,
    validate_tournament,
)
from app.services.wallet_service import InsufficientFunds, entry_fee_deltas


IST = ZoneInfo("Asia/Kolkata")


class Snapshot:
    def __init__(self, identifier: str, value: dict[str, Any] | None) -> None:
        self.id = identifier
        self._value = value
        self.exists = value is not None

    def to_dict(self) -> dict[str, Any]:
        return dict(self._value or {})


class Document:
    def __init__(self, db: "FakeFirestore", collection: str, identifier: str) -> None:
        self.db = db
        self.collection = collection
        self.id = identifier

    def get(self, **_kwargs: Any) -> Snapshot:
        return Snapshot(self.id, self.db.data[self.collection].get(self.id))

    def delete(self) -> None:
        self.db.data[self.collection].pop(self.id, None)

    def update(self, value: dict[str, Any]) -> None:
        self.db.data[self.collection][self.id].update(value)

    def create(self, value: dict[str, Any]) -> None:
        if self.id in self.db.data[self.collection]:
            raise ValueError("Document already exists.")
        self.db.data[self.collection][self.id] = dict(value)


class Collection:
    def __init__(self, db: "FakeFirestore", name: str) -> None:
        self.db = db
        self.name = name

    def document(self, identifier: str | None = None) -> Document:
        if identifier is None:
            self.db.next_id += 1
            identifier = f"doc-{self.db.next_id}"
        return Document(self.db, self.name, identifier)

    def stream(self, **_kwargs: Any) -> list[Snapshot]:
        return [
            Snapshot(identifier, value)
            for identifier, value in self.db.data[self.name].items()
        ]

    def where(self, field: str, _operator: str, expected: Any) -> "Query":
        return Query(self.db, self.name, field, expected)


class Batch:
    def __init__(self, db: "FakeFirestore") -> None:
        self.db = db
        self.pending: list[tuple[Document, dict[str, Any]]] = []

    def set(self, reference: Document, value: dict[str, Any]) -> None:
        self.pending.append((reference, value))

    def commit(self) -> None:
        for reference, value in self.pending:
            self.db.data[reference.collection][reference.id] = dict(value)


class FakeFirestore:
    def __init__(self) -> None:
        self.data: dict[str, dict[str, dict[str, Any]]] = {
            "tournaments": {},
            "tournamentDefaults": {},
            "tournamentEntries": {},
            "tournamentResults": {},
            "notifications": {},
        }
        self.next_id = 0

    def collection(self, name: str) -> Collection:
        self.data.setdefault(name, {})
        return Collection(self, name)

    def batch(self) -> Batch:
        return Batch(self)


class FakeTransaction:
    def create(self, reference: Document, value: dict[str, Any]) -> None:
        reference.create(value)

    def update(self, reference: Document, value: dict[str, Any]) -> None:
        reference.update(value)

    def delete(self, reference: Document) -> None:
        reference.delete()


class Query:
    def __init__(
        self,
        db: FakeFirestore,
        collection: str,
        field: str,
        expected: Any,
    ) -> None:
        self.db = db
        self.collection = collection
        self.field = field
        self.expected = expected
        self.order_field = ""

    def order_by(self, field: str) -> "Query":
        self.order_field = field
        return self

    def stream(self, **_kwargs: Any) -> list[Snapshot]:
        values = [
            (identifier, value)
            for identifier, value in self.db.data[self.collection].items()
            if value.get(self.field) == self.expected
        ]
        if self.order_field:
            values.sort(key=lambda item: item[1].get(self.order_field, 0))
        return [Snapshot(identifier, value) for identifier, value in values]


def valid_payload(*, loot: bool = False) -> dict[str, Any]:
    start = datetime.now(IST) + timedelta(days=2)
    if loot:
        while start.weekday() not in (5, 6):
            start += timedelta(days=1)
    return {
        "mode": "  BR   Ranked  ",
        "team": "Solo",
        "map": "Bermuda",
        "fee": 0 if loot else "50",
        "slots": "48",
        "duration": "25",
        "start": start.replace(tzinfo=None).isoformat(timespec="minutes"),
        "place_amt": ["500", "250"],
        "per_kill": "10",
        "loot": loot,
    }


class TournamentServiceTests(unittest.TestCase):
    def test_saving_room_details_notifies_entrants_with_password(self) -> None:
        db = FakeFirestore()
        db.data["tournaments"]["tournament-1"] = {
            "mode": "BR Solo",
            "roomId": "",
            "roomPass": "",
        }
        db.data["tournamentEntries"]["entry-1"] = {
            "uid": "player-1",
            "tournamentId": "tournament-1",
        }
        counts = {"sent": 1, "failed": 0, "no_device": 0, "inbox_saved": 1}

        with (
            patch.object(
                tournament_service,
                "run_transaction",
                side_effect=lambda _db, operation: operation(FakeTransaction()),
            ),
            patch.object(
                tournament_service, "notify_users", return_value=counts
            ) as notify,
        ):
            result, notified = save_room_details(
                "tournament-1", " room-123 ", " pass-123 ", db=db
            )

        self.assertTrue(notified)
        self.assertEqual(db.data["tournaments"]["tournament-1"]["roomId"], "room-123")
        self.assertEqual(db.data["tournaments"]["tournament-1"]["roomPass"], "pass-123")
        notify.assert_called_once()
        self.assertEqual(notify.call_args.args[0], ["player-1"])
        self.assertIn("Room ID: room-123. Password: pass-123.", notify.call_args.args[2])
        self.assertEqual(notify.call_args.kwargs["category"], "tournament_room")
        self.assertEqual(result["notificationCounts"], counts)

    def test_joined_matches_include_only_account_entries_and_approved_rewards(self) -> None:
        db = FakeFirestore()
        now = datetime.now(IST)
        db.data["tournaments"] = {
            "upcoming": {
                "mode": "Solo Cup",
                "team": "Solo",
                "map": "Bermuda",
                "startAt": now + timedelta(hours=2),
                "durationMin": 25,
                "slots": 48,
                "joinedCount": 2,
            },
            "completed": {
                "mode": "Duo Cup",
                "team": "Duo",
                "map": "Purgatory",
                "startAt": now - timedelta(hours=1),
                "durationMin": 25,
                "slots": 24,
                "joinedCount": 8,
                "roomId": "room-123",
                "roomPass": "pass-123",
            },
            "other-player-match": {
                "mode": "Other Match",
                "startAt": now - timedelta(hours=1),
                "durationMin": 25,
            },
        }
        db.data["tournamentEntries"] = {
            "entry-upcoming": {
                "uid": "player-1",
                "tournamentId": "upcoming",
                "slot": 7,
            },
            "entry-completed": {
                "uid": "player-1",
                "tournamentId": "completed",
                "slot": 14,
            },
            "entry-other": {"uid": "player-2", "tournamentId": "other-player-match"},
        }
        completed_result_id = hashlib.sha256(
            b"completed:player-1"
        ).hexdigest()
        db.data["tournamentResults"][completed_result_id] = {
            "uid": "player-1",
            "tournamentId": "completed",
            "status": "approved",
            "amount": 350,
        }

        matches = joined_matches("player-1", db)

        self.assertEqual(
            [(match["tournamentId"], match["status"]) for match in matches],
            [("upcoming", "upcoming"), ("completed", "completed")],
        )
        self.assertEqual(matches[1]["result"], {"declared": True, "won": 350})
        self.assertEqual(matches[1]["roomId"], "room-123")
        self.assertEqual(
            [match["mySlot"] for match in matches],
            [7, 14],
        )

    def test_team_slot_capacity_expands_to_individual_player_seats(self) -> None:
        db = FakeFirestore()
        db.data["tournaments"]["duo-match"] = {
            "team": "Duo",
            "slots": 24,
            "simulatedSlotsEnabled": True,
            "reservedSlots": [4, 5],
        }
        db.data["tournaments"]["squad-match"] = {
            "team": "Squad",
            "slots": 12,
        }
        db.data["tournamentEntries"]["taken-seat"] = {
            "tournamentId": "duo-match",
            "uid": "player-2",
            "slot": 2,
        }

        duo = slots_for_tournament("duo-match", "player-1", db)
        squad = slots_for_tournament("squad-match", "player-1", db)

        self.assertEqual(
            (duo["slots"], duo["teamSlots"], duo["teamSize"], duo["taken"]),
            (48, 24, 2, [2]),
        )
        self.assertEqual(duo["reserved"], [4, 5])
        self.assertEqual(
            (squad["slots"], squad["teamSlots"], squad["teamSize"]),
            (48, 12, 4),
        )
        self.assertEqual(
            tournament_service._present(
                "duo-match",
                {"team": "Duo", "slots": 24, "joinedCount": 17},
                datetime.now(timezone.utc),
            )["players"],
            "17/48",
        )

    def test_simulated_slots_are_randomly_reserved_from_unoccupied_seats(self) -> None:
        db = FakeFirestore()
        db.data["tournaments"]["match-1"] = {"team": "Solo", "slots": 8}
        db.data["tournamentEntries"]["entry-1"] = {
            "tournamentId": "match-1",
            "uid": "player-1",
            "slot": 3,
        }
        db.data["tournamentEntries"]["entry-2"] = {
            "tournamentId": "match-1",
            "uid": "player-2",
            "slot": 7,
        }
        transaction = FakeTransaction()

        with patch.object(
            tournament_service,
            "run_transaction",
            side_effect=lambda _db, operation: operation(transaction),
        ):
            enabled = tournament_service.set_simulated_slots(
                "match-1",
                True,
                4,
                db,
            )

        reserved = db.data["tournaments"]["match-1"]["reservedSlots"]
        self.assertTrue(enabled["simulatedSlotsEnabled"])
        self.assertEqual(len(reserved), 4)
        self.assertEqual(len(set(reserved)), 4)
        self.assertNotIn(3, reserved)
        self.assertNotIn(7, reserved)

        with patch.object(
            tournament_service,
            "run_transaction",
            side_effect=lambda _db, operation: operation(transaction),
        ):
            disabled = tournament_service.set_simulated_slots(
                "match-1",
                False,
                4,
                db,
            )

        self.assertFalse(disabled["simulatedSlotsEnabled"])
        self.assertEqual(disabled["reservedSlots"], [])

    def test_join_cannot_take_a_reserved_slot(self) -> None:
        db = FakeFirestore()
        db.data.setdefault("users", {})
        db.data["users"]["player-1"] = {
            "gameOk": True,
            "gameUid": "123456789",
            "ign": "Player One",
        }
        db.data["tournaments"]["match-1"] = {
            "team": "Solo",
            "slots": 8,
            "fee": 0,
            "startAt": datetime.now(timezone.utc) + timedelta(days=2),
            "durationMin": 25,
            "simulatedSlotsEnabled": True,
            "reservedSlots": [4],
        }

        with self.assertRaisesRegex(SlotAlreadyTaken, "reserved"):
            with patch.object(
                tournament_service,
                "run_transaction",
                side_effect=lambda _db, operation: operation(FakeTransaction()),
            ):
                tournament_service.join_tournament("player-1", "match-1", 4, db)

    def test_duo_join_accepts_last_individual_seat_beyond_team_count(self) -> None:
        db = FakeFirestore()
        db.data.setdefault("users", {})
        db.data.setdefault("wallets", {})
        db.data.setdefault("tournamentSlotClaims", {})
        db.data["users"]["player-1"] = {
            "gameOk": True,
            "gameUid": "123456789",
            "ign": "Player One",
        }
        db.data["tournaments"]["duo-match"] = {
            "team": "Duo",
            "slots": 24,
            "fee": 0,
            "joinedCount": 47,
            "simulatedSlotsEnabled": True,
            "reservedSlots": [2, 3],
            "startAt": datetime.now(timezone.utc) + timedelta(days=2),
            "durationMin": 25,
        }
        transaction = FakeTransaction()

        with patch.object(
            tournament_service,
            "run_transaction",
            side_effect=lambda _db, operation: operation(transaction),
        ):
            result = tournament_service.join_tournament(
                "player-1",
                "duo-match",
                48,
                db,
            )

        self.assertEqual(result["slot"], 48)
        self.assertEqual(
            next(iter(db.data["tournamentEntries"].values()))["slot"],
            48,
        )
        self.assertEqual(db.data["tournaments"]["duo-match"]["joinedCount"], 48)
        self.assertEqual(db.data["tournaments"]["duo-match"]["reservedSlots"], [2])

    def test_two_real_joins_release_two_reserved_seats(self) -> None:
        db = FakeFirestore()
        db.data["users"] = {
            "player-1": {
                "gameOk": True,
                "gameUid": "123456789",
                "ign": "Player One",
            },
            "player-2": {
                "gameOk": True,
                "gameUid": "987654321",
                "ign": "Player Two",
            },
        }
        db.data["tournaments"]["match-1"] = {
            "team": "Solo",
            "slots": 8,
            "fee": 0,
            "joinedCount": 0,
            "simulatedSlotsEnabled": True,
            "reservedSlots": [4, 5],
            "startAt": datetime.now(timezone.utc) + timedelta(days=2),
            "durationMin": 25,
        }

        for uid, slot in (("player-1", 1), ("player-2", 2)):
            with patch.object(
                tournament_service,
                "run_transaction",
                side_effect=lambda _db, operation: operation(FakeTransaction()),
            ):
                tournament_service.join_tournament(uid, "match-1", slot, db)

        tournament = db.data["tournaments"]["match-1"]
        self.assertEqual(tournament["joinedCount"], 2)
        self.assertEqual(tournament["reservedSlots"], [])

    def test_join_rejects_seat_beyond_team_capacity(self) -> None:
        db = FakeFirestore()
        db.data.setdefault("users", {})
        db.data.setdefault("wallets", {})
        db.data.setdefault("tournamentSlotClaims", {})
        db.data["users"]["player-1"] = {
            "gameOk": True,
            "gameUid": "123456789",
            "ign": "Player One",
        }
        db.data["tournaments"]["duo-match"] = {
            "team": "Duo",
            "slots": 24,
            "fee": 0,
            "joinedCount": 48,
            "startAt": datetime.now(timezone.utc) + timedelta(days=2),
            "durationMin": 25,
        }

        with self.assertRaisesRegex(TournamentJoinError, "valid slot"):
            with patch.object(
                tournament_service,
                "run_transaction",
                side_effect=lambda _db, operation: operation(FakeTransaction()),
            ):
                tournament_service.join_tournament(
                    "player-1",
                    "duo-match",
                    49,
                    db,
                )

    def test_create_and_reuse_default_persist_to_shared_collections(self) -> None:
        db = FakeFirestore()
        created = create_tournament(
            valid_payload(),
            save_as_default=True,
            db=db,
        )

        self.assertEqual(len(db.data["tournaments"]), 1)
        self.assertEqual(len(db.data["tournamentDefaults"]), 1)
        stored = db.data["tournaments"][created["id"]]
        self.assertEqual(stored["mode"], "BR Ranked")
        self.assertEqual(stored["prize"], 1220)
        self.assertEqual(stored["fee"], 50)
        self.assertFalse(stored["simulatedSlotsEnabled"])
        self.assertEqual(stored["simulatedSlotsCount"], 0)
        self.assertEqual(stored["reservedSlots"], [])

        default_id = next(iter(db.data["tournamentDefaults"]))
        future = datetime.now(IST) + timedelta(days=3)
        reused = create_from_default(
            default_id,
            future.replace(tzinfo=None).isoformat(timespec="minutes"),
            simulated_slots_count=3,
            db=db,
        )
        self.assertNotEqual(created["id"], reused["id"])
        self.assertEqual(len(db.data["tournaments"]), 2)
        self.assertEqual(len(db.data["tournamentDefaults"]), 1)
        reused_tournament = db.data["tournaments"][reused["id"]]
        self.assertTrue(reused_tournament["simulatedSlotsEnabled"])
        self.assertEqual(reused_tournament["simulatedSlotsCount"], 3)
        self.assertEqual(len(reused_tournament["reservedSlots"]), 3)

    def test_create_reservations_reject_counts_above_capacity(self) -> None:
        payload = valid_payload()
        payload["simulatedSlotsCount"] = 49

        with self.assertRaisesRegex(TournamentInputError, "between 0 and 48"):
            create_tournament(payload, db=FakeFirestore())

    def test_loot_is_free_and_weekend_only(self) -> None:
        payload = valid_payload(loot=True)
        validated = validate_tournament(payload)
        self.assertTrue(validated["loot"])
        self.assertEqual(validated["fee"], 0)

        weekday = datetime.now(IST) + timedelta(days=2)
        while weekday.weekday() in (5, 6):
            weekday += timedelta(days=1)
        payload["start"] = weekday.replace(tzinfo=None).isoformat(timespec="minutes")
        with self.assertRaisesRegex(TournamentInputError, "Saturday or Sunday"):
            validate_tournament(payload)

    def test_dashboard_counts_derive_from_saved_schedule(self) -> None:
        db = FakeFirestore()
        create_tournament(valid_payload(), db=db)
        self.assertEqual(dashboard_counts(db)["total"], 1)
        self.assertEqual(dashboard_counts(db)["upcoming"], 1)

    def test_rejects_non_integer_money(self) -> None:
        payload = valid_payload()
        payload["fee"] = "10.5"
        with self.assertRaisesRegex(TournamentInputError, "whole number"):
            validate_tournament(payload)

    def test_joined_players_show_only_real_occupied_slots_in_order(self) -> None:
        from app.services.tournament_service import list_joined_players

        db = FakeFirestore()
        db.data["tournaments"]["tournament-1"] = {
            "mode": "BR Solo",
            "team": "Solo",
            "map": "Bermuda",
            "slots": 20,
            "joinedCount": 2,
            "startAt": datetime.now(IST) + timedelta(days=1),
            "durationMin": 25,
        }
        db.data["tournamentEntries"] = {
            "entry-3": {
                "tournamentId": "tournament-1",
                "slot": 3,
                "ign": "Third",
                "gameUid": "33333333",
            },
            "entry-1": {
                "tournamentId": "tournament-1",
                "slot": 1,
                "ign": "First",
                "gameUid": "11111111",
            },
        }

        tournament, rows = list_joined_players("tournament-1", db)

        self.assertEqual(tournament["joined"], 2)
        self.assertEqual([row["slot"] for row in rows], [1, 3])
        self.assertEqual([row["ign"] for row in rows], ["First", "Third"])

    def test_entry_fee_uses_deposited_then_bonus_then_winnings(self) -> None:
        self.assertEqual(
            entry_fee_deltas(
                {"deposited": 5, "bonus": 3, "winnings": 10},
                10,
            ),
            {"deposited": -5, "bonus": -3, "winnings": -2},
        )
        with self.assertRaises(InsufficientFunds):
            entry_fee_deltas(
                {"deposited": 5, "bonus": 3, "winnings": 1},
                10,
            )

    def test_delete_refunds_joined_players_and_removes_slot_claims(self) -> None:
        db = FakeFirestore()
        db.data["tournaments"]["tournament-1"] = {
            "mode": "BR Solo",
            "fee": 50,
            "slots": 20,
            "joinedCount": 1,
            "startAt": datetime.now(IST) + timedelta(days=1),
            "durationMin": 25,
        }
        db.data["tournamentEntries"]["entry-1"] = {
            "tournamentId": "tournament-1",
            "uid": "player-1",
            "slot": 3,
        }
        db.data.setdefault("tournamentSlotClaims", {})
        db.data["tournamentSlotClaims"]["tournament-1_3"] = {
            "tournamentId": "tournament-1",
            "uid": "player-1",
            "slot": 3,
        }

        with (
            patch.object(
                tournament_service,
                "run_transaction",
                side_effect=lambda _db, operation: operation(FakeTransaction()),
            ),
            patch.object(
                tournament_service,
                "apply",
                return_value={"total": 150, "ledgerId": "refund-1"},
            ) as apply,
            patch.object(tournament_service, "deliver_to_user") as deliver,
        ):
            result = delete_tournament("tournament-1", db)

        self.assertEqual(
            result,
            {"refunded_players": 1, "refunded_amount": 50},
        )
        apply.assert_called_once()
        self.assertEqual(apply.call_args.args[0], "player-1")
        self.assertEqual(
            apply.call_args.args[1]["deltas"],
            {"deposited": 50},
        )
        self.assertEqual(apply.call_args.args[1]["kind"], "refund")
        self.assertEqual(len(db.data["notifications"]), 1)
        notification = next(iter(db.data["notifications"].values()))
        self.assertEqual(notification["uid"], "player-1")
        self.assertEqual(notification["category"], "tournament_cancel")
        self.assertIn("cancelled", notification["body"])
        self.assertIn("₹50", notification["body"])
        deliver.assert_called_once()
        self.assertEqual(deliver.call_args.args[0], "player-1")
        self.assertEqual(
            deliver.call_args.kwargs["notification_id"],
            next(iter(db.data["notifications"])),
        )
        self.assertNotIn("tournament-1", db.data["tournaments"])
        self.assertNotIn("entry-1", db.data["tournamentEntries"])
        self.assertNotIn("tournament-1_3", db.data["tournamentSlotClaims"])

    def test_completed_tournament_can_be_deleted_with_refund(self) -> None:
        db = FakeFirestore()
        db.data["tournaments"]["tournament-1"] = {
            "mode": "BR Solo",
            "fee": 50,
            "slots": 20,
            "joinedCount": 1,
            "startAt": datetime.now(IST) - timedelta(days=1),
            "durationMin": 25,
        }
        db.data["tournamentEntries"]["entry-1"] = {
            "tournamentId": "tournament-1",
            "uid": "player-1",
            "slot": 3,
        }

        with (
            patch.object(
                tournament_service,
                "run_transaction",
                side_effect=lambda _db, operation: operation(FakeTransaction()),
            ),
            patch.object(tournament_service, "apply", return_value={"total": 150}),
            patch.object(tournament_service, "deliver_to_user") as deliver,
        ):
            result = delete_tournament("tournament-1", db)

        self.assertEqual(result["refunded_players"], 1)
        deliver.assert_called_once()
        self.assertNotIn("tournament-1", db.data["tournaments"])

    def test_deleting_free_tournament_notifies_joined_player(self) -> None:
        db = FakeFirestore()
        db.data["tournaments"]["tournament-1"] = {
            "mode": "Free match",
            "fee": 0,
            "slots": 20,
            "joinedCount": 1,
        }
        db.data["tournamentEntries"]["entry-1"] = {
            "tournamentId": "tournament-1",
            "uid": "player-1",
            "slot": 1,
        }

        with (
            patch.object(
                tournament_service,
                "run_transaction",
                side_effect=lambda _db, operation: operation(FakeTransaction()),
            ),
            patch.object(tournament_service, "apply") as apply,
            patch.object(tournament_service, "deliver_to_user") as deliver,
        ):
            result = delete_tournament("tournament-1", db)

        self.assertEqual(
            result,
            {"refunded_players": 0, "refunded_amount": 0},
        )
        apply.assert_not_called()
        self.assertEqual(len(db.data["notifications"]), 1)
        self.assertIn(
            "No entry fee was charged",
            next(iter(db.data["notifications"].values()))["body"],
        )
        deliver.assert_called_once()


if __name__ == "__main__":
    unittest.main()
