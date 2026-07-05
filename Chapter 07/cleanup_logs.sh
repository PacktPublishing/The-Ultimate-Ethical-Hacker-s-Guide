#!/bin/bash

#################################################################
# ETHICAL HACKING LAB LOG CLEANUP SCRIPT
# 
# PURPOSE: Clear forensic evidence of testing activities from
#          an authorized, isolated lab environment.
#
# USAGE: sudo bash cleanup_logs.sh
#
# WARNING: This is ONLY for authorized lab environments.
#          Do NOT use on production or unauthorized systems.
#################################################################

# Color output for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}================================================${NC}"
echo -e "${RED}SYSTEM LOG CLEANUP SCRIPT${NC}"
echo -e "${YELLOW}================================================${NC}"
echo ""
echo -e "${RED}WARNING: This will PERMANENTLY DELETE all system logs.${NC}"
echo -e "${RED}This should ONLY be done in authorized lab environments.${NC}"
echo ""
echo "Proceed? (type 'YES' to continue)"
read -p "> " confirmation

if [ "$confirmation" != "YES" ]; then
    echo -e "${GREEN}Cleanup cancelled.${NC}"
    exit 0
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: This script must be run as root (use sudo).${NC}"
    exit 1
fi

echo -e "${YELLOW}[*] Starting log cleanup...${NC}"
echo ""

# 1. Clear auth log
echo -e "${YELLOW}[*] Clearing authentication logs...${NC}"
if [ -f /var/log/auth.log ]; then
    > /var/log/auth.log
    echo -e "${GREEN}[+] Cleared /var/log/auth.log${NC}"
fi

# 2. Clear syslog
echo -e "${YELLOW}[*] Clearing system logs...${NC}"
if [ -f /var/log/syslog ]; then
    > /var/log/syslog
    echo -e "${GREEN}[+] Cleared /var/log/syslog${NC}"
fi

# 3. Clear kernel log
echo -e "${YELLOW}[*] Clearing kernel logs...${NC}"
if [ -f /var/log/kern.log ]; then
    > /var/log/kern.log
    echo -e "${GREEN}[+] Cleared /var/log/kern.log${NC}"
fi

# 4. Clear cron log
echo -e "${YELLOW}[*] Clearing cron logs...${NC}"
if [ -f /var/log/cron.log ]; then
    > /var/log/cron.log
    echo -e "${GREEN}[+] Cleared /var/log/cron.log${NC}"
fi

# 5. Clear systemd journal (modern systems)
echo -e "${YELLOW}[*] Clearing systemd journal...${NC}"
journalctl --vacuum=0 > /dev/null 2>&1
echo -e "${GREEN}[+] Cleared systemd journal${NC}"

# 6. Clear wtmp (login history)
echo -e "${YELLOW}[*] Clearing login history...${NC}"
if [ -f /var/log/wtmp ]; then
    > /var/log/wtmp
    echo -e "${GREEN}[+] Cleared /var/log/wtmp${NC}"
fi

# 7. Clear utmp (active users)
echo -e "${YELLOW}[*] Clearing active user log...${NC}"
if [ -f /var/log/utmp ]; then
    > /var/log/utmp
    echo -e "${GREEN}[+] Cleared /var/log/utmp${NC}"
fi

# 8. Clear lastlog (last login info)
echo -e "${YELLOW}[*] Clearing last login info...${NC}"
if [ -f /var/log/lastlog ]; then
    > /var/log/lastlog
    echo -e "${GREEN}[+] Cleared /var/log/lastlog${NC}"
fi

# 9. Clear all logs in /var/log/ subdirectories
echo -e "${YELLOW}[*] Clearing miscellaneous logs in /var/log/...${NC}"
find /var/log/ -type f -name "*.log" -exec sh -c '> "$1" 2>/dev/null' _ {} \;
echo -e "${GREEN}[+] Cleared /var/log/*.log files${NC}"

# 10. Clear bash history for all users
echo -e "${YELLOW}[*] Clearing bash command history...${NC}"
for user in $(cut -d: -f1 /etc/passwd); do
    history_file="/home/$user/.bash_history"
    if [ -f "$history_file" ]; then
        > "$history_file"
    fi
done
> /root/.bash_history
echo -e "${GREEN}[+] Cleared .bash_history for all users${NC}"

# 11. Clear shell history variables (current session)
echo -e "${YELLOW}[*] Clearing current session history...${NC}"
history -c
history -w
echo -e "${GREEN}[+] Cleared current session history${NC}"

# 12. Clear apt/package manager logs (Debian-based)
echo -e "${YELLOW}[*] Clearing package manager logs...${NC}"
if [ -f /var/log/apt/history.log ]; then
    > /var/log/apt/history.log
fi
if [ -f /var/log/apt/term.log ]; then
    > /var/log/apt/term.log
fi
echo -e "${GREEN}[+] Cleared package manager logs${NC}"

# 13. Clear temporary files
echo -e "${YELLOW}[*] Clearing temporary files...${NC}"
rm -f /tmp/* 2>/dev/null
rm -f /var/tmp/* 2>/dev/null
rm -f /dev/shm/* 2>/dev/null
echo -e "${GREEN}[+] Cleared /tmp, /var/tmp, /dev/shm${NC}"

# 14. Clear sudo logs (if sudo logging is enabled)
echo -e "${YELLOW}[*] Clearing sudo logs...${NC}"
if [ -f /var/log/sudo.log ]; then
    > /var/log/sudo.log
    echo -e "${GREEN}[+] Cleared /var/log/sudo.log${NC}"
fi

# 15. Clear SSH key fingerprints in known_hosts (optional - comment out if not needed)
echo -e "${YELLOW}[*] Clearing SSH known_hosts...${NC}"
for user in $(cut -d: -f1 /etc/passwd); do
    known_hosts="/home/$user/.ssh/known_hosts"
    if [ -f "$known_hosts" ]; then
        > "$known_hosts"
    fi
done
> /root/.ssh/known_hosts 2>/dev/null
echo -e "${GREEN}[+] Cleared .ssh/known_hosts${NC}"

echo ""
echo -e "${YELLOW}================================================${NC}"
echo -e "${GREEN}[+] Log cleanup completed successfully!${NC}"
echo -e "${YELLOW}================================================${NC}"
echo ""
echo -e "${YELLOW}Summary of cleared logs:${NC}"
echo "  - Authentication logs (/var/log/auth.log)"
echo "  - System logs (/var/log/syslog)"
echo "  - Kernel logs (/var/log/kern.log)"
echo "  - Cron logs (/var/log/cron.log)"
echo "  - Systemd journal (journalctl)"
echo "  - Login history (wtmp, utmp, lastlog)"
echo "  - Bash history (all users)"
echo "  - Package manager logs"
echo "  - Temporary files (/tmp, /var/tmp, /dev/shm)"
echo "  - SSH known_hosts"
echo ""
echo -e "${RED}NOTE: This cleanup is NOT complete anonymization.${NC}"
echo -e "${RED}Forensic tools may still recover deleted data.${NC}"
echo ""
