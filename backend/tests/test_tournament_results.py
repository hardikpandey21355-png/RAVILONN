import unittest
from typing import Any
from unittest.mock import patch

from app.services import admin_service, wallet_service
from app.services.admin_service import AdminOperationError


class Snapshot:
    def __init__(self, reference: "Document", value: dict[str, Any] | None) -> None:
        self.reference = reference
        self.id = reference.id
        self.exists = value is not None
        self._value = value

    def to_dict(self) -> dict[str, Any]:
        return dict(self._value or {})


class Document:
    def __init__(self, db: "FakeFirestore", collection: str, identifier: str) -> None:
        self.db = db
        self.collection = collection
        self.id = identifier

    def get(self, **_kwargs: Any) -> Snapshot:
        return Snapshot(self, self.db.data[self.collection].get(self.id))

    def set(self, value: dict[str, Any], merge: bool = False) -> None:
        if merge:
            self.db.data[self.collection].setdefault(self.id, {}).update(value)
        else:
            self.db.data[self.collection][self.id] = dict(value)

    def create(self, value: dict[str, Any]) -> None:
        if self.id in self.db.data[self.collection]:
            raise ValueError("Document already exists.")
        self.db.data[self.collection][self.id] = dict(value)


class Query:
    def __init__(
        self,
        db: "FakeFirestore",
        collection: str,
        field: str,
        expected: Any,
    ) -> None:
        self.db = db
        self.collection = collection
        self.field = field
        self.expected = expected

    def stream(self) -> list[Snapshot]:
        return [
            Snapshot(Document(self.db, self.collection, identifier), value)
            for identifier, value in self.db.data[self.collection].items()
            if value.get(self.field) == self.expected
        ]


class Collection:
    def __init__(self, db: "FakeFirestore", name: str) -> None:
        self.db = db
        self.name = name

    def document(self, identifier: str | None = None) -> Document:
        if identifier is None:
            self.db.next_id += 1
            identifier = f"transaction-{self.db.next_id}"
        return Document(self.db, self.name, identifier)

    def where(self, field: str, _operator: str, expected: Any) -> Query:
        return Query(self.db, self.name, field, expected)


class Transaction:
    def set(
        self,
        reference: Document,
        value: dict[str, Any],
        merge: bool = False,
    ) -> None:
        reference.set(value, merge)

    def create(self, reference: Document, value: dict[str, Any]) -> None:
        reference.create(value)


class FakeFirestore:
    def __init__(self) -> None:
        self.data: dict[str, dict[str, dict[str, Any]]] = {
            "tournaments": {"match-1": {"status": "completed"}},
            "tournamentEntries": {
                "entry-1": {"uid": "player-1", "tournamentId": "match-1"}
            },
            "tournamentResults": {},
            "users": {"player-1": {"uid": "player-1"}},
            "wallets": {"player-1": {"winnings": 100}},
            "transactions": {},
        }
        self.next_id = 0

    def collection(self, name: str) -> Collection:
        self.data.setdefault(name, {})
        return Collection(self, name)


class TournamentResultsTests(unittest.TestCase):
    def test_approval_credits_once_and_publishes_stats_from_approved_record(self) -> None:
        db = FakeFirestore()

        def run_transaction(_db: Any, operation: Any) -> Any:
            return operation(Transaction())

        with (
            patch.object(admin_service, "get_db", return_value=db),
            patch.object(wallet_service, "get_db", return_value=db),
            patch.object(admin_service, "run_transaction", side_effect=run_transaction),
        ):
            approved = admin_service.approve_tournament_results(
                "match-1",
                [{"uid": "player-1", "kills": 7, "place": 1, "amount": 500}],
                admin_uid="admin-1",
                db=db,
            )
            stats = admin_service.profile_stats("player-1", db)

            with self.assertRaisesRegex(AdminOperationError, "paid twice"):
                admin_service.approve_tournament_results(
                    "match-1",
                    [{"uid": "player-1", "kills": 7, "place": 1, "amount": 500}],
                    admin_uid="admin-1",
                    db=db,
                )

        self.assertEqual(approved, 1)
        self.assertEqual(db.data["wallets"]["player-1"]["winnings"], 600)
        self.assertEqual(len(db.data["transactions"]), 1)
        ledger = next(iter(db.data["transactions"].values()))
        self.assertEqual(ledger["kind"], "match_reward")
        self.assertEqual(ledger["amt"], 500)
        self.assertEqual(ledger["dir"], "in")
        self.assertEqual(ledger["balanceAfter"], 600)
        self.assertEqual(stats, {"matches": 1, "wins": 1, "kills": 7, "earned": 500})

    def test_zero_reward_result_counts_kills_without_a_wallet_credit(self) -> None:
        db = FakeFirestore()

        def run_transaction(_db: Any, operation: Any) -> Any:
            return operation(Transaction())

        with (
            patch.object(admin_service, "get_db", return_value=db),
            patch.object(wallet_service, "get_db", return_value=db),
            patch.object(admin_service, "run_transaction", side_effect=run_transaction),
        ):
            admin_service.approve_tournament_results(
                "match-1",
                [{"uid": "player-1", "kills": 4, "place": 0, "amount": 0}],
                db=db,
            )

        self.assertEqual(db.data["wallets"]["player-1"]["winnings"], 100)
        self.assertEqual(db.data["transactions"], {})
        self.assertEqual(
            admin_service.profile_stats("player-1", db),
            {"matches": 1, "wins": 0, "kills": 4, "earned": 0},
        )
