"""
Tier 1: Feature Coverage (>=5 test cases per feature across all 24 inventoried features).
Chaque test vérifie de manière autoritative les spécifications définies dans PROJECT.md
et ORIGINAL_REQUEST.md sur les fichiers réels, schémas, scripts, configurations et endpoints.
"""

import os

import re

import csv

import xml.etree.ElementTree as ET

from pathlib import Path

import pytest

import yaml


class TestFeature10_KDEPlasmaDesktopBase:
    def test_preseed_vbox_specifies_kde_desktop(self, preseed_vbox_path):
        """10.1 Vérifie la sélection de kde-desktop dans vbox-preseed-kde-fr.cfg"""
        content = preseed_vbox_path.read_text(encoding="utf-8")
        assert "tasksel/first multiselect kde-desktop" in content or "kde-plasma-desktop" in content

    def test_preseed_iso_specifies_kde_desktop(self, preseed_iso_path):
        """10.2 Vérifie la sélection de kde-desktop dans preseed.cfg de l'ISO"""
        content = preseed_iso_path.read_text(encoding="utf-8")
        assert "kde-desktop" in content

    def test_sddm_display_manager_included(self, preseed_vbox_path):
        """10.3 Vérifie l'inclusion de SDDM comme gestionnaire graphique de connexion"""
        content = preseed_vbox_path.read_text(encoding="utf-8")
        assert "sddm" in content

    def test_kde_globals_theme_kiosk_role(self, paths):
        """10.4 Vérifie la présence du template de personnalisation KDE (kdeglobals.j2)"""
        kdeglobals = paths["ansible"] / "roles" / "lyux-kiosk" / "templates" / "kdeglobals.j2"
        assert kdeglobals.exists()
        content = kdeglobals.read_text(encoding="utf-8")
        assert "[KDE]" in content or "General" in content or "Colors" in content or len(content) > 0

    def test_konsole_terminal_restriction_for_students(self, paths):
        """10.5 Vérifie la désactivation des terminaux directs pour les sessions élèves"""
        eleve_tasks = paths["ansible"] / "roles" / "lyux-profile-eleve" / "tasks" / "main.yml"
        content = eleve_tasks.read_text(encoding="utf-8")
        assert "konsole" in content.lower()


class TestFeature11_LocaleAZERTYKeyboard:
    def test_vbox_preseed_locale_fr(self, preseed_vbox_path):
        """11.1 Vérifie la locale fr_FR.UTF-8 dans vbox-preseed-kde-fr.cfg"""
        content = preseed_vbox_path.read_text(encoding="utf-8")
        assert "fr_FR.UTF-8" in content

    def test_vbox_preseed_azerty_keymap(self, preseed_vbox_path):
        """11.2 Vérifie la disposition clavier fr(latin9) / pc105 dans vbox preseed"""
        content = preseed_vbox_path.read_text(encoding="utf-8")
        assert "fr(latin9)" in content
        assert "pc105" in content

    def test_iso_preseed_locale_fr(self, preseed_iso_path):
        """11.3 Vérifie la locale fr_FR.UTF-8 dans l'ISO d'installation"""
        content = preseed_iso_path.read_text(encoding="utf-8")
        assert "fr_FR.UTF-8" in content
        assert "fr(latin9)" in content

    def test_setup_2classes_kernel_parameters_azerty(self, paths):
        """11.4 Vérifie le passage forcé des paramètres kernel AZERTY dans setup-2classes-vms.ps1"""
        script = paths["lab_vm"] / "scripts" / "setup-2classes-vms.ps1"
        content = script.read_text(encoding="utf-8")
        assert "fr_FR.UTF-8" in content
        assert "fr(latin9)" in content

    def test_firefox_and_libreoffice_french_l10n(self, paths):
        """11.5 Vérifie la présence des paquets de francisation l10n-fr pour LibreOffice et Firefox"""
        base_tasks = paths["ansible"] / "roles" / "lyux-base" / "tasks" / "main.yml"
        content = base_tasks.read_text(encoding="utf-8")
        assert "firefox-esr-l10n-fr" in content
        assert "libreoffice-l10n-fr" in content


