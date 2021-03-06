#! /bin/bash
# set ROOT and AtoM DB passes to env vars if available otherwise defaults to dummy-pass and atom-pass
if [[ -z "${ROOT_PASS}" ]]; then
  ROOT_DB_PASS=root-pass
else
  ROOT_DB_PASS=$ROOT_PASS
fi
if [[ -z "${ATOM_PASS}" ]]; then
  ATOM_DB_PASS=atom-pass
else
  ATOM_DB_PASS=$ATOM_PASS
fi
if [[ -z "${DB_HOST}" ]]; then
  echo "skipping mysql install"
else
  echo "mysql-server-5.7 mysql-server/root_password password $ROOT_DB_PASS" | debconf-set-selections
  echo "mysql-server-5.7 mysql-server/root_password_again password $ROOT_DB_PASS" | debconf-set-selections
  apt -y install mysql-server-5.7
fi
# install JAVA
add-apt-repository ppa:openjdk-r/ppa
apt-get update
apt install -y openjdk-11-jre-headless software-properties-common
# install Elastic Search
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/5.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-5.x.list
apt update
apt install -y elasticsearch
systemctl enable elasticsearch
systemctl start elasticsearch
# install and configure Nginx
apt install -y nginx
touch /etc/nginx/sites-available/atom
ln -sf /etc/nginx/sites-available/atom /etc/nginx/sites-enabled/atom
rm /etc/nginx/sites-enabled/default
cat <<"EOF" > /etc/nginx/sites-available/atom
upstream atom {
  server unix:/run/php7.2-fpm.atom.sock;
}

server {

  listen 80;
  root /usr/share/nginx/atom;

  # http://wiki.nginx.org/HttpCoreModule#server_name
  # _ means catch any, but it's better if you replace this with your server
  # name, e.g. archives.foobar.com
  server_name _;

  client_max_body_size 72M;

  # http://wiki.nginx.org/HttpCoreModule#try_files
  location / {
    try_files $uri /index.php?$args;
  }

  location ~ /\. {
    deny all;
    return 404;
  }

  location ~* (\.yml|\.ini|\.tmpl)$ {
    deny all;
    return 404;
  }

  location ~* /(?:uploads|files)/.*\.php$ {
    deny all;
    return 404;
  }

  location ~* /uploads/r/(.*)/conf/ {

  }

  location ~* ^/uploads/r/(.*)$ {
    include /etc/nginx/fastcgi_params;
    set $index /index.php;
    fastcgi_param SCRIPT_FILENAME $document_root$index;
    fastcgi_param SCRIPT_NAME $index;
    fastcgi_pass atom;
  }

  location ~ ^/private/(.*)$ {
    internal;
    alias /usr/share/nginx/atom/$1;
  }

  location ~ ^/(index|qubit_dev)\.php(/|$) {
    include /etc/nginx/fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_split_path_info ^(.+\.php)(/.*)$;
    fastcgi_pass atom;
  }

  location ~* \.php$ {
    deny all;
    return 404;
  }

}
EOF
systemctl enable nginx
systemctl reload nginx
# Install PHP
apt install -y php7.2-cli php7.2-curl php7.2-json php7.2-ldap php7.2-mysql php7.2-opcache php7.2-readline php7.2-xml php7.2-fpm php7.2-mbstring php7.2-xsl php7.2-zip php-apcu
# Install memcache here if need it

# PHP pool
cat <<"EOF" > /etc/php/7.2/fpm/pool.d/atom.conf
[atom]

; The user running the application
user = www-data
group = www-data

; Use UNIX sockets if Nginx and PHP-FPM are running in the same machine
listen = /run/php7.2-fpm.atom.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0600

; The following directives should be tweaked based in your hardware resources
pm = dynamic
pm.max_children = 30
pm.start_servers = 10
pm.min_spare_servers = 10
pm.max_spare_servers = 10
pm.max_requests = 200

chdir = /

; Some defaults for your PHP production environment
; A full list here: http://www.php.net/manual/en/ini.list.php
php_admin_value[expose_php] = off
php_admin_value[allow_url_fopen] = on
php_admin_value[memory_limit] = 512M
php_admin_value[max_execution_time] = 120
php_admin_value[post_max_size] = 72M
php_admin_value[upload_max_filesize] = 64M
php_admin_value[max_file_uploads] = 10
php_admin_value[cgi.fix_pathinfo] = 0
php_admin_value[display_errors] = off
php_admin_value[display_startup_errors] = off
php_admin_value[html_errors] = off
php_admin_value[session.use_only_cookies] = 0

; APC
php_admin_value[apc.enabled] = 1
php_admin_value[apc.shm_size] = 64M
php_admin_value[apc.num_files_hint] = 5000
php_admin_value[apc.stat] = 0

; Zend OPcache
php_admin_value[opcache.enable] = 1
php_admin_value[opcache.memory_consumption] = 192
php_admin_value[opcache.interned_strings_buffer] = 16
php_admin_value[opcache.max_accelerated_files] = 4000
php_admin_value[opcache.validate_timestamps] = 0
php_admin_value[opcache.fast_shutdown] = 1

; This is a good place to define some environment variables, e.g. use
; ATOM_DEBUG_IP to define a list of IP addresses with full access to the
; debug frontend or ATOM_READ_ONLY if you want AtoM to prevent
; authenticated users
env[ATOM_DEBUG_IP] = "10.10.10.10,127.0.0.1"
env[ATOM_READ_ONLY] = "off"
EOF
systemctl enable php7.2-fpm
systemctl start php7.2-fpm
# remove default PHP pool
rm /etc/php/7.2/fpm/pool.d/www.conf
systemctl restart php7.2-fpm
# install GEARMAN
apt install -y gearman-job-server
cat <<"EOF" > /usr/lib/systemd/system/atom-worker.service
[Unit]
Description=AtoM worker
After=network.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/usr/share/nginx/atom
ExecStart=/usr/bin/php -d memory_limit=-1 -d error_reporting="E_ALL" symfony jobs:worker
ExecStop=/bin/kill -s TERM $MAINPID
Restart=no
EOF
systemctl daemon-reload
systemctl enable atom-worker
# FOP
apt install -y --no-install-recommends fop libsaxon-java
# Optional: apt-get install -y imagemagick ghostscript poppler-utils ffmpeg
# Install AtoM
wget https://storage.accesstomemory.org/releases/atom-2.5.0.tar.gz
mkdir /usr/share/nginx/atom
tar xzf atom-2.5.0.tar.gz -C /usr/share/nginx/atom --strip 1
chown -R www-data:www-data /usr/share/nginx/atom
chmod o= /usr/share/nginx/atom
# Setup DB
if [[ -z "${DB_HOST}" ]]; then
  echo "Skipping DB setup. Make sure you have an 'atom' database on your DB server (CREATE DATABASE atom CHARACTER SET utf8 COLLATE utf8_unicode_ci;)"
else
  mysql -h localhost -u root -p$ROOT_DB_PASS -e "CREATE DATABASE atom CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
  mysql -h localhost -u root -p$ROOT_DB_PASS -e "GRANT ALL ON atom.* TO 'atom'@'localhost' IDENTIFIED BY '$ATOM_DB_PASS';"
  cat <<"EOF" > /etc/mysql/conf.d/mysqld.cnf
[mysqld]
sql_mode=STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
EOF
systemctl restart mysql
fi