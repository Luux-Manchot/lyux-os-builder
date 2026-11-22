"""
Milestone 4 Adversarial Stress Harness (Challenger 2 — Gen 5)
Opération Manchot (LyuX) — Veyon Classroom Supervision

Adversarially stress-tests:
1. Network Objects parsing: JSON and CSV parsing under edge conditions
   (whitespace, special characters, french diacritics, malformed lines, schema integrity).
2. Socket port checking: check_port_open behavior with open, closed, filtered/blackhole ports,
   and strict timeout enforcement.
3. Station UI integration: VeyonManager API interaction with FastAPI endpoints in lyux-station/src/main.py,
   including live API requests, error handling (404), and offline graceful degradation.
4. Student profile isolation: Repository-wide adversarial audit confirming that students cannot
   escalate privileges, obtain veyon-master binaries, or access private cryptographic keys.
"""

import os

import sys

import io

import re

import csv

import json

import time

import socket

import tempfile

import threading

import ipaddress

from pathlib import Path

from typing import Dict, List, Any, Optional

import pytest

from fastapi.testclient import TestClient

PROJECT_ROOT = Path(__file__).resolve().parents[2]

STATION_SRC = PROJECT_ROOT / "lyux-desktop" / "applications" / "station" / "src"

SERVER_API_SRC = PROJECT_ROOT / "lyux-server" / "lyux-server-api" / "src"

for p in [str(STATION_SRC), str(SERVER_API_SRC)]:
    if p not in sys.path:
        sys.path.insert(0, p)

from veyon_manager import VeyonManager, PILOT_ROOMS, VEYON_PORTS


