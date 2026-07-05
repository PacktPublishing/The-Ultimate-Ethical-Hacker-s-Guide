echo "=== INIT.D SCRIPTS ==="
ls -la /etc/init.d/ | grep -v "^total"

echo "=== RUNLEVEL SYMLINKS ==="
ls -la /etc/rc*.d/ | grep -E "^l"   # Show only symlinks
