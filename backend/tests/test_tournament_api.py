import unittest
from unittest.mock import patch
from typing import Any

from app import create_app


class TournamentApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.app = create_app(
            {
                "TESTING": True,
                "FIREBASE_TOKEN_VERIFIER": self.verify_token,
            }
        )
        self.client = self.app.test_client()

    def verify_token(self, token: str) -> dict[str, Any]:
        if token != "valid-test-token":
            raise ValueError("Invalid token")
        return {"uid": "player-1"}

    def auth_headers(self) -> dict[str, str]:
        return {"Authorization": "Bearer valid-test-token"}

    def test_tournament_list_requires_authentication(self) -> None:
        response = self.client.get("/api/tournaments")
        self.assertEqual(response.status_code, 401)
        self.assertFalse(response.json["ok"])

    def test_profile_stats_requires_authentication(self) -> None:
        response = self.client.get("/api/profile/stats")
        self.assertEqual(response.status_code, 401)
        self.assertFalse(response.json["ok"])

    def test_profile_stats_returns_approved_match_totals(self) -> None:
        with (
            patch("app.routes._require_user", return_value=({}, None)),
            patch(
                "app.routes.profile_stats",
                return_value={"matches": 4, "wins": 2, "kills": 7, "earned": 1250},
            ),
            patch(
                "app.services.settings_service.get_settings",
                return_value={"maintenance": False},
            ),
        ):
            response = self.client.get(
                "/api/profile/stats",
                headers={"Authorization": "Bearer valid-test-token"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json,
            {
                "ok": True,
                "matches": 4,
                "wins": 2,
                "kills": 7,
                "earned": 1250,
            },
        )

    def test_authenticated_list_returns_shared_tournament_fields(self) -> None:
        records = [
            {
                "id": "tournament-1",
                "game": "Free Fire",
                "mode": "BR Ranked",
                "team": "Solo",
                "map": "Bermuda",
                "fee": 50,
                "prize": 1000,
                "joined": 0,
                "slots": 48,
                "players": "0/48",
                "status": "upcoming",
                "loot": False,
                "roomId": "private-room-id",
                "roomPass": "private-room-pass",
                "room_id": "private-room-id",
                "room_pass": "private-room-pass",
                "startAt": None,
                "_startAt": None,
            },
            {
                "id": "deleting-tournament",
                "status": "deleting",
                "isDeleting": True,
                "startAt": None,
                "_startAt": None,
            },
        ]
        with (
            patch("app.routes.list_tournaments", return_value=records),
            patch("app.routes._require_user", return_value=({}, None)),
            patch("app.routes.joined_tournament_slots", return_value={}),
            patch(
                "app.routes.wallet_for",
                return_value={
                    "deposited": 0,
                    "bonus": 0,
                    "winnings": 0,
                    "total": 0,
                },
            ),
            patch(
                "app.routes.get_settings",
                return_value={
                    "maintenance": False,
                    "maintenanceMessage": "We will be back shortly.",
                    "maintenanceEta": "",
                },
            ),
        ):
            response = self.client.get(
                "/api/tournaments",
                headers={"Authorization": "Bearer valid-test-token"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["tournaments"][0]["id"], "tournament-1")
        self.assertEqual(len(response.json["tournaments"]), 1)
        self.assertNotIn("_startAt", response.json["tournaments"][0])
        self.assertFalse(response.json["tournaments"][0]["joinedByMe"])
        self.assertIsNone(response.json["tournaments"][0]["mySlot"])
        for field in ("roomId", "roomPass", "room_id", "room_pass"):
            self.assertNotIn(field, response.json["tournaments"][0])
        self.assertFalse(response.json["maintenance"]["on"])

    def test_tournament_list_excludes_completed_and_deleting_items(self) -> None:
        records = [
            {"id": "upcoming", "status": "upcoming", "_startAt": None},
            {"id": "completed", "status": "completed", "_startAt": None},
            {"id": "live", "status": "live", "_startAt": None},
            {"id": "deleting", "status": "deleting", "isDeleting": True},
        ]
        with (
            patch("app.routes.list_tournaments", return_value=records),
            patch("app.routes._require_user", return_value=({}, None)),
            patch("app.routes.joined_tournament_slots", return_value={}),
            patch("app.routes.wallet_for", return_value={}),
            patch("app.routes.get_settings", return_value={"maintenance": False}),
        ):
            response = self.client.get(
                "/api/tournaments",
                headers=self.auth_headers(),
            )

        self.assertEqual(response.status_code, 200, response.json)
        self.assertEqual(
            [item["id"] for item in response.json["tournaments"]],
            ["upcoming", "live"],
        )

    def test_matches_endpoint_returns_only_joined_user_matches(self) -> None:
        matches = [
            {"tournamentId": "joined-match", "status": "completed"},
        ]
        with (
            patch("app.routes._require_user", return_value=({}, None)),
            patch("app.routes.joined_matches", return_value=matches) as load_matches,
            patch(
                "app.services.settings_service.get_settings",
                return_value={"maintenance": False},
            ),
        ):
            response = self.client.get(
                "/api/matches",
                headers=self.auth_headers(),
            )

        self.assertEqual(response.status_code, 200, response.json)
        self.assertEqual(response.json, {"ok": True, "matches": matches})
        load_matches.assert_called_once_with("player-1")

    def test_joined_player_receives_tournament_room_details(self) -> None:
        records = [
            {
                "id": "tournament-1",
                "status": "upcoming",
                "roomId": "room-123",
                "roomPass": "pass-123",
                "room_id": "room-123",
                "room_pass": "pass-123",
                "_startAt": None,
            },
        ]
        with (
            patch("app.routes.list_tournaments", return_value=records),
            patch("app.routes._require_user", return_value=({}, None)),
            patch(
                "app.routes.joined_tournament_slots",
                return_value={"tournament-1": 4},
            ),
            patch(
                "app.routes.wallet_for",
                return_value={"deposited": 0, "bonus": 0, "winnings": 0, "total": 0},
            ),
            patch(
                "app.routes.get_settings",
                return_value={
                    "maintenance": False,
                    "maintenanceMessage": "We will be back shortly.",
                    "maintenanceEta": "",
                },
            ),
        ):
            response = self.client.get(
                "/api/tournaments",
                headers={"Authorization": "Bearer valid-test-token"},
            )

        self.assertEqual(response.status_code, 200, response.json)
        tournament = response.json["tournaments"][0]
        self.assertTrue(tournament["joinedByMe"])
        self.assertEqual(tournament["mySlot"], 4)
        self.assertEqual(tournament["roomId"], "room-123")
        self.assertEqual(tournament["roomPass"], "pass-123")
        self.assertEqual(tournament["room_id"], "room-123")
        self.assertEqual(tournament["room_pass"], "pass-123")

    def test_join_requires_auth_and_rejects_maintenance_mode(self) -> None:
        response = self.client.post(
            "/api/tournaments/tournament-1/join",
            json={"slot": 1},
        )
        self.assertEqual(response.status_code, 401)

        with patch(
            "app.services.settings_service.get_settings",
            return_value={
                "maintenance": True,
                "maintenanceMessage": "Back soon",
                "maintenanceEta": "10 minutes",
            },
        ), patch("app.routes.join_tournament") as join:
            response = self.client.post(
                "/api/tournaments/tournament-1/join",
                json={"slot": 1},
                headers={"Authorization": "Bearer valid-test-token"},
            )

        self.assertEqual(response.status_code, 503, response.json)
        self.assertTrue(response.json["maintenance"])
        self.assertEqual(response.json["message"], "Back soon")
        join.assert_not_called()


if __name__ == "__main__":
    unittest.main()
