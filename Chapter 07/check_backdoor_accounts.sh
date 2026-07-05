echo "=== USER ACCOUNTS ==="
cat /etc/passwd | cut -d: -f1,3,5

echo "=== RECENT PASSWORD CHANGES ==="
lastlog

echo "=== SUDOERS MODIFICATIONS ==="
cat /etc/sudoers
ls -la /etc/sudoers.d/