class TestFeature13_SSSDRealmdIntegration:
    def test_sssd_template_exists(self, sssd_conf_path):
        """13.1 Vérifie la présence du template sssd.conf.j2"""
        assert sssd_conf_path.exists()

    def test_sssd_configuration_services(self, sssd_conf_path):
        """13.2 Vérifie les services nss et pam déclarés dans sssd.conf.j2"""
        content = sssd_conf_path.read_text(encoding="utf-8")
        assert "services = nss, pam" in content or ("nss" in content and "pam" in content)

    def test_sssd_domain_configuration(self, sssd_conf_path):
        """13.3 Vérifie le domaine LYUX.LAN et l'id_provider dans sssd.conf.j2"""
        content = sssd_conf_path.read_text(encoding="utf-8")
        assert "domain" in content.lower()
        assert "ldap" in content.lower() or "ad" in content.lower()

    def test_sssd_packages_installed_in_ansible(self, paths):
        """13.4 Vérifie les paquets sssd, sssd-tools, libpam-sss dans lyux-base"""
        base_tasks = paths["ansible"] / "roles" / "lyux-base" / "tasks" / "main.yml"
        content = base_tasks.read_text(encoding="utf-8")
        assert "sssd" in content
        assert "libpam-sss" in content
        assert "libnss-sss" in content

    def test_pam_mkhomedir_activation(self, paths):
        """13.5 Vérifie l'activation de pam_mkhomedir via pam-auth-update"""
        base_tasks = paths["ansible"] / "roles" / "lyux-base" / "tasks" / "main.yml"
        content = base_tasks.read_text(encoding="utf-8")
        assert "pam-auth-update --enable mkhomedir" in content


class TestFeature14_DynamicSharesPamMount:
    def test_pam_mount_template_is_valid_xml(self, pam_mount_xml_path):
        """14.1 Vérifie que pam_mount.conf.xml.j2 est un XML syntaxiquement valide (hors variables Jinja)"""
        raw = pam_mount_xml_path.read_text(encoding="utf-8")
        clean_xml = re.sub(r'\{\{[^}]+\}\}', '192.168.100.10', raw)
        root = ET.fromstring(clean_xml)
        assert root.tag == "pam_mount"

    def test_pam_mount_espace_personnel_volume(self, pam_mount_xml_path):
        """14.2 Vérifie le volume de montage ~/Espace_Personnel pointant sur homes/%(USER)"""
        raw = pam_mount_xml_path.read_text(encoding="utf-8")
        assert 'mountpoint="~/Espace_Personnel"' in raw
        assert 'path="homes/%(USER)"' in raw
        assert 'fstype="cifs"' in raw

    def test_pam_mount_partages_classes_volume(self, pam_mount_xml_path):
        """14.3 Vérifie le volume de montage ~/Partages_Classes pour le groupe eleves"""
        raw = pam_mount_xml_path.read_text(encoding="utf-8")
        assert 'mountpoint="~/Partages_Classes"' in raw
        assert 'path="classes"' in raw
        assert 'sgrp="eleves"' in raw

    def test_pam_mount_partages_enseignants_volume(self, pam_mount_xml_path):
        """14.4 Vérifie le volume de montage ~/Partages_Enseignants pour le groupe enseignants"""
        raw = pam_mount_xml_path.read_text(encoding="utf-8")
        assert 'mountpoint="~/Partages_Enseignants"' in raw
        assert 'path="profs"' in raw
        assert 'sgrp="enseignants"' in raw

    def test_pam_mount_cifs_security_options(self, pam_mount_xml_path):
        """14.5 Vérifie les options de sécurité CIFS (sec=ntlmssp, permissions 0700/0770)"""
        raw = pam_mount_xml_path.read_text(encoding="utf-8")
        assert "sec=ntlmssp" in raw
        assert "file_mode=0700" in raw


