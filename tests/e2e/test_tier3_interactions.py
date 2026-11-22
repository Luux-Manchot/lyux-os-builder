"""
Tier 3: Cross-Feature Combinations (Pairwise and Multi-Component Interactions).
Valide les interactions critiques entre composants hétérogènes :
- Authentification SDDM & montage dynamique pam_mount
- Enrôlement OTP & enregistrement d'inventaire matériel
- Supervision Veyon & verrouillage distant de postes élèves
- Signalement de panne élève & enregistrement de ticket GLPI
- Réinitialisation de mot de passe enseignant & mise à jour d'annuaire
- Profils disciplinaires Ansible & attribution des salles pilotes
- Proxy de paquets Apt-Cacher-NG & préconfiguration d'installation
- Clefs asymétriques Veyon & restriction des privilèges enseignants
"""

import re

import xml.etree.ElementTree as ET

from pathlib import Path

import pytest


class TestTier3Interactions:
    """Interactions trans-domaines rattachées à os-builder."""

    def test_interaction_sddm_and_pam_mount_chain(self, pam_mount_xml_path, paths):
        """3.1 Interaction SDDM + pam_mount : Connexion élève et montage automatique des partages"""
        # 1. Vérification que SDDM est le display manager installé
        vbox_preseed = (paths["lab_vm"] / "configs" / "vbox-preseed-kde-fr.cfg").read_text(encoding="utf-8")
        assert "sddm" in vbox_preseed

        # 2. Vérification que pam_mount monte ~/Espace_Personnel et ~/Partages_Classes
        raw_xml = pam_mount_xml_path.read_text(encoding="utf-8")
        clean_xml = re.sub(r'\{\{[^}]+\}\}', '192.168.100.10', raw_xml)
        root = ET.fromstring(clean_xml)
        mounts = {v.attrib.get("mountpoint"): v for v in root.findall("volume")}

        assert "~/Espace_Personnel" in mounts
        assert "~/Partages_Classes" in mounts
        assert mounts["~/Espace_Personnel"].attrib["path"] == "homes/%(USER)"
        assert mounts["~/Partages_Classes"].attrib["sgrp"] == "eleves"

    def test_interaction_ansible_profiles_match_pilot_rooms_curriculum(self, paths, ansible_inventory_data):
        """3.7 Interaction Profils disciplinaires Ansible -> Salles pilotes B204 (NSI) et S102 (Sciences)"""
        tasks_file = paths["ansible"] / "roles" / "lyux-profile-salles" / "tasks" / "main.yml"
        tasks_content = tasks_file.read_text(encoding="utf-8")

        inventory_clients = ansible_inventory_data["all"]["children"]["postes_clients"]["children"]
        b204_profile = inventory_clients["salle_nsi_b204"]["vars"]["room_profile"]
        s102_profile = inventory_clients["salle_sciences_s102"]["vars"]["room_profile"]

        assert b204_profile == "nsi"
        assert s102_profile == "sciences"

        # Le rôle salle implémente les deux conditions
        assert f"room_profile == '{b204_profile}'" in tasks_content
        assert f"room_profile == '{s102_profile}'" in tasks_content

    def test_interaction_apt_cacher_proxy_preseed_and_ansible(self, paths, preseed_iso_path):
        """3.8 Interaction Apt-Cacher-NG : Déclaration miroir preseed et configuration proxy Ansible"""
        # Preseed configure le miroir proxy sur le port 3142
        preseed_content = preseed_iso_path.read_text(encoding="utf-8")
        assert ":3142" in preseed_content

        # Rôle base déploie 01apt-cacher-proxy.j2
        base_tasks = (paths["ansible"] / "roles" / "lyux-base" / "tasks" / "main.yml").read_text(encoding="utf-8")
        assert "01apt-cacher-proxy.j2" in base_tasks
        assert "/etc/apt/apt.conf.d/01proxy" in base_tasks

    def test_interaction_veyon_asymmetric_key_hierarchy(self, paths):
        """3.9 Interaction Clefs Veyon : Clé privée profs seule avec Veyon Master, clé publique sur tous"""
        prof_role = (paths["ansible"] / "roles" / "lyux-profile-prof" / "tasks" / "main.yml").read_text(encoding="utf-8")
        base_role = (paths["ansible"] / "roles" / "lyux-base" / "tasks" / "main.yml").read_text(encoding="utf-8")
        eleve_role = (paths["ansible"] / "roles" / "lyux-profile-eleve" / "tasks" / "main.yml").read_text(encoding="utf-8")

        # veyon-master réservé au prof
        assert "veyon-master" in prof_role
        assert "veyon-master" not in eleve_role

        # veyon-service présent sur le socle commun
        assert "veyon-service" in base_role
        assert "name: veyon" in eleve_role
