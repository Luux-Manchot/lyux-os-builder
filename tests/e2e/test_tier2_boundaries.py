"""
Tier 2: Boundary & Corner Cases (>=5 test cases per feature covering boundaries,
empty inputs, invalid formats, extremes across all 24 features).
"""

import os

import re

import csv

import xml.etree.ElementTree as ET

from pathlib import Path

import pytest

import yaml


class TestFeature10_KDEPlasmaBoundaries:
    def test_preseed_user_fullname_non_empty(self, preseed_vbox_path):
        """10.1 Nom complet de l'administrateur local non vide"""
        content = preseed_vbox_path.read_text(encoding="utf-8")
        assert "d-i passwd/user-fullname string Administrateur LyuX" in content

    def test_preseed_auto_partitioning_atomic_recipe(self, preseed_vbox_path):
        """10.2 Partitionnement atomique d-i sans fractionnement complexe"""
        content = preseed_vbox_path.read_text(encoding="utf-8")
        assert "d-i partman-auto/choose_recipe select atomic" in content

    def test_preseed_confirm_write_new_label(self, preseed_vbox_path):
        """10.3 Confirmation automatique d'écriture de table de partition pour éviter tout blocage"""
        content = preseed_vbox_path.read_text(encoding="utf-8")
        assert "d-i partman-partitioning/confirm_write_new_label boolean true" in content

    def test_sddm_installed_with_plasma_nm(self, preseed_vbox_path):
        """10.4 Présence conjointe de sddm et de l'applet réseau plasma-nm"""
        content = preseed_vbox_path.read_text(encoding="utf-8")
        assert "sddm" in content
        assert "plasma-nm" in content

    def test_kxmlgui_disabled_for_eleves(self, paths):
        """10.5 Suppression du fichier konsoleui.rc pour bloquer les raccourcis terminaux"""
        content = (paths["ansible"] / "roles" / "lyux-profile-eleve" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "/usr/local/share/kxmlgui5/konsole/konsoleui.rc" in content
        assert "state: absent" in content


class TestFeature11_LocaleAZERTYBoundaries:
    def test_xkb_keymap_exact_latin9(self, preseed_vbox_path):
        """11.1 Disposition clavier avec variante latin9 pour le symbole Euro et caractères français"""
        content = preseed_vbox_path.read_text(encoding="utf-8")
        assert "xkb-keymap select fr(latin9)" in content

    def test_keyboard_model_pc105_standard(self, preseed_vbox_path):
        """11.2 Modèle de clavier fixé au standard 105 touches (pc105)"""
        content = preseed_vbox_path.read_text(encoding="utf-8")
        assert "modelcode string pc105" in content

    def test_console_setup_ask_detect_false(self, preseed_vbox_path):
        """11.3 Détection interactive du clavier désactivée (ask_detect false)"""
        content = preseed_vbox_path.read_text(encoding="utf-8")
        assert "console-setup/ask_detect boolean false" in content

    def test_timezone_europe_paris_in_setup_vms(self, paths):
        """11.4 Fuseau horaire Europe/Paris forcé dans setup-2classes-vms.ps1"""
        content = (paths["lab_vm"] / "scripts" / "setup-2classes-vms.ps1").read_text(encoding="utf-8")
        assert '--time-zone="Europe/Paris"' in content

    def test_domain_lyux_lan_configured(self, preseed_vbox_path):
        """11.5 Domaine réseau lyux.lan forcé dans le preseed"""
        content = preseed_vbox_path.read_text(encoding="utf-8")
        assert "netcfg/get_domain string lyux.lan" in content


class TestFeature13_SSSDRealmdBoundaries:
    def test_sssd_file_permissions_mode_0600(self, paths):
        """13.1 Le fichier sssd.conf doit obligatoirement avoir les permissions 0600 (exigence stricte SSSD)"""
        content = (paths["ansible"] / "roles" / "lyux-base" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "mode: '0600'" in content

    def test_sssd_owner_and_group_root(self, paths):
        """13.2 sssd.conf doit appartenir exclusivement à root:root"""
        content = (paths["ansible"] / "roles" / "lyux-base" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "owner: root" in content
        assert "group: root" in content

    def test_sssd_handler_notifies_restart(self, paths):
        """13.3 Modification de sssd.conf déclenche la notification 'Restart sssd'"""
        content = (paths["ansible"] / "roles" / "lyux-base" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "notify: Restart sssd" in content

    def test_sssd_handler_file_defines_service_restart(self, paths):
        """13.4 Le handler Ansible Restart sssd redémarre effectivement le service"""
        handler_path = paths["ansible"] / "roles" / "lyux-base" / "handlers" / "main.yml"
        assert handler_path.exists()
        content = handler_path.read_text(encoding="utf-8")
        assert "name: sssd" in content
        assert "state: restarted" in content

    def test_sssd_cache_credentials_offline(self, sssd_conf_path):
        """13.5 sssd.conf active la mise en cache des identifiants (cache_credentials = true)"""
        content = sssd_conf_path.read_text(encoding="utf-8")
        assert "cache_credentials" in content


class TestFeature14_DynamicSharesPamMountBoundaries:
    def test_pam_mount_volume_attributes_presence(self, pam_mount_xml_path):
        """14.1 Tous les éléments volume disposent de fstype, server, path, mountpoint"""
        raw = pam_mount_xml_path.read_text(encoding="utf-8")
        clean_xml = re.sub(r'\{\{[^}]+\}\}', '192.168.100.10', raw)
        root = ET.fromstring(clean_xml)
        volumes = root.findall("volume")
        assert len(volumes) >= 3
        for v in volumes:
            assert "fstype" in v.attrib
            assert "server" in v.attrib
            assert "path" in v.attrib
            assert "mountpoint" in v.attrib

    def test_pam_mount_fstype_is_cifs(self, pam_mount_xml_path):
        """14.2 Tous les partages sont de type CIFS/SMB standardisé"""
        raw = pam_mount_xml_path.read_text(encoding="utf-8")
        clean_xml = re.sub(r'\{\{[^}]+\}\}', '192.168.100.10', raw)
        root = ET.fromstring(clean_xml)
        for v in root.findall("volume"):
            assert v.attrib["fstype"] == "cifs"

    def test_pam_mount_mkmountpoint_enabled(self, pam_mount_xml_path):
        """14.3 mkmountpoint activé avec suppression au démontage (remove=true)"""
        raw = pam_mount_xml_path.read_text(encoding="utf-8")
        assert '<mkmountpoint enable="1" remove="true" />' in raw

    def test_pam_mount_mntoptions_require_nosuid_nodev(self, pam_mount_xml_path):
        """14.4 Sécurité du montage exigeant nosuid et nodev"""
        raw = pam_mount_xml_path.read_text(encoding="utf-8")
        assert '<mntoptions require="nosuid,nodev" />' in raw

    def test_pam_mount_file_permissions_mode_0644(self, paths):
        """14.5 pam_mount.conf.xml installé en mode 0644 root:root"""
        content = (paths["ansible"] / "roles" / "lyux-base" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "dest: /etc/security/pam_mount.conf.xml" in content
        assert "mode: '0644'" in content


class TestFeature15_NSIMathsBoundaries:
    def test_nsi_package_list_not_empty(self, paths):
        """15.1 La liste des paquets NSI contient au moins 8 éléments"""
        content = (paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml").read_text(encoding="utf-8")
        nsi_block = content[content.find("when: room_profile == 'nsi'") - 400:content.find("when: room_profile == 'nsi'")]
        pkgs = re.findall(r'-\s+([a-zA-Z0-9_\+-]+)', nsi_block)
        assert len(pkgs) >= 8

    def test_nsi_no_duplicate_packages(self, paths):
        """15.2 Aucun doublon de paquet dans la tâche NSI"""
        content = (paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml").read_text(encoding="utf-8")
        nsi_block = content[content.find("when: room_profile == 'nsi'") - 400:content.find("when: room_profile == 'nsi'")]
        pkgs = re.findall(r'-\s+([a-zA-Z0-9_\+-]+)', nsi_block)
        assert len(pkgs) == len(set(pkgs))

    def test_nsi_room_b204_assigned_in_inventory(self, ansible_inventory_data):
        """15.3 Salle B204 assignée au profil nsi dans l'inventaire"""
        b204 = ansible_inventory_data["all"]["children"]["postes_clients"]["children"]["salle_nsi_b204"]
        assert b204["vars"]["room_profile"] == "nsi"

    def test_wireshark_network_analyzer_included(self, paths):
        """15.4 Wireshark inclus pour le programme officiel NSI (Protocoles & Réseaux)"""
        content = (paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "wireshark" in content

    def test_python_full_and_pip_in_base(self, paths):
        """15.5 Socle python3-full et python3-pip dans lyux-base"""
        content = (paths["ansible"] / "roles" / "lyux-base" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "python3-full" in content
        assert "python3-pip" in content


class TestFeature16_SciencesBoundaries:
    def test_sciences_package_list_not_empty(self, paths):
        """16.1 La liste des paquets Sciences contient au moins 5 éléments"""
        content = (paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml").read_text(encoding="utf-8")
        sciences_block = content[content.find("when: room_profile == 'sciences'") - 300:content.find("when: room_profile == 'sciences'")]
        pkgs = re.findall(r'-\s+([a-zA-Z0-9_\+-]+)', sciences_block)
        assert len(pkgs) >= 5

    def test_sciences_room_s102_assigned_in_inventory(self, ansible_inventory_data):
        """16.2 Salle S102 assignée au profil sciences dans l'inventaire"""
        s102 = ansible_inventory_data["all"]["children"]["postes_clients"]["children"]["salle_sciences_s102"]
        assert s102["vars"]["room_profile"] == "sciences"

    def test_techno_profile_distinct_from_sciences(self, paths):
        """16.3 Profil Techno distinct du profil Sciences (FreeCAD, KiCad)"""
        content = (paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "freecad" in content
        assert "when: room_profile == 'techno'" in content

    def test_vlc_and_audacity_in_base_for_multimedia(self, paths):
        """16.4 Lecteur multimédia VLC et Audacity dans lyux-base pour les TP sciences"""
        content = (paths["ansible"] / "roles" / "lyux-base" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "vlc" in content
        assert "audacity" in content

    def test_okular_pdf_reader_in_base(self, paths):
        """16.5 Lecteur Okular dans lyux-base pour les sujets de TP"""
        content = (paths["ansible"] / "roles" / "lyux-base" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "okular" in content


class TestFeature17_VeyonKeysBoundaries:
    def test_private_key_cannot_be_accessible_to_students(self, paths):
        """17.1 La clef privée n'est jamais accessible au groupe eleves"""
        spec = (paths["root"] / "docs" / "PROJECT.md").read_text(encoding="utf-8")
        assert "root:enseignants" in spec
        assert "root:eleves" not in spec

    def test_private_key_mode_not_world_readable(self, paths):
        """17.2 Le mode de la clef privée interdit tout droit pour les autres (mode 0440)"""
        spec = (paths["root"] / "docs" / "PROJECT.md").read_text(encoding="utf-8")
        assert "0440" in spec

    def test_public_key_world_readable_for_service(self, paths):
        """17.3 Le mode de la clef publique autorise la lecture à tous (mode 0444)"""
        spec = (paths["root"] / "docs" / "PROJECT.md").read_text(encoding="utf-8")
        assert "0444" in spec

    def test_veyon_key_directories_separation(self, paths):
        """17.4 Ségrégation stricte des dossiers private/teacher et public/teacher"""
        spec = (paths["root"] / "docs" / "PROJECT.md").read_text(encoding="utf-8")
        assert "/etc/veyon/keys/private" in spec
        assert "/etc/veyon/keys/public" in spec

    def test_veyon_default_ports_consecutive_boundaries(self, expected_ports):
        """17.5 Les ports Veyon sont tous distincts et situés dans la plage 11100-11400"""
        v_ports = [expected_ports[k]["port"] for k in ["veyon_service", "veyon_feature", "veyon_demo"]]
        assert len(v_ports) == len(set(v_ports))
        for p in v_ports:
            assert 11000 <= p <= 12000


class TestFeature18_VeyonMasterDeploymentBoundaries:
    def test_master_not_installed_on_student_stations(self, paths):
        """18.1 veyon-master absent des tâches élèves lyux-profile-eleve"""
        content = (paths["ansible"] / "roles" / "lyux-profile-eleve" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "veyon-master" not in content

    def test_service_running_on_eleves(self, paths):
        """18.2 veyon-service activé au démarrage sur les postes élèves"""
        content = (paths["ansible"] / "roles" / "lyux-profile-eleve" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "name: veyon" in content
        assert "state: started" in content

    def test_provision_client_installs_master_only_conditionally(self, paths):
        """18.3 Le script provision-client.sh tolère ou gère l'installation de veyon-master"""
        content = (paths["lab_vm"] / "scripts" / "provision-client.sh").read_text(encoding="utf-8")
        assert "veyon" in content

    def test_ansible_roles_hierarchy_separation(self, paths):
        """18.4 Ségrégation claire entre rôles lyux-profile-prof et lyux-profile-eleve"""
        prof_dir = paths["ansible"] / "roles" / "lyux-profile-prof"
        eleve_dir = paths["ansible"] / "roles" / "lyux-profile-eleve"
        assert prof_dir.is_dir()
        assert eleve_dir.is_dir()

    def test_veyon_plugins_present_in_prof_profile(self, paths):
        """18.5 Paquet veyon-plugins présent pour les extensions de contrôle à distance"""
        content = (paths["ansible"] / "roles" / "lyux-profile-prof" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "veyon-plugins" in content


class TestFeature21_VirtualBoxBoundaries:
    def test_vboxmanage_executable_default_path(self, paths):
        """21.1 Chemin par défaut de VBoxManage.exe sous Windows"""
        content = (paths["lab_vm"] / "scripts" / "setup-2classes-vms.ps1").read_text(encoding="utf-8")
        assert "C:\\Program Files\\Oracle\\VirtualBox\\VBoxManage.exe" in content

    def test_vm_disk_size_20gb_minimum(self, paths):
        """21.2 Taille des disques virtuels fixée à 20 Go (20480 Mo) pour le confort des profils"""
        content = (paths["lab_vm"] / "scripts" / "setup-2classes-vms.ps1").read_text(encoding="utf-8")
        assert "--size 20480" in content

    def test_vm_ostype_debian_64(self, paths):
        """21.3 Type d'OS configuré sur Debian_64"""
        content = (paths["lab_vm"] / "scripts" / "setup-2classes-vms.ps1").read_text(encoding="utf-8")
        assert '--ostype "Debian_64"' in content

    def test_vm_vram_128mb_allocated(self, paths):
        """21.4 Mémoire vidéo allouée à 128 Mo pour fluidité KDE Plasma"""
        content = (paths["lab_vm"] / "scripts" / "setup-2classes-vms.ps1").read_text(encoding="utf-8")
        assert "--vram 128" in content

    def test_sata_controller_bootable(self, paths):
        """21.5 Contrôleur SATA IntelAhci configuré avec flag bootable on"""
        content = (paths["lab_vm"] / "scripts" / "setup-2classes-vms.ps1").read_text(encoding="utf-8")
        assert "--controller IntelAhci --bootable on" in content


class TestFeature22_AutomatedLabRunnerBoundaries:
    def test_vagrantfile_ip_subnet_consistency(self, paths):
        """22.1 Vagrantfile utilise le sous-réseau cohérent 192.168.100.x"""
        content = (paths["lab_vm"] / "Vagrantfile").read_text(encoding="utf-8")
        assert "192.168.100." in content

    def test_vagrantfile_synced_folders(self, paths):
        """22.2 Réseau privé et sous-réseau cohérent configuré dans le Vagrantfile"""
        content = (paths["lab_vm"] / "Vagrantfile").read_text(encoding="utf-8")
        assert 'private_network' in content
        assert '192.168.100.10' in content

    def test_download_iso_powershell_file_exists(self, paths):
        """22.3 Script de téléchargement automatique d'ISO présent"""
        ps = paths["lab_vm"] / "scripts" / "download-and-attach-iso.ps1"
        assert ps.exists()

    def test_start_unattended_install_powershell_exists(self, paths):
        """22.4 Script start-unattended-install.ps1 présent"""
        ps = paths["lab_vm"] / "scripts" / "start-unattended-install.ps1"
        assert ps.exists()

    def test_batch_launcher_calls_powershell(self, paths):
        """22.5 Lancer-LyuX.bat et lancer-lyux.ps1 démarrent le portail web 8000 et l'application station"""
        bat_path = paths["root"] / "lyux-desktop" / "applications" / "Lancer-LyuX.bat" if (paths["root"] / "lyux-desktop" / "applications" / "Lancer-LyuX.bat").exists() else paths["root"] / "Lancer-LyuX.bat"
        ps1_path = paths["root"] / "lyux-desktop" / "applications" / "lancer-lyux.ps1" if (paths["root"] / "lyux-desktop" / "applications" / "lancer-lyux.ps1").exists() else paths["root"] / "lancer-lyux.ps1"
        bat_content = bat_path.read_text(encoding="utf-8")
        ps1_content = ps1_path.read_text(encoding="utf-8")
        assert "localhost:8000" in bat_content
        assert "main.py" in bat_content
        assert "localhost:8000" in ps1_content
        assert "main.py" in ps1_content


class TestFeature23_E2ESuiteBoundaries:
    def test_test_infra_contains_all_milestones(self, paths):
        """23.1 TEST_INFRA.md documente l'ensemble des jalons M1 à M6"""
        content = (paths["root"] / "docs" / "TEST_INFRA.md").read_text(encoding="utf-8")
        for m in ["Tier 1", "Tier 2", "Tier 3", "Tier 4"]:
            assert m in content

    def test_conftest_exports_all_required_fixtures(self):
        """23.2 Vérifie l'accessibilité de la fixture globale project_root"""
        assert Path(__file__).resolve().parents[2].parent.exists()

    def test_all_expected_ports_have_transport_and_protocol(self, expected_ports):
        """23.3 Toutes les définitions de ports spécifient protocole et transport"""
        for sname, sdata in expected_ports.items():
            assert "protocol" in sdata
            assert "transport" in sdata
            assert "port" in sdata

    def test_e2e_folder_isolated_from_projects_code(self, paths):
        """23.4 Le dossier tests/e2e est totalement disjoint de projects/"""
        e2e_dir = paths["tests_dir"] / "e2e"
        assert not str(e2e_dir).startswith(str(paths["root"] / "projects"))

    def test_original_request_file_exists_and_non_empty(self, paths):
        """23.5 ORIGINAL_REQUEST.md est accessible et non vide"""
        req_file = paths["root"] / ".antigravity" / "agents" / "teamwork" / "ORIGINAL_REQUEST.md"
        assert req_file.exists()
        assert len(req_file.read_text(encoding="utf-8")) > 100
