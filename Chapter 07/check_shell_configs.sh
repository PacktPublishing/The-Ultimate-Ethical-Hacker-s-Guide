echo "=== /ROOT/.BASHRC ==="
tail -20 /root/.bashrc

echo "=== /ROOT/.PROFILE ==="
tail -20 /root/.profile

echo "=== /ETC/PROFILE ==="
tail -20 /etc/profile

echo "=== /ETC/BASH.BASHRC ==="
tail -20 /etc/bash.bashrc 2>/dev/null