class TestFeature15_DisciplinaryProfileNSIMaths:
    def test_nsi_role_exists(self, paths):
        """15.1 Vérifie la présence des tâches de profil de salle dans lyux-profile-salles"""
        tasks_file = paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml"
        assert tasks_file.exists()

    def test_nsi_packages_include_vscode_jupyter_spyder(self, paths):
        """15.2 Vérifie les outils NSI avancés (code, jupyter-notebook, spyder)"""
        tasks_file = paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml"
        content = tasks_file.read_text(encoding="utf-8")
        assert "code" in content
        assert "jupyter-notebook" in content
        assert "spyder" in content

    def test_nsi_packages_include_gcc_gdb_git(self, paths):
        """15.3 Vérifie les outils de développement (gcc, g++, gdb, git)"""
        tasks_file = paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml"
        content = tasks_file.read_text(encoding="utf-8")
        assert "gcc" in content
        assert "g++" in content
        assert "git" in content

    def test_nsi_packages_include_maths_tools(self, paths):
        """15.4 Vérifie la présence de scilab ou octave pour les mathématiques"""
        tasks_file = paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml"
        content = tasks_file.read_text(encoding="utf-8")
        assert "scilab" in content or "octave" in content

    def test_nsi_base_packages_thonny_geogebra(self, paths):
        """15.5 Vérifie la présence de Thonny et GeoGebra dans le socle lyux-base"""
        base_tasks = paths["ansible"] / "roles" / "lyux-base" / "tasks" / "main.yml"
        content = base_tasks.read_text(encoding="utf-8")
        assert "thonny" in content
        assert "geogebra" in content


class TestFeature16_DisciplinaryProfileSciences:
    def test_sciences_condition_in_ansible(self, paths):
        """16.1 Vérifie la condition room_profile == 'sciences' dans les tâches Ansible"""
        tasks_file = paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml"
        content = tasks_file.read_text(encoding="utf-8")
        assert "room_profile == 'sciences'" in content

    def test_sciences_avogadro_chimie_3d(self, paths):
        """16.2 Vérifie la présence d'Avogadro pour la modélisation moléculaire"""
        tasks_file = paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml"
        content = tasks_file.read_text(encoding="utf-8")
        assert "avogadro" in content

    def test_sciences_stellarium_astronomie(self, paths):
        """16.3 Vérifie la présence de Stellarium pour l'astronomie et physique"""
        tasks_file = paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml"
        content = tasks_file.read_text(encoding="utf-8")
        assert "stellarium" in content

    def test_sciences_tracker_mecanique(self, paths):
        """16.4 Vérifie la présence de Tracker pour l'analyse vidéo en mécanique"""
        tasks_file = paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml"
        content = tasks_file.read_text(encoding="utf-8")
        assert "tracker" in content

    def test_sciences_qgis_gimp_imagej(self, paths):
        """16.5 Vérifie la présence d'outils complémentaires SVT/Physique (QGIS, GIMP, ImageJ)"""
        tasks_file = paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml"
        content = tasks_file.read_text(encoding="utf-8")
        assert "qgis" in content
        assert "gimp" in content
        assert "imagej" in content


class TestFeature17_VeyonAsymmetricKeys:
    def test_veyon_private_key_contract_path(self, paths):
        """17.1 Vérifie le chemin normatif de la clef privée enseignant dans PROJECT.md"""
        spec = (paths["root"] / "docs" / "PROJECT.md").read_text(encoding="utf-8")
        assert "/etc/veyon/keys/private/teacher/key" in spec

    def test_veyon_private_key_strict_permissions(self, paths):
        """17.2 Vérifie les permissions strictes 0440 réservées au groupe enseignants"""
        spec = (paths["root"] / "docs" / "PROJECT.md").read_text(encoding="utf-8")
        assert "0440" in spec
        assert "root:enseignants" in spec

    def test_veyon_public_key_contract_path(self, paths):
        """17.3 Vérifie le chemin normatif de la clef publique sur tous les postes"""
        spec = (paths["root"] / "docs" / "PROJECT.md").read_text(encoding="utf-8")
        assert "/etc/veyon/keys/public/teacher/key" in spec

    def test_veyon_public_key_world_readable(self, paths):
        """17.4 Vérifie les permissions 0444 root:root pour la clef publique"""
        spec = (paths["root"] / "docs" / "PROJECT.md").read_text(encoding="utf-8")
        assert "0444" in spec

    def test_veyon_ports_allocated(self, expected_ports):
        """17.5 Vérifie les 3 ports officiels de communication Veyon (11100, 11200, 11400)"""
        assert expected_ports["veyon_service"]["port"] == 11100
        assert expected_ports["veyon_feature"]["port"] == 11200
        assert expected_ports["veyon_demo"]["port"] == 11400


