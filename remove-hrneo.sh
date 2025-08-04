#!/bin/sh
# Удаление HRNeo WebUI

# === АНИМАЦИЯ ===
animation() {
    local pid=$1 message=$2 spin='|/-\\' i=0
    echo -n "[ ] $message..."
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r[%s] %s..." "${spin:$i:1}" "$message"
        usleep 100000
    done
    wait $pid
    if [ $? -eq 0 ]; then
        printf "\r[✔] %s\n" "$message"
    else
        printf "\r[✖] %s\n" "$message"
    fi
}

run_with_animation() {
    local msg="$1"
    shift
    ("$@") >/dev/null 2>&1 &
    animation $! "$msg"
}

echo "Начинается удаление HRNeo WebUI..."

run_with_animation "Остановка сервисов"
/opt/etc/init.d/S80lighttpd stop

run_with_animation "Удаление Lighttpd + PHP8" \
    opkg remove lighttpd lighttpd-mod-cgi lighttpd-mod-setenv lighttpd-mod-redirect lighttpd-mod-rewrite \
    php8 php8-cgi php8-cli php8-mod-curl php8-mod-openssl php8-mod-session jq

run_with_animation "Удаление директорий" \
    rm -rf /opt/share/www/hrneo
    rm -rf /opt/etc/lighttpd
    rm -rf /opt/etc/init.d/S80lighttpd
echo ""
echo "✅ HRNeo WebUI удален с устройства"
