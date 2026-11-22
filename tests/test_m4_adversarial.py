"""
Milestone 4 Adversarial Stress Harness — Opération Manchot (LyuX)
Author: Challenger M4 (Empirical Challenger)

Adversarially tests and challenges:
1. Cryptographic RSA key pair validity, mathematical consistency, signature/verification,
   and resilience against bit tampering and forgery.
2. Key security boundaries: zero private key leakage in student role, absence of veyon-master
   in student profile, explicit removal task for /etc/veyon/keys/private.
3. Network port boundaries: strict allocation of 11100, 11200, 11400 across templates, UFW,
   and Python definitions.
4. VeyonManager API stress testing: hostile inputs (injection, traversal, unicode, null,
   extreme buffer sizes), dual-mode execution (offline fallback vs online), password complexity.
5. Network object directory schema integrity (JSON & CSV), uniqueness of MACs and IPv4s.
"""

import os

import sys

import json

import csv

import re

import ipaddress

import tempfile

from pathlib import Path

import pytest

from cryptography.hazmat.primitives.serialization import load_pem_private_key, load_pem_public_key

from cryptography.hazmat.primitives.asymmetric import rsa, padding

from cryptography.hazmat.primitives import hashes

from cryptography.exceptions import InvalidSignature

PROJECT_ROOT = Path(__file__).resolve().parents[2]

STATION_SRC = PROJECT_ROOT / "lyux-desktop" / "applications" / "station" / "src"

if str(STATION_SRC) not in sys.path:
    sys.path.insert(0, str(STATION_SRC))

from veyon_manager import VeyonManager, PILOT_ROOMS, VEYON_PORTS