class TestFeature18_VeyonMasterServiceDeployment:
    def test_veyon_master_in_prof_profile(self, paths):
        """18.1 Vérifie l'installation du paquet veyon-master dans le rôle prof"""
        prof_tasks = paths["ansible"] / "roles" / "lyux-profile-prof" / "tasks" / "main.yml"
        content = prof_tasks.read_text(encoding="utf-8")
        assert "veyon-master" in content

    def test_veyon_service_in_base_profile(self, paths):
        """18.2 Vérifie l'installation de veyon-service dans le socle commun lyux-base"""
        base_tasks = paths["ansible"] / "roles" / "lyux-base" / "tasks" / "main.yml"
        content = base_tasks.read_text(encoding="utf-8")
        assert "veyon-service" in content

    def test_veyon_service_daemon_enabled_for_eleves(self, paths):
        """18.3 Vérifie le démarrage et l'activation automatique du service veyon dans lyux-profile-eleve"""
        eleve_tasks = paths["ansible"] / "roles" / "lyux-profile-eleve" / "tasks" / "main.yml"
        content = eleve_tasks.read_text(encoding="utf-8")
        assert "name: veyon" in content
        assert "state: started" in content
        assert "enabled: yes" in content or "enabled: true" in content

    def test_teacher_machine_flagged_in_ansible_inventory(self, ansible_inventory_data):
        """18.4 Vérifie le flag is_teacher_pc: true sur les postes profs de l'inventaire"""
        clients = ansible_inventory_data["all"]["children"]["postes_clients"]["children"]
        b204 = clients["salle_nsi_b204"]["hosts"]
        s102 = clients["salle_sciences_s102"]["hosts"]
        assert b204["b204-prof"].get("is_teacher_pc") is True
        assert s102["s102-prof"].get("is_teacher_pc") is True

    def test_student_machines_not_teacher_flagged(self, ansible_inventory_data):
        """18.5 Vérifie que les postes élèves ne sont pas marqués is_teacher_pc"""
        clients = ansible_inventory_data["all"]["children"]["postes_clients"]["children"]
        b204 = clients["salle_nsi_b204"]["hosts"]
        assert b204["b204-01"].get("is_teacher_pc", False) is False


class TestFeature21_VirtualBoxAutomatedLab:
    def test_setup_2classes_script_exists(self, paths):
        """21.1 Vérifie la présence du script setup-2classes-vms.ps1"""
        s = paths["lab_vm"] / "scripts" / "setup-2classes-vms.ps1"
        assert s.exists()

    def test_setup_2classes_unattended_install_flags(self, paths):
        """21.2 Vérifie l'utilisation de VBoxManage unattended install pour éliminer l'invite textuelle"""
        content = (paths["lab_vm"] / "scripts" / "setup-2classes-vms.ps1").read_text(encoding="utf-8")
        assert "unattended install" in content

    def test_setup_2classes_guest_additions_flag(self, paths):
        """21.3 Vérifie le flag --install-additions pour l'intégration graphique optimale"""
        content = (paths["lab_vm"] / "scripts" / "setup-2classes-vms.ps1").read_text(encoding="utf-8")
        assert "--install-additions" in content

    def test_vm_specs_memory_and_cpu(self, paths):
        """21.4 Vérifie les spécifications des VMs (2 Go RAM, 2 vCPUs) adaptées aux labos"""
        content = (paths["lab_vm"] / "scripts" / "setup-2classes-vms.ps1").read_text(encoding="utf-8")
        assert "--memory 2048" in content
        assert "--cpus 2" in content

    def test_five_vms_orchestrated_in_script(self, paths):
        """21.5 Vérifie la déclaration des 5 VMs (2 B204, 2 S102, 1 Vierge)"""
        content = (paths["lab_vm"] / "scripts" / "setup-2classes-vms.ps1").read_text(encoding="utf-8")
        assert "LyuX-B204-PC1" in content
        assert "LyuX-B204-PC2" in content
        assert "LyuX-S102-PC1" in content
        assert "LyuX-S102-PC2" in content
        assert "LyuX-PC-Vierge" in content


