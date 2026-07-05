echo "=== SYSTEMD SERVICES ==="
systemctl list-unit-files --state=enabled | grep -v "^#"

echo "=== CUSTOM SERVICES ==="
ls -la /etc/systemd/system/
ls -la /usr/lib/systemd/system/

echo "=== SUSPICIOUS SERVICE CONTENTS ==="
for service in $(ls /etc/systemd/system/*.service 2>/dev/null); do
    echo "File: $service"
    cat "$service"
done