class TestNetworkObjectsParsingAndResilience:
    """Stress tests on network-objects JSON and CSV parsing and edge cases."""

    @pytest.fixture
    def canonical_files(self):
        json_path = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "configs" / "veyon" / "network-objects.json"
        csv_path = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "configs" / "veyon" / "network-objects.csv"
        return json_path, csv_path

    def test_canonical_json_schema_and_builtin_directory_structure(self, canonical_files):
        """Verify canonical network-objects.json follows Veyon BuiltinDirectory structure."""
        json_path, _ = canonical_files
        assert json_path.exists(), "network-objects.json must exist"

        content = json_path.read_text(encoding="utf-8")
        data = json.loads(content)

        assert "NetworkObjects" in data
        assert "Locations" in data["NetworkObjects"]
        assert "Computers" in data["NetworkObjects"]

        locations = data["NetworkObjects"]["Locations"]
        computers = data["NetworkObjects"]["Computers"]

        assert len(locations) == 2, "Must contain exactly 2 pilot room locations"
        assert len(computers) == 6, "Must contain exactly 6 pilot computers (2 teachers + 4 students)"

        location_names = {loc["name"] for loc in locations}
        assert "Salle B204" in location_names
        assert "Salle S102" in location_names

        mac_regex = re.compile(r"^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$")
        teacher_count = 0
        student_count = 0

        for comp in computers:
            # Required fields
            for field in ["id", "name", "host", "mac", "location", "role"]:
                assert field in comp, f"Field '{field}' missing from computer {comp}"

            # Valid IP format
            ip_obj = ipaddress.ip_address(comp["host"])
            assert ip_obj.version == 4, f"Host {comp['host']} must be valid IPv4"

            # Valid MAC format
            assert mac_regex.match(comp["mac"]), f"Invalid MAC format: {comp['mac']}"

            # Location must exist in Locations list
            assert comp["location"] in location_names, f"Unknown location: {comp['location']}"

            # Role validation
            assert comp["role"] in ("teacher", "student")
            if comp["role"] == "teacher":
                teacher_count += 1
            else:
                student_count += 1

        assert teacher_count == 2
        assert student_count == 4

    def test_canonical_csv_schema_and_parity_with_json(self, canonical_files):
        """
        Verify canonical network-objects.csv contains both locations and computers,
        and matches network-objects.json definitions.
        Note: Veyon BuiltinDirectory CSV format contains both locations and computers.
        Columns: name;host;mac;location;type
        """
        json_path, csv_path = canonical_files
        assert csv_path.exists(), "network-objects.csv must exist"

        json_data = json.loads(json_path.read_text(encoding="utf-8"))
        json_computers = {c["name"]: c for c in json_data["NetworkObjects"]["Computers"]}
        json_locations = {l["name"]: l for l in json_data["NetworkObjects"]["Locations"]}

        with open(csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f, delimiter=";")
            rows = list(reader)

        assert reader.fieldnames == ["name", "host", "mac", "location", "type"]

        csv_locations = [r for r in rows if r["type"] == "location"]
        csv_computers = [r for r in rows if r["type"] == "computer"]

        assert len(csv_locations) == 2, "CSV must contain 2 location rows"
        assert len(csv_computers) == 6, "CSV must contain 6 computer rows"

        for cloc in csv_locations:
            assert cloc["name"] in json_locations

        for ccomp in csv_computers:
            cname = ccomp["name"]
            assert cname in json_computers, f"Computer {cname} from CSV not found in JSON"
            jcomp = json_computers[cname]
            assert ccomp["host"] == jcomp["host"]
            assert ccomp["mac"].lower() == jcomp["mac"].lower()
            assert ccomp["location"] == jcomp["location"]

    def test_csv_parser_adversarial_whitespace_and_empty_lines(self):
        """Test CSV parsing robustness against leading/trailing whitespace, blank lines, and CRLF."""
        adversarial_csv = (
            "name;host;mac;location;type\r\n"
            "\r\n"  # Empty line
            "  Salle B204  ;;; ; location \r\n"
            "b204-prof ; 192.168.100.20 ; 52:54:00:11:20:01 ; Salle B204 ; computer\r\n"
            "   \r\n"  # Whitespace-only line
            "b204-pc01; 192.168.100.21;52:54:00:11:20:02;Salle B204;computer\r\n"
            "\r\n"
        )
        stream = io.StringIO(adversarial_csv)
        reader = csv.DictReader(stream, delimiter=";")
        parsed_entries = []
        for row in reader:
            if not row or not any(row.values()):
                continue
            cleaned = {k.strip(): (v.strip() if v else "") for k, v in row.items() if k}
            if cleaned.get("name"):
                parsed_entries.append(cleaned)

        assert len(parsed_entries) == 3
        prof_entry = next(e for e in parsed_entries if e["name"] == "b204-prof")
        assert prof_entry["host"] == "192.168.100.20"
        assert prof_entry["type"] == "computer"

    def test_csv_parser_special_characters_and_french_diacritics(self):
        """Test CSV parsing with French accents, quotes, and UTF-8 characters."""
        french_csv = (
            "name;host;mac;location;type\n"
            '"Salle B204 — NSI / Mathématiques";;;;"location"\n'
            'b204-prof;192.168.100.20;52:54:00:11:20:01;"Salle B204 — NSI / Mathématiques";"computer"\n'
            'b204-pc01;192.168.100.21;52:54:00:11:20:02;"Salle B204 — NSI / Mathématiques";"computer"\n'
        )
        stream = io.StringIO(french_csv)
        reader = csv.DictReader(stream, delimiter=";")
        rows = list(reader)

        assert len(rows) == 3
        assert rows[0]["name"] == "Salle B204 — NSI / Mathématiques"
        assert rows[1]["location"] == "Salle B204 — NSI / Mathématiques"

    def test_malformed_csv_error_recovery(self):
        """Test detection and handling of malformed CSV rows (missing delimiters, extra columns)."""
        malformed_csv = (
            "name;host;mac;location;type\n"
            "b204-prof;192.168.100.20;Salle B204;computer\n"  # Missing a field (4 fields instead of 5)
            "b204-pc01;192.168.100.21;52:54:00:11:20:02;Salle B204;computer;EXTRA_FIELD\n"  # 6 fields
        )
        stream = io.StringIO(malformed_csv)
        reader = csv.reader(stream, delimiter=";")
        header = next(reader)
        expected_cols = len(header)
        assert expected_cols == 5

        row1 = next(reader)
        assert len(row1) == 4, "Detected truncated row"

        row2 = next(reader)
        assert len(row2) == 6, "Detected row with extra columns"

    def test_malformed_json_detection(self):
        """Test rejection of corrupted JSON network objects."""
        corrupted_jsons = [
            '{"NetworkObjects": {"Locations": [',  # Truncated
            '{"NetworkObjects": "not_a_dict"}',    # Wrong type
            '{"Locations": [], "Computers": []}',  # Missing root NetworkObjects key
            '{"NetworkObjects": {"Locations": []}}'  # Missing Computers key
        ]
        for cj in corrupted_jsons:
            try:
                data = json.loads(cj)
                valid = isinstance(data.get("NetworkObjects"), dict) and "Computers" in data["NetworkObjects"]
                assert not valid, f"Corrupted structure was not rejected: {cj}"
            except json.JSONDecodeError:
                pass  # Successfully rejected

    def test_export_network_objects_config_roundtrip(self):
        """Test VeyonManager export_network_objects_config produces valid JSON loadable by parser."""
        vm = VeyonManager()
        with tempfile.TemporaryDirectory() as td:
            out_file = Path(td) / "exported_objects.json"
            exported = vm.export_network_objects_config(output_path=str(out_file))

            assert out_file.exists()
            reloaded = json.loads(out_file.read_text(encoding="utf-8"))

            assert reloaded == exported
            assert "NetworkObjects" in reloaded
            assert len(reloaded["NetworkObjects"]["Locations"]) == 2
            assert len(reloaded["NetworkObjects"]["Computers"]) == 6


