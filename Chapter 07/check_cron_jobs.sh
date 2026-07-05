echo "=== ROOT CRONTAB ==="
crontab -u root -l

echo "=== USER CRONTABS ==="
for user in $(cut -d: -f1 /etc/passwd); do
    crontab -u $user -l 2>/dev/null | grep -v "^#"
done

echo "=== SYSTEM-WIDE CRON ==="
ls -la /etc/cron.d/
ls -la /etc/cron.daily/
ls -la /etc/cron.hourly/
ls -la /etc/cron.weekly/
ls -la /etc/cron.monthly/
