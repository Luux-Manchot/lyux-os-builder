#!/usr/bin/env bash
echo "lyux-admin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/lyux-admin-nopasswd
chmod 0440 /etc/sudoers.d/lyux-admin-nopasswd