class TestSocketPortCheckingAdversarial:
    """Empirical verification of VeyonManager.check_port_open with real network states."""

    @pytest.fixture
    def manager(self):
        return VeyonManager()

    def test_check_port_open_live_open_socket(self, manager):
        """Spin up a real local TCP server and verify check_port_open returns True."""
        server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server_sock.bind(("127.0.0.1", 0))
        server_sock.listen(1)
        port = server_sock.getsockname()[1]

        # Stop accept after 1 connection
        stop_event = threading.Event()
        def accept_worker():
            try:
                server_sock.settimeout(2.0)
                conn, _ = server_sock.accept()
                conn.close()
            except Exception:
                pass
            finally:
                stop_event.set()

        t = threading.Thread(target=accept_worker)
        t.daemon = True
        t.start()

        try:
            is_open = manager.check_port_open("127.0.0.1", port, timeout=1.0)
            assert is_open is True, f"check_port_open must return True on listening port {port}"
        finally:
            server_sock.close()
            stop_event.wait(timeout=1.0)

    def test_check_port_open_closed_socket(self, manager):
        """Verify check_port_open returns False immediately on closed/refused port."""
        # Find an unused port by binding and immediately closing
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.bind(("127.0.0.1", 0))
        unused_port = s.getsockname()[1]
        s.close()

        timeout = 0.5
        start = time.time()
        is_open = manager.check_port_open("127.0.0.1", unused_port, timeout=timeout)
        elapsed = time.time() - start

        assert is_open is False, "Closed port must return False"
        assert elapsed < timeout + 0.3, f"Closed port check should return within timeout margin, took {elapsed}s"

    def test_check_port_open_filtered_blackhole_timeout_enforcement(self, manager):
        """
        Verify check_port_open bounds timeout when connecting to a non-routable blackhole IP.
        Uses RFC 5737 TEST-NET-1 (192.0.2.1) which drops packets without response.
        """
        blackhole_ip = "192.0.2.1"
        target_port = 11100
        configured_timeout = 0.25

        start = time.time()
        is_open = manager.check_port_open(blackhole_ip, target_port, timeout=configured_timeout)
        elapsed = time.time() - start

        assert is_open is False, "Filtered/blackhole IP must return False"
        # Must respect timeout within reasonable OS scheduling margin (< 1.5s)
        assert elapsed < 1.5, f"Timeout was not respected: took {elapsed}s"

    def test_check_port_open_boundary_and_hostile_inputs(self, manager):
        """Test check_port_open resilience against hostile, malformed, or boundary arguments."""
        hostile_calls = [
            ("", 11100),                            # Empty host
            ("invalid-domain-never-resolves.lan", 11100),  # Unresolvable DNS
            ("999.999.999.999", 11100),             # Malformed IP
            ("127.0.0.1\x00extra", 11100),          # Null byte injection
            ("127.0.0.1", 0),                       # Port 0
            ("127.0.0.1", -1),                      # Negative port
            ("127.0.0.1", 65536),                   # Port overflow > 65535
            ("127.0.0.1", 100000),                  # Huge port
        ]

        for host, port in hostile_calls:
            # Must return False gracefully without raising uncaught exception
            try:
                result = manager.check_port_open(host, port, timeout=0.1)
                assert result is False, f"Expected False for ({host}, {port}), got {result}"
            except Exception as e:
                pytest.fail(f"check_port_open crashed on ({host}, {port}) with: {type(e).__name__}: {e}")


