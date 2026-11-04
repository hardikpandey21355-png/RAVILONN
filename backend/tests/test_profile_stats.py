import unittest
from typing import Any

from app.services.admin_service import profile_stats


class Snapshot:
    def __init__(self, value: dict[str, Any]) -> None:
        self._value = value

    def to_dict(self) -> dict[str, Any]:
        return dict(self._value)


class Query:
    def __init__(
        self,
        records: list[dict[str, Any]],
        field: str,
        expected: Any,
    ) -> None:
        self.records = records
        self.field = field
        self.expected = expected

    def stream(self) -> list[Snapshot]:
        return [
            Snapshot(record)
            for record in self.records
            if record.get(self.field) == self.expected
        ]


class Collection:
    def __init__(self, records: list[dict[str, Any]]) -> None:
        self.records = records

    def where(self, field: str, _operator: str, expected: Any) -> Query:
        return Query(self.records, field, expected)


class FakeFirestore:
    def __init__(self) -> None:
        self.entries = [
            {"uid": "player-1", "tournamentId": "match-1"},
            {"uid": "player-1", "tournamentId": "match-2"},
            {"uid": "player-2", "tournamentId": "match-3"},
        ]
        self.results = [
            {
                "uid": "player-1",
                "status": "approved",
                "kills": 2,
                "amount": 500,
            },
            {
                "uid": "player-1",
                "status": "approved",
                "kills": 5,
                "amount": 0,
            },
            {
                "uid": "player-1",
                "status": "draft",
                "kills": 99,
                "amount": 9999,
            },
        ]

    def collection(self, name: str) -> Collection:
        return Collection(
            self.entries if name == "tournamentEntries" else self.results
        )


class ProfileStatsTests(unittest.TestCase):
    def test_stats_count_joins_and_only_approved_results(self) -> None:
        self.assertEqual(
            profile_stats("player-1", FakeFirestore()),
            {"matches": 2, "wins": 1, "kills": 7, "earned": 500},
        )