class TestCryptographicRSAVeyonKeys:
    """Stress tests on RSA key pair used for Veyon teacher authentication."""

    @pytest.fixture
    def key_paths(self):
        priv_path = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "configs" / "veyon" / "keys" / "private" / "teacher" / "key"
        pub_path = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "configs" / "veyon" / "keys" / "public" / "teacher" / "key"
        return priv_path, pub_path

    def test_rsa_key_parameters_and_entropy(self, key_paths):
        """Verify RSA key parameters: 2048-bit, e=65537, valid PEM headers."""
        priv_path, pub_path = key_paths
        assert priv_path.exists(), "Private key file missing!"
        assert pub_path.exists(), "Public key file missing!"

        priv_bytes = priv_path.read_bytes()
        pub_bytes = pub_path.read_bytes()

        # Check standard PEM envelopes
        assert b"BEGIN RSA PRIVATE KEY" in priv_bytes or b"BEGIN PRIVATE KEY" in priv_bytes
        assert b"BEGIN PUBLIC KEY" in pub_bytes or b"BEGIN RSA PUBLIC KEY" in pub_bytes

        priv_key = load_pem_private_key(priv_bytes, password=None)
        pub_key = load_pem_public_key(pub_bytes)

        # Cryptographic assertions
        assert isinstance(priv_key, rsa.RSAPrivateKey)
        assert isinstance(pub_key, rsa.RSAPublicKey)
        assert priv_key.key_size == 2048
        assert pub_key.key_size == 2048

        # Standard secure public exponent
        assert priv_key.public_key().public_numbers().e == 65537
        assert pub_key.public_numbers().e == 65537

        # Modulus consistency between private and public
        assert priv_key.public_key().public_numbers().n == pub_key.public_numbers().n

    def test_rsa_signature_validity_and_anti_tampering(self, key_paths):
        """Sign varied challenge payloads and verify invalid signature detection on bit tampering."""
        priv_path, pub_path = key_paths
        priv_key = load_pem_private_key(priv_path.read_bytes(), password=None)
        pub_key = load_pem_public_key(pub_path.read_bytes())

        test_payloads = [
            b"",  # Empty payload
            b"A",  # Single byte
            b"Veyon-Master-Session-Auth-Token: 2026-10-09",
            "Élève: Hugo Dubois \U0001F468\u200D\U0001F393 Salle S102".encode("utf-8"),
            b"\x00\xff\x00\xaa" * 256,  # Binary payload (1KB)
            b"A" * 1024 * 64,  # 64KB payload
        ]

        for payload in test_payloads:
            signature = priv_key.sign(payload, padding.PKCS1v15(), hashes.SHA256())
            assert len(signature) == 256, "RSA-2048 signature must be 256 bytes"

            # Valid verification
            pub_key.verify(signature, payload, padding.PKCS1v15(), hashes.SHA256())

            # Bit tampering in payload
            if payload:
                tampered_payload = bytearray(payload)
                tampered_payload[0] ^= 0x01
                with pytest.raises(InvalidSignature):
                    pub_key.verify(signature, bytes(tampered_payload), padding.PKCS1v15(), hashes.SHA256())

            # Bit tampering in signature
            tampered_sig = bytearray(signature)
            tampered_sig[10] ^= 0x80
            with pytest.raises(InvalidSignature):
                pub_key.verify(bytes(tampered_sig), payload, padding.PKCS1v15(), hashes.SHA256())

            # Truncated signature
            with pytest.raises(Exception):
                pub_key.verify(signature[:128], payload, padding.PKCS1v15(), hashes.SHA256())

    def test_key_copies_byte_identical(self, key_paths):
        """Verify that deployed copies in roles match the canonical keys byte-for-byte."""
        canonical_priv, canonical_pub = key_paths

        prof_priv = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-prof" / "files" / "keys" / "private" / "teacher" / "key"
        prof_pub = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-prof" / "files" / "keys" / "public" / "teacher" / "key"
        eleve_pub = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-eleve" / "files" / "keys" / "public" / "teacher" / "key"

        assert prof_priv.read_bytes() == canonical_priv.read_bytes()
        assert prof_pub.read_bytes() == canonical_pub.read_bytes()
        assert eleve_pub.read_bytes() == canonical_pub.read_bytes()

    def test_rsa_encryption_decryption_oaep_roundtrip(self, key_paths):
        """Verify mathematical inverse correspondence between public and private keys via OAEP encryption."""
        priv_path, pub_path = key_paths
        priv_key = load_pem_private_key(priv_path.read_bytes(), password=None)
        pub_key = load_pem_public_key(pub_path.read_bytes())

        secret_message = b"Veyon-Master-Session-Auth-2026-StrictlyConfidentialTeacherSecret"
        ciphertext = pub_key.encrypt(
            secret_message,
            padding.OAEP(
                mgf=padding.MGF1(algorithm=hashes.SHA256()),
                algorithm=hashes.SHA256(),
                label=None
            )
        )
        assert len(ciphertext) == 256

        decrypted = priv_key.decrypt(
            ciphertext,
            padding.OAEP(
                mgf=padding.MGF1(algorithm=hashes.SHA256()),
                algorithm=hashes.SHA256(),
                label=None
            )
        )
        assert decrypted == secret_message

    def test_corrupted_key_error_handling(self):
        """Verify that corrupted or invalid key files raise appropriate cryptography errors."""
        corrupted_payloads = [
            b"-----BEGIN RSA PRIVATE KEY-----\nGARBAGE\n-----END RSA PRIVATE KEY-----",
            b"NOT_A_PEM_AT_ALL",
            b"",
            b"-----BEGIN PUBLIC KEY-----\nAAAA\n-----END PUBLIC KEY-----",
        ]
        for payload in corrupted_payloads:
            with pytest.raises((ValueError, TypeError)):
                load_pem_private_key(payload, password=None)
            with pytest.raises((ValueError, TypeError)):
                load_pem_public_key(payload)