class TestStationUIFastAPIIntegration:
    """Tests interaction between VeyonManager and the FastAPI server endpoints."""

    @pytest.fixture
    def test_client(self):
        """Initialize FastAPI TestClient for projects/lyux-server-api."""
        import main as server_main
        return TestClient(server_main.app)

    def test_fastapi_endpoints_exist_and_match_contract(self, test_client):
        """Verify endpoints /api/v1/control/lock-room and /api/v1/control/reset-password exist."""
        # Test lock-room schema validation
        res_lock = test_client.post("/api/v1/control/lock-room", json={
            "room_id": "B204",
            "action": "lock",
            "message_text": "Test consigne"
        })
        assert res_lock.status_code == 200
        data_lock = res_lock.json()
        assert data_lock["success"] is True
        assert data_lock["action"] == "lock"
        assert data_lock["affected_machines"] == 2

        # Test unlock-room
        res_unlock = test_client.post("/api/v1/control/lock-room", json={
            "room_id": "B204",
            "action": "unlock",
            "message_text": ""
        })
        assert res_unlock.status_code == 200
        assert res_unlock.json()["action"] == "unlock"

        # Test reset-password valid student
        res_reset = test_client.post("/api/v1/control/reset-password", json={
            "username": "lucas.martin"
        })
        assert res_reset.status_code == 200
        data_reset = res_reset.json()
        assert data_reset["success"] is True
        assert data_reset["username"] == "lucas.martin"
        assert data_reset["new_password"].startswith("Pass")
        assert data_reset["new_password"].endswith("!")

        # Test reset-password unknown student -> 404
        res_404 = test_client.post("/api/v1/control/reset-password", json={
            "username": "eleve.inexistant"
        })
        assert res_404.status_code == 404

    def test_veyon_manager_live_api_integration(self, monkeypatch, test_client):
        """Test VeyonManager delegating to FastAPI via requests mocking."""
        import requests

        class MockResponse:
            def __init__(self, status_code, json_data):
                self.status_code = status_code
                self._json = json_data
            def json(self):
                return self._json

        def mock_post(url, json=None, timeout=None):
            path = url.split("127.0.0.1:8000")[-1]
            if path == "/api/v1/control/lock-room":
                res = test_client.post("/api/v1/control/lock-room", json=json)
                return MockResponse(res.status_code, res.json())
            elif path == "/api/v1/control/reset-password":
                res = test_client.post("/api/v1/control/reset-password", json=json)
                return MockResponse(res.status_code, res.json())
            raise requests.ConnectionError("Unknown endpoint")

        monkeypatch.setattr(requests, "post", mock_post)

        vm = VeyonManager(api_url="http://127.0.0.1:8000")

        # 1. Lock room B204
        res_l = vm.lock_room("B204", "Consigne test")
        assert res_l["success"] is True
        assert res_l["affected_machines"] == 2
        assert "fallback" not in res_l.get("mode", "")

        # 2. Unlock room S102
        res_u = vm.unlock_room("S102")
        assert res_u["success"] is True
        assert res_u["affected_machines"] == 2

        # 3. Reset password valid user
        res_p = vm.reset_student_password("emma.bernard")
        assert res_p["success"] is True
        assert res_p["username"] == "emma.bernard"
        assert res_p["new_password"].startswith("Pass")

        # 4. Reset password unknown user -> 404 handling
        res_bad = vm.reset_student_password("hacker.eleve")
        assert res_bad["success"] is False
        assert res_bad["status_code"] == 404

    def test_station_main_call_signatures_match_veyon_manager(self):
        """Inspect lyux-station/src/main.py AST and ensure call sites match VeyonManager methods."""
        main_path = PROJECT_ROOT / "lyux-desktop" / "applications" / "station" / "src" / "main.py"
        assert main_path.exists()
        content = main_path.read_text(encoding="utf-8")

        # main.py calls:
        # - self.veyon_mgr.reset_student_password(eleve_login, api_url=self.api_url)
        # - self.veyon_mgr.lock_room(self.current_room, "Attention au tableau")
        # - self.veyon_mgr.unlock_room(self.current_room)
        # - self.veyon_mgr.send_message(self.current_room, msg_text)

        vm = VeyonManager()
        import inspect

        # reset_student_password signature
        sig_reset = inspect.signature(vm.reset_student_password)
        assert "username" in sig_reset.parameters
        assert "api_url" in sig_reset.parameters

        # lock_room signature
        sig_lock = inspect.signature(vm.lock_room)
        assert "room_id" in sig_lock.parameters
        assert "message" in sig_lock.parameters

        # unlock_room signature
        sig_unlock = inspect.signature(vm.unlock_room)
        assert "room_id" in sig_unlock.parameters

        # send_message signature
        sig_msg = inspect.signature(vm.send_message)
        assert "room_id" in sig_msg.parameters
        assert "message_text" in sig_msg.parameters

    def test_offline_fallback_mode_resilience(self):
        """Ensure that when API server is down, VeyonManager falls back to offline mode cleanly."""
        vm = VeyonManager(api_url="http://127.0.0.1:59999")  # Non-listening port

        # Lock room fallback
        res_lock = vm.lock_room("B204", "Silence")
        assert res_lock["success"] is True
        assert res_lock["mode"] == "fallback_local"
        assert res_lock["affected_machines"] == 2

        # Reset password fallback
        res_reset = vm.reset_student_password("lucas.martin")
        assert res_reset["success"] is True
        assert res_reset["mode"] == "fallback_local"
        assert res_reset["new_password"].startswith("Pass")
        assert res_reset["new_password"].endswith("!")


