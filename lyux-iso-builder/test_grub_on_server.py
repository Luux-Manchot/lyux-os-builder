import subprocess
import sys

def run(cmd):
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    print(f"=== CMD: {cmd} ===")
    print(f"RC: {p.returncode}")
    if p.stdout.strip():
        print(f"STDOUT:\n{p.stdout.strip()}")
    if p.stderr.strip():
        print(f"STDERR:\n{p.stderr.strip()}")
    return p

run("truncate -s 500M /tmp/test_grub.img")
p = run("losetup -fP --show /tmp/test_grub.img")
loop = p.stdout.strip()
print(f"LOOP DEVICE: {loop}")

try:
    run(f"parted -s {loop} mklabel msdos")
    run(f"parted -s {loop} mkpart primary ext4 1MiB 100%")
    run(f"parted -s {loop} set 1 boot on")
    run(f"mkfs.ext4 -F {loop}p1")
    run("mkdir -p /tmp/mnt_test")
    run(f"mount {loop}p1 /tmp/mnt_test")
    run("mkdir -p /tmp/mnt_test/boot/grub")

    # Method 1: Host grub-install with --boot-directory
    p1 = run(f"/usr/sbin/grub-install --target=i386-pc --recheck --boot-directory=/tmp/mnt_test/boot {loop}")
    
    # Check MBR
    run(f"file -s {loop}")
    run(f"hexdump -C -n 512 {loop} | grep -i grub")
finally:
    run("umount -R /tmp/mnt_test 2>/dev/null || true")
    run(f"losetup -d {loop} 2>/dev/null || true")
    run("rm -f /tmp/test_grub.img")