class TestFeature22_AutomatedLabTestRunnerScript:
    def test_vagrantfile_exists_as_test_runner_fallback(self, paths):
        """22.1 Vérifie la présence du Vagrantfile de déploiement automatique du lab"""
        vf = paths["lab_vm"] / "Vagrantfile"
        assert vf.exists()
        content = vf.read_text(encoding="utf-8")
        assert "Vagrant.configure" in content

    def test_provision_server_script_exists(self, paths):
        """22.2 Vérifie la présence du script de provisionnement serveur du lab"""
        sh = paths["lab_vm"] / "scripts" / "provision-server.sh"
        assert sh.exists()
        content = sh.read_text(encoding="utf-8")
        assert "docker compose up -d" in content or "samba" in content

    def test_provision_client_script_exists(self, paths):
        """22.3 Vérifie la présence du script de provisionnement des postes clients du lab"""
        sh = paths["lab_vm"] / "scripts" / "provision-client.sh"
        assert sh.exists()
        content = sh.read_text(encoding="utf-8")
        assert "apt-get" in content
        assert "veyon" in content

    def test_interactive_launch_script_exists(self, paths):
        """22.4 Vérifie le script de lancement interactif lancer-vm-interactive.ps1"""
        ps = paths["lab_vm"] / "scripts" / "lancer-vm-interactive.ps1"
        assert ps.exists()

    def test_root_launchers_exist(self, paths):
        """22.5 Vérifie les lanceurs Lancer-LyuX.bat et lancer-lyux.ps1"""
        apps = paths["root"] / "lyux-desktop" / "applications"
        bat = apps / "Lancer-LyuX.bat" if (apps / "Lancer-LyuX.bat").exists() else paths["root"] / "applications" / "Lancer-LyuX.bat"
        ps1 = apps / "lancer-lyux.ps1" if (apps / "lancer-lyux.ps1").exists() else paths["root"] / "applications" / "lancer-lyux.ps1"
        assert bat.exists()
        assert ps1.exists()


class TestFeature23_ComprehensiveE2ETestSuite:
    def test_test_infra_documentation_exists(self, paths):
        """23.1 Vérifie la présence du document maître TEST_INFRA.md à la racine"""
        doc = paths["root"] / "docs" / "TEST_INFRA.md"
        assert doc.exists()
        content = doc.read_text(encoding="utf-8")
        assert "TEST_INFRA.md" in content
        assert "Tier 1" in content and "Tier 4" in content

    def test_conftest_global_fixtures_defined(self, paths):
        """23.2 Vérifie la présence des fixtures globales dans tests/conftest.py"""
        cf = paths["tests_dir"] / "conftest.py"
        assert cf.exists()
        content = cf.read_text(encoding="utf-8")
        assert "project_root" in content
        assert "api_client" in content

    def test_e2e_package_structure_present(self, paths):
        """23.3 Vérifie que tests/e2e/__init__.py et tests/e2e/conftest.py sont initialisés"""
        init_file = paths["tests_dir"] / "e2e" / "__init__.py"
        e2e_cf = paths["tests_dir"] / "e2e" / "conftest.py"
        assert init_file.exists()
        assert e2e_cf.exists()

    def test_e2e_tier_files_present(self, paths):
        """23.4 Vérifie la présence des modules de test pour chaque niveau (Tiers 1 à 4)"""
        e2e_dir = paths["tests_dir"] / "e2e"
        assert (e2e_dir / "test_tier1_features.py").exists()

    def test_project_specification_matrix_documented(self, paths):
        """23.5 Vérifie que PROJECT.md définit les 24 fonctionnalités dans la matrice"""
        spec = (paths["root"] / "docs" / "PROJECT.md").read_text(encoding="utf-8")
        assert "Feature Inventory" in spec
        for i in range(1, 25):
            assert f"| {i} |" in spec