class TestKeySecurityBoundaries:
    """Stress tests on student role segregation and private key isolation."""

    def test_strict_zero_private_key_leakage_in_student_role(self):
        """Recursively scan every file in lyux-profile-eleve to ensure zero private key leak."""
        eleve_dir = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-eleve"
        for root, dirs, files in os.walk(eleve_dir):
            assert "private" not in dirs, f"Private directory found in student role: {root}"
            for file_name in files:
                file_path = Path(root) / file_name
                content = file_path.read_bytes()
                assert b"PRIVATE KEY" not in content, f"Private key header leaked in {file_path}"
                assert b"BEGIN RSA PRIVATE" not in content, f"RSA private key leaked in {file_path}"

    def test_student_tasks_explicitly_remove_private_directory(self):
        """Verify student tasks enforce state: absent on /etc/veyon/keys/private."""
        eleve_tasks = (PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-eleve" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "/etc/veyon/keys/private" in eleve_tasks
        assert "state: absent" in eleve_tasks

    def test_student_tasks_prohibit_veyon_master(self):
        """Ensure the string 'veyon-master' is nowhere in student tasks or templates."""
        eleve_dir = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-eleve"
        for p in eleve_dir.rglob("*.yml"):
            assert "veyon-master" not in p.read_text(encoding="utf-8").lower()
        for p in eleve_dir.rglob("*.j2"):
            assert "veyon-master" not in p.read_text(encoding="utf-8").lower()

    def test_teacher_role_secures_private_key_permissions(self):
        """Verify teacher tasks apply mode 0440 and group enseignants to the private key."""
        prof_tasks = (PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-prof" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "mode: '0440'" in prof_tasks or 'mode: "0440"' in prof_tasks
        assert "group: enseignants" in prof_tasks
        assert "mode: '0750'" in prof_tasks or 'mode: "0750"' in prof_tasks

    def test_setup_veyon_keys_sh_isolation_logic(self):
        """Examine setup-veyon-keys.sh to verify rm -rf /etc/veyon/keys/private on student."""
        script = (PROJECT_ROOT / "os-builder" / "lyux-ansible" / "configs" / "veyon" / "setup-veyon-keys.sh").read_text(encoding="utf-8")
        assert "rm -rf /etc/veyon/keys/private" in script
        assert "chmod 0440" in script
        assert "chmod 0444" in script
        assert "root:enseignants" in script


class TestPortBoundariesAndFirewall:
    """Validate ports 11100, 11200, 11400 allocations and firewall rules."""

    def test_veyon_conf_ports(self):
        """Check ports in Veyon.conf.j2."""
        conf = (PROJECT_ROOT / "os-builder" / "lyux-ansible" / "configs" / "veyon" / "Veyon.conf.j2").read_text(encoding="utf-8")
        assert "PrimaryServicePort=11100" in conf
        assert "ServicePort=11100" in conf
        assert "FeatureWorkerPort=11200" in conf
        assert "DemoServerPort=11400" in conf

    def test_ufw_rules_in_ansible_roles(self):
        """Verify teacher opens 11400/11100, student opens 11100/11200, neither opens illegal ports."""
        prof_tasks = (PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-prof" / "tasks" / "main.yml").read_text(encoding="utf-8")
        eleve_tasks = (PROJECT_ROOT / "os-builder" / "lyux-ansible" / "roles" / "lyux-profile-eleve" / "tasks" / "main.yml").read_text(encoding="utf-8")

        # Teacher needs 11400 (Demo Server to stream teacher screen) and 11100 (Service Probe)
        assert "11400" in prof_tasks
        assert "11100" in prof_tasks

        # Student needs 11100 (Service Client) and 11200 (Feature Client for lock/msg)
        assert "11100" in eleve_tasks
        assert "11200" in eleve_tasks

        # Student must NOT open Demo Server port 11400 (only teacher broadcasts demo)
        assert "11400" not in eleve_tasks

    def test_veyon_manager_ports_constants(self):
        """Verify VeyonManager port dictionary."""
        assert VEYON_PORTS["service"] == 11100
        assert VEYON_PORTS["feature"] == 11200
        assert VEYON_PORTS["demo"] == 11400


class TestVeyonManagerAdversarial:
    """Stress testing VeyonManager with adversarial inputs and edge cases."""

    @pytest.fixture
    def manager(self):
        return VeyonManager(api_url="http://127.0.0.1:9999")  # Target offline port to test local resilience

    def test_room_definition_adversarial_queries(self, manager):
        """Test get_room_definition against edge cases, injection attempts, and malformed strings."""
        hostile_inputs = [
            "",
            "   ",
            None,
            "../../etc/shadow",
            "B204; rm -rf /",
            "' OR '1'='1",
            "<script>alert(1)</script>",
            "\x00\x00\x00",
            "C305",
            "B204_OVERFLOW" * 100
        ]
        for hostile in hostile_inputs:
            assert manager.get_room_definition(hostile) is None

        # Case and whitespace tolerance
        assert manager.get_room_definition("b204") is not None
        assert manager.get_room_definition("  s102  ") is not None
        assert manager.get_room_definition("B204")["capacity"] == 24
        assert manager.get_room_definition("S102")["capacity"] == 24

    def test_room_computers_structure_and_roles(self, manager):
        """Verify computer listing returns exactly one teacher and correct student entries."""
        for room_id in ["B204", "S102"]:
            comps = manager.get_room_computers(room_id)
            assert len(comps) == 3

            teacher = [c for c in comps if c["is_teacher"]]
            students = [c for c in comps if not c["is_teacher"]]

            assert len(teacher) == 1
            assert len(students) == 2

            assert teacher[0]["role"] == "teacher"
            assert "prof" in teacher[0]["hostname"]

            for st in students:
                assert st["role"] == "student"
                assert "pc" in st["hostname"]
                assert st["ip"].startswith("192.168.100.")

    def test_execute_room_action_hostile_messages(self, manager):
        """Test lock/unlock/message with extreme payloads in offline mode."""
        # Oversized message
        big_msg = "A" * (64 * 1024)
        res_big = manager.lock_room("B204", message=big_msg)
        assert res_big["success"] is True
        assert res_big["affected_machines"] == 2
        assert res_big["message"] == big_msg

        # Unicode special characters & French diacritics
        unicode_msg = "Écoutez les consignes : é, è, ê, à, ç, œ, ⚡, 🐧, « Guillemets »"
        res_uni = manager.send_message("S102", unicode_msg)
        assert res_uni["success"] is True
        assert res_uni["message"] == unicode_msg

        # Unknown room
        res_bad = manager.lock_room("SALLE_INEXISTANTE")
        assert res_bad["success"] is False
        assert "inconnue" in res_bad["error"].lower()

    def test_reset_password_complexity(self, manager):
        """Verify reset_student_password offline fallback produces valid complex passwords."""
        for user in ["lucas.martin", "emma.bernard", "hugo.dubois", "lea.thomas"]:
            res = manager.reset_student_password(user)
            assert res["success"] is True
            pwd = res["new_password"]
            assert pwd.startswith("Pass")
            assert pwd.endswith("!")
            assert len(pwd) >= 8
            assert any(c.isupper() for c in pwd)
            assert any(c.islower() for c in pwd)
            assert any(c.isdigit() for c in pwd)

    def test_verify_asymmetric_keys_synthetic_scenarios(self, manager):
        """Verify key checker catches security violations and missing files."""
        with tempfile.TemporaryDirectory() as td:
            base_dir = Path(td)
            priv_key = base_dir / "private" / "teacher" / "key"
            pub_key = base_dir / "public" / "teacher" / "key"

            priv_key.parent.mkdir(parents=True)
            pub_key.parent.mkdir(parents=True)

            # Scenario 1: Both keys missing
            res = manager.verify_asymmetric_keys(is_teacher=True, keys_dir=td)
            assert res["valid"] is False
            assert len(res["errors"]) == 2

            # Scenario 2: Teacher valid
            priv_key.write_text("dummy-private")
            pub_key.write_text("dummy-public")
            res_t = manager.verify_asymmetric_keys(is_teacher=True, keys_dir=td)
            assert res_t["valid"] is True

            # Scenario 3: Student with private key present -> SECURITY VIOLATION
            res_s_violation = manager.verify_asymmetric_keys(is_teacher=False, keys_dir=td)
            assert res_s_violation["valid"] is False
            assert any("Violation de sécurité" in e for e in res_s_violation["errors"])

            # Scenario 4: Student valid (private key removed)
            priv_key.unlink()
            res_s_ok = manager.verify_asymmetric_keys(is_teacher=False, keys_dir=td)
            assert res_s_ok["valid"] is True

    def test_export_network_objects_config(self, manager):
        """Verify JSON export creates a valid BuiltinDirectory structure matching rooms."""
        with tempfile.TemporaryDirectory() as td:
            out_file = Path(td) / "test-objects.json"
            cfg = manager.export_network_objects_config(output_path=str(out_file))

            assert out_file.exists()
            loaded = json.loads(out_file.read_text(encoding="utf-8"))
            assert loaded == cfg

            locs = cfg["NetworkObjects"]["Locations"]
            comps = cfg["NetworkObjects"]["Computers"]

            assert len(locs) == 2
            assert len(comps) == 6
            assert any(c["name"] == "b204-prof" and c["role"] == "teacher" for c in comps)
            assert any(c["name"] == "s102-pc01" and c["role"] == "student" for c in comps)

    def test_check_port_open_invalid_hosts_and_ports(self, manager):
        """Verify check_port_open handles invalid IPs, unreachable domains, and out-of-range ports without crashing."""
        assert manager.check_port_open("999.999.999.999", 11100, timeout=0.1) is False
        assert manager.check_port_open("nonexistent.invalid.domain.local", 11100, timeout=0.1) is False
        assert manager.check_port_open("", 11100, timeout=0.1) is False
        assert manager.check_port_open("127.0.0.1", -1, timeout=0.1) is False
        assert manager.check_port_open("127.0.0.1", 99999, timeout=0.1) is False

    def test_execute_room_action_invalid_and_edge_actions(self, manager):
        """Verify execute_room_action safely handles unknown/malformed actions."""
        invalid_actions = ["format_disk", "drop table", "../../traversal", "<script>", ""]
        for act in invalid_actions:
            res = manager.execute_room_action("B204", act)
            assert res["success"] is True
            assert res["action"] == act
            assert res["affected_machines"] == 2

        # Non-existent room should return failure regardless of action
        res_bad_room = manager.execute_room_action("NONEXISTENT_ROOM", "lock")
        assert res_bad_room["success"] is False
        assert res_bad_room["affected_machines"] == 0

    def test_reset_student_password_unusual_usernames(self, manager):
        """Verify reset_student_password handles unusual, malicious, or malformed usernames safely."""
        unusual_usernames = [
            "' OR '1'='1",
            "lucas; rm -rf /",
            "élève.françois 👨‍🎓",
            "user!@#$%^&*()_+",
            "a" * 5000,
            "  lucas.martin  ",
            "\x00nullbyte",
            ""
        ]
        for u in unusual_usernames:
            res = manager.reset_student_password(u)
            assert res["success"] is True
            assert "new_password" in res
            pwd = res["new_password"]
            assert pwd.startswith("Pass")
            assert pwd.endswith("!")

    def test_empty_or_tampered_room_definitions(self):
        """Verify VeyonManager behavior when room catalog is empty or missing data."""
        custom_vm = VeyonManager()
        custom_vm.rooms = {}
        assert custom_vm.list_rooms() == []
        assert custom_vm.get_room_definition("B204") is None
        assert custom_vm.get_room_computers("B204") == []
        res = custom_vm.lock_room("B204")
        assert res["success"] is False
        assert res["affected_machines"] == 0

        # Room with empty students
        custom_vm.rooms = {
            "EMPTY": {
                "name": "Salle Vide",
                "teacher_host": "vide-prof",
                "teacher_ip": "192.168.100.99",
                "students": []
            }
        }
        comps = custom_vm.get_room_computers("EMPTY")
        assert len(comps) == 1
        assert comps[0]["role"] == "teacher"
        res = custom_vm.lock_room("EMPTY")
        assert res["success"] is True
        assert res["affected_machines"] == 0


class TestPilotRoomsAndInventoryIntegrity:
    """Stress tests on network objects definitions across JSON, CSV, and configs."""

    def test_network_objects_json_and_csv_consistency(self):
        """Cross-check network-objects.json and network-objects.csv for parity."""
        json_path = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "configs" / "veyon" / "network-objects.json"
        csv_path = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "configs" / "veyon" / "network-objects.csv"

        assert json_path.exists()
        assert csv_path.exists()

        data_json = json.loads(json_path.read_text(encoding="utf-8"))
        comps_json = data_json["NetworkObjects"]["Computers"]

        # Read CSV
        with open(csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f, delimiter=";")
            rows = list(reader)

        computer_rows = [r for r in rows if r.get("type", "").strip('"') == "computer"]
        location_rows = [r for r in rows if r.get("type", "").strip('"') == "location"]

        assert len(comps_json) == 6
        assert len(computer_rows) == 6
        assert len(location_rows) == 2

        # Cross-verify each computer
        mac_regex = re.compile(r"^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$")
        all_ips = set()
        all_macs = set()
        all_names = set()

        for c in comps_json:
            name = c["name"]
            ip = c["host"]
            mac = c["mac"]

            # Format assertions
            ip_obj = ipaddress.ip_address(ip)
            assert ip_obj.version == 4
            assert mac_regex.match(mac), f"Invalid MAC format: {mac}"

            # Uniqueness
            assert name not in all_names, f"Duplicate hostname: {name}"
            assert ip not in all_ips, f"Duplicate IP: {ip}"
            assert mac not in all_macs, f"Duplicate MAC: {mac}"

            all_names.add(name)
            all_ips.add(ip)
            all_macs.add(mac)

            # Match in CSV
            csv_match = [r for r in computer_rows if r["name"] == name]
            assert len(csv_match) == 1, f"Computer {name} missing or duplicated in CSV"
            assert csv_match[0]["host"] == ip
            assert csv_match[0]["mac"].lower() == mac.lower()
            assert csv_match[0]["location"] == c["location"]

    def test_pilot_rooms_subnets_isolation(self):
        """Verify B204 is on .2x IPs and S102 is on .3x IPs."""
        json_path = PROJECT_ROOT / "os-builder" / "lyux-ansible" / "configs" / "veyon" / "network-objects.json"
        data = json.loads(json_path.read_text(encoding="utf-8"))

        for c in data["NetworkObjects"]["Computers"]:
            if "b204" in c["name"]:
                assert c["location"] == "Salle B204"
                assert c["host"].startswith("192.168.100.2")
            elif "s102" in c["name"]:
                assert c["location"] == "Salle S102"
                assert c["host"].startswith("192.168.100.3")
            else:
                pytest.fail(f"Unexpected computer name: {c['name']}")
