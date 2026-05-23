echo "Починаємо встановлення пакетів..."
apt update
apt install -y nodejs npm mariadb-server nginx git curl

echo "Створення користувачів..."
useradd -m -s /bin/bash -G sudo student 2>/dev/null || true
echo "student:student123" | chpasswd

useradd -m -s /bin/bash -G sudo teacher 2>/dev/null || true
echo "teacher:12345678" | chpasswd
chage -d 0 teacher

useradd -r -s /bin/false app 2>/dev/null || true

groupadd operator 2>/dev/null || true
useradd -m -s /bin/bash -g operator operator 2>/dev/null || true
echo "operator:12345678" | chpasswd
chage -d 0 operator

cat <<EOF > /etc/sudoers.d/operator
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl start mywebapp.service, /usr/bin/systemctl stop mywebapp.service, /usr/bin/systemctl restart mywebapp.service, /usr/bin/systemctl status mywebapp.service, /usr/bin/systemctl reload nginx
EOF

echo "Налаштування MariaDB..."
mysql -e "CREATE DATABASE IF NOT EXISTS mywebapp;"
mysql -e "CREATE USER IF NOT EXISTS 'app'@'127.0.0.1' IDENTIFIED BY 'password';"
mysql -e "GRANT ALL PRIVILEGES ON mywebapp.* TO 'app'@'127.0.0.1';"
mysql -e "FLUSH PRIVILEGES;"

echo "Розміщення файлів застосунку..."
mkdir -p /opt/mywebapp
cp app.js migrate.js package.json /opt/mywebapp/
cd /opt/mywebapp
npm install express minimist mariadb@2
chown -R app:app /opt/mywebapp

echo "Налаштування Systemd Socket Activation..."
cat << 'EOF' > /etc/systemd/system/mywebapp.socket
[Unit]
Description=My Web App Socket

[Socket]
ListenStream=127.0.0.1:5200

[Install]
WantedBy=sockets.target
EOF

cat << 'EOF' > /etc/systemd/system/mywebapp.service
[Unit]
Description=My Web App (Notes Service)
Requires=mywebapp.socket
After=network.target mariadb.service mywebapp.socket

[Service]
User=app
Group=app
WorkingDirectory=/opt/mywebapp
ExecStartPre=/usr/bin/node /opt/mywebapp/migrate.js --dbuser=app --dbpassword=password --dbname=mywebapp
ExecStart=/usr/bin/node /opt/mywebapp/app.js --port=5200 --dbuser=app --dbpassword=password --dbname=mywebapp
Restart=always
EOF

systemctl daemon-reload
systemctl disable --now mywebapp.service
systemctl enable --now mywebapp.socket

echo "Налаштування Nginx..."
cat << 'EOF' > /etc/nginx/sites-available/mywebapp
server {
    listen 80;
    access_log /var/log/nginx/mywebapp_access.log;
    
    location = / { proxy_pass http://127.0.0.1:5200; }
    location /notes { proxy_pass http://127.0.0.1:5200; }
    location /health/ { return 403; }
}
EOF

ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

echo "Створення файлу gradebook..."
echo "6" > /home/student/gradebook
chown student:student /home/student/gradebook

# usermod -L "$SUDO_USER" 
echo "Розгортання успішно завершено!"