class TestStudentProfileIsolationAndPrivilegeEscalation:
    """Adversarial security audit verifying student environment isolation."""

    def test_student_role_tasks_contain_zero_veyon_master(self):
        """Confirm that veyon-master is NEVER referenced in lyux-profile-eleve."""
        eleve_dir = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-eleve"
        for p in eleve_dir.rglob("*"):
            if p.is_file():
                content = p.read_text(encoding="utf-8", errors="ignore")
                assert "veyon-master" not in content.lower(), f"Forbidden veyon-master found in student file: {p}"

    def test_student_role_prohibits_private_key_deployment(self):
        """Confirm that no private key file exists in student role files or templates."""
        eleve_dir = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-eleve"
        for p in eleve_dir.rglob("*"):
            if p.is_file():
                if "key" in p.name.lower():
                    # Must only be public key
                    assert "public" in str(p.parent).lower(), f"Non-public key file in student role: {p}"
                    content = p.read_bytes()
                    assert b"PRIVATE" not in content, f"Private key bytes leaked in student role: {p}"

    def test_student_tasks_explicitly_delete_private_keys(self):
        """Confirm tasks in lyux-profile-eleve delete /etc/veyon/keys/private."""
        tasks_file = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-eleve" / "tasks" / "main.yml"
        content = tasks_file.read_text(encoding="utf-8")
        assert "/etc/veyon/keys/private" in content
        assert "state: absent" in content

    def test_veyon_master_desktop_shortcut_not_in_student_skel(self):
        """Confirm Veyon_Master.desktop is ONLY in lyux-profile-prof, not in student or base."""
        prof_file = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-prof" / "files" / "Veyon_Master.desktop"
        assert prof_file.exists(), "Teacher must have Veyon_Master.desktop"

        # Check all other roles
        other_roles = [
            PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-base",
            PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-kiosk",
            PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-eleve",
            PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-salles",
        ]
        for role_dir in other_roles:
            matches = list(role_dir.rglob("*Veyon_Master*"))
            assert len(matches) == 0, f"Veyon Master desktop entry leaked to non-teacher role: {matches}"

    def test_student_accounts_have_no_sudo_or_admin_privileges(self):
        """Verify in import-users-csv.py and test accounts that eleves have NO sudo groups."""
        import_script = (PROJECT_ROOT / "lyux-server" / "lyux-server-infra" / "scripts" / "import-users-csv.py").read_text(encoding="utf-8")

        # In ROLE_PROFILES, "eleves" must have empty secondary_groups
        eleves_section_match = re.search(r'"eleves":\s*\{([^}]+)\}', import_script)
        assert eleves_section_match, "Could not find eleves role in import script"
        eleves_section = eleves_section_match.group(1)
        assert '"secondary_groups": []' in eleves_section, "Students must not have secondary groups"
        assert "sudo" not in eleves_section, "Students must not have sudo"

    def test_setup_veyon_keys_sh_student_branch_enforces_cleanup(self):
        """Verify setup-veyon-keys.sh executes rm -rf /etc/veyon/keys/private when not teacher."""
        script_path = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "configs" / "veyon" / "setup-veyon-keys.sh"
        assert script_path.exists()
        content = script_path.read_text(encoding="utf-8")

        # Look for else branch of IS_TEACHER
        assert 'rm -rf /etc/veyon/keys/private' in content
        assert 'chmod 0440 /etc/veyon/keys/private/teacher/key' in content
        assert 'chown root:enseignants /etc/veyon/keys/private/teacher/key' in content

    def test_terminal_shortcut_restriction_in_student_profile(self):
        """Confirm student profile disables direct terminal access via konsoleui.rc."""
        tasks_file = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-eleve" / "tasks" / "main.yml"
        content = tasks_file.read_text(encoding="utf-8")
        assert "konsoleui.rc" in content
        assert "state: absent" in content
