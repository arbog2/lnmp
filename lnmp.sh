#!/bin/bash

# =============================================================================
# LNMP 一键安装脚本 (Debian 12/13)
# 功能：
# - 编译安装 Nginx、MySQL、PHP
# - 支持自定义版本号、路径、密码等参数
# - 检查本地源码，不存在则下载
# - 创建 lnmp 系统命令
# - 检查磁盘和内存空间
# =============================================================================

set -e

# 默认配置
DEFAULT_NGINX_VERSION="1.30.0"
DEFAULT_MYSQL_VERSION="8.4.8"
DEFAULT_PHP_VERSION="8.4.20"
DEFAULT_WEB_PATH="/home/wwwroot/html"
DEFAULT_LOG_PATH="/home/wwwlogs"
DEFAULT_SSL_PATH="/usr/local/nginx/conf/ssl"
DEFAULT_DATA_PATH="/home/mysql"
DEFAULT_INSTALL_PATH="/usr/local"

# 全局变量
NGINX_VERSION=${NGINX_VERSION:-$DEFAULT_NGINX_VERSION}
MYSQL_VERSION=${MYSQL_VERSION:-$DEFAULT_MYSQL_VERSION}
PHP_VERSION=${PHP_VERSION:-$DEFAULT_PHP_VERSION}
WEB_PATH=${WEB_PATH:-$DEFAULT_WEB_PATH}
LOG_PATH=${LOG_PATH:-$DEFAULT_LOG_PATH}
SSL_PATH=${SSL_PATH:-$DEFAULT_SSL_PATH}
DATA_PATH=${DATA_PATH:-$DEFAULT_DATA_PATH}
INSTALL_PATH=${INSTALL_PATH:-$DEFAULT_INSTALL_PATH}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-"gzmcisco"}

# 源码目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/src"
#SRC_DIR="./src"
mkdir -p "${SRC_DIR}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# 检查磁盘空间
check_disk_space() {
    local required_space_gb=$1
    local available_space_kb=$(df / | tail -1 | awk '{print $4}')
    local available_space_gb=$((available_space_kb / 1024 / 1024))
    
    log_info "Required disk space: ${required_space_gb}GB"
    log_info "Available disk space: ${available_space_gb}GB"
    
    if [[ $available_space_gb -lt $required_space_gb ]]; then
        log_error "Not enough disk space. Required: ${required_space_gb}GB, Available: ${available_space_gb}GB"
        exit 1
    fi
}

# 检查内存
check_memory() {
    local required_memory_mb=$1
    local available_memory_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local available_memory_mb=$((available_memory_kb / 1024))
    
    log_info "Required memory: ${required_memory_mb}MB"
    log_info "Available memory: ${available_memory_mb}MB"
    
    if [[ $available_memory_mb -lt $required_memory_mb ]]; then
        log_error "Not enough memory. Required: ${required_memory_mb}MB, Available: ${available_memory_mb}MB"
        exit 1
    fi
}

# 安装系统依赖
install_dependencies() {
    log_info "Updating system packages..."
    apt update
    
    log_info "Installing required dependencies..."
    apt install -y \
        build-essential \
        wget \
        curl \
        git \
        cmake \
        gcc \
        g++ \
        make \
        libtool \
        autoconf \
        pkg-config \
        gnupg2 \
        ca-certificates \
        lsb-release \
        libpcre2-dev \
        libssl-dev \
        libcurl4-openssl-dev \
        libjpeg-dev \
        libpng-dev \
        libfreetype6-dev \
        libonig-dev \
        libzip-dev \
        libxml2-dev \
        libxslt1-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        libgmp-dev \
        libldap2-dev \
        libmemcached-dev \
        libsasl2-dev \
        libkrb5-dev \
        libedit-dev \
        libncurses5-dev \
        libaio-dev \
        libnuma-dev \
        libtinfo-dev \
        libncurses-dev \
        libargon2-dev \
        libffi-dev \
        libgd-dev \
        libicu-dev \
        libpspell-dev \
        librecode-dev \
        libsnmp-dev \
        libtidy-dev \
        libwebp-dev \
        libxpm-dev \
        libgdbm-dev \
        libexpat1-dev \
        libgssapi-krb5-2 \
        libicu-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libxpm-dev \
        libfreetype6-dev \
        libssl-dev \
        libcurl4-openssl-dev \
        libonig-dev \
        libzip-dev \
        libxml2-dev \
        libxslt1-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        libgmp-dev \
        libldap2-dev \
        libmemcached-dev \
        libsasl2-dev \
        libkrb5-dev \
        libedit-dev \
        libncurses5-dev \
        libtinfo-dev \
        libncurses-dev \
        libmaxminddb-dev \
        libtirpc-dev \
        libatomic1 \
        ninja-build
    
    log_success "Dependencies installed successfully"
}

# 下载源码包
download_source() {
    local software=$1
    local version=$2
    local url=$3
    local filename=$4
    
    if [[ ! -f "$SRC_DIR/$filename" ]]; then
        log_info "Downloading $software-$version source code..."
        wget -O "$SRC_DIR/$filename" "$url" || {
            log_error "Failed to download $software-$version"
            exit 1
        }
        log_success "$software-$version source downloaded"
    else
        log_info "Using existing $software-$version source from $SRC_DIR/$filename"
    fi
}

# 编译安装 Nginx
install_nginx() {
    log_info "Starting Nginx installation..."
    
    local nginx_filename="nginx-${NGINX_VERSION}.tar.gz"
    local nginx_url="http://nginx.org/download/${nginx_filename}"
    
    download_source "Nginx" "$NGINX_VERSION" "$nginx_url" "$nginx_filename"
    
    # 记录当前目录
    local current_dir=$(pwd)
    
    cd "$SRC_DIR"
    tar -zxf "$nginx_filename"
    cd "nginx-${NGINX_VERSION}"
    
    log_info "Configuring Nginx..."
    ./configure \
        --prefix="${INSTALL_PATH}/nginx" \
        --sbin-path="${INSTALL_PATH}/nginx/sbin/nginx" \
        --conf-path="${INSTALL_PATH}/nginx/conf/nginx.conf" \
        --error-log-path="${LOG_PATH}/error.log" \
        --http-log-path="${LOG_PATH}/access.log" \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --with-pcre \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_stub_status_module \
        --with-http_auth_request_module \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-stream_realip_module \
        --with-http_slice_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-compat \
        --with-file-aio \
        --with-http_v2_module
    
    log_info "Compiling Nginx..."
    make -j$(nproc)
    
    log_info "Installing Nginx..."
    make install
    
    # 返回到源码目录
    cd "$current_dir"
    cd "$SRC_DIR"
	if getent group www >/dev/null 2>&1; then
		echo "组 www 已存在，跳过创建"
	else
		/usr/sbin/groupadd www
		if [ $? -eq 0 ]; then
			echo "组 www 创建成功"
		else
			echo "组 www 创建失败，退出"
			exit 1
		fi
	fi

	# 创建用户 www（如不存在）
	if getent passwd www >/dev/null 2>&1; then
		echo "用户 www 已存在，跳过创建"
	else
		# 常用选项：主组 www，禁止登录 shell，创建家目录 /home/www
		/usr/sbin/useradd -s /sbin/nologin -g www www
		if [ $? -eq 0 ]; then
			echo "用户 www 创建成功"
		else
			echo "用户 www 创建失败"
			exit 1
		fi
	fi
	mkdir -p "$LOG_PATH"
    chmod 777 "$LOG_PATH"
    # 创建默认网站目录
    mkdir -p "${WEB_PATH}"
	chmod +w "${WEB_PATH}"
	chown -R www:www "$WEB_PATH"
	cat >$WEB_PATH/.user.ini<<EOF
open_basedir=$WEB_PATH:/tmp/:/proc/
EOF
        chmod 644 ${WEB_PATH}/.user.ini
        chattr +i ${WEB_PATH}/.user.ini
		cat >>/usr/local/nginx/conf/fastcgi.conf<<EOF
fastcgi_param PHP_ADMIN_VALUE "open_basedir=\$document_root/:/tmp/:/proc/";
EOF
    echo "<h1>Welcome to LNMP on Debian!</h1><p>Nginx is running.</p>" > "$WEB_PATH/index.html"
    
    # 创建 Nginx 服务文件
    cat > /lib/systemd/system/nginx.service << EOF
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=${INSTALL_PATH}/nginx/sbin/nginx -t
ExecStart=${INSTALL_PATH}/nginx/sbin/nginx
ExecReload=/bin/kill -s HUP \$MAINPID
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=process
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    log_success "Nginx installed successfully"
}

# 编译安装 MySQL
install_mysql() {
    log_info "Starting MySQL installation..."
	id mysql &>/dev/null || /usr/sbin/useradd -r -s /bin/false mysql
    log_info "Checking for existing MySQL processes..."
	if pgrep mysqld > /dev/null; then
		log_warn "Existing mysqld process found, stopping..."
		systemctl stop mysql 2>/dev/null || true
		pkill -9 mysqld 2>/dev/null || true
		sleep 2
	fi

	# 清理残留的 socket 文件
	rm -rf /var/run/mysqld/*.sock 2>/dev/null || true
	mkdir -p /var/run/mysqld
	chown mysql:mysql /var/run/mysqld
    local mysql_filename="mysql-${MYSQL_VERSION}.tar.gz"
    local mysql_url="https://cdn.mysql.com/Downloads/MySQL-8.4/${mysql_filename}"
    
    # 尝试备用 URL
    if ! download_source "MySQL" "$MYSQL_VERSION" "$mysql_url" "$mysql_filename"; then
        mysql_url="https://dev.mysql.com/get/Downloads/MySQL-8.4/${mysql_filename}"
        download_source "MySQL" "$MYSQL_VERSION" "$mysql_url" "$mysql_filename"
    fi
    
    # 记录当前目录
    local current_dir=$(pwd)
    
    cd "$SRC_DIR"
    
    # 如果目录存在，先删除旧的构建目录
    if [[ -d "mysql-${MYSQL_VERSION}-build" ]]; then
        rm -rf "mysql-${MYSQL_VERSION}-build"
    fi
    
    # 解压 MySQL 源码（如果尚未解压）
    if [[ ! -d "mysql-${MYSQL_VERSION}" ]]; then
        tar -zxf "$mysql_filename"
    fi
    
    # 创建构建目录并进入
    mkdir -p "mysql-${MYSQL_VERSION}-build"
    cd "mysql-${MYSQL_VERSION}-build"
    
    # 使用 out-of-source 构建方式配置 MySQL，针对 8.4 版本优化参数
    log_info "Configuring MySQL with out-of-source build for version 8.4..."
    cmake "../mysql-${MYSQL_VERSION}" \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PATH}/mysql" \
        -DMYSQL_DATADIR="${DATA_PATH}" \
        -DSYSCONFDIR=/etc \
        -DWITH_SSL=system \
        -DWITH_ZLIB=system \
        -DENABLED_LOCAL_INFILE=1 \
        -DMYSQL_TCP_PORT=3306 \
        -DMYSQL_UNIX_ADDR=/var/run/mysqld/mysqld.sock \
        -DWITH_BOOST="../mysql-${MYSQL_VERSION}/boost/boost_1_77_0" \
        -DAIO=1 \
        -DDOWNLOAD_BOOST=OFF \
        -DWITH_UNIT_TESTS=OFF \
        -DWITHOUT_AUTHENTICATION_LDAP=ON \
        -DWITH_EDITLINE=system
    
    log_info "Compiling MySQL (this may take a while)..."
    make -j$(nproc)
    
    log_info "Installing MySQL..."
    make install
    
    # 返回到源码目录
    cd "$current_dir"
    cd "$SRC_DIR"
    
    # 创建 MySQL 用户
    #id mysql &>/dev/null || useradd -r -s /bin/false mysql
    
    # 创建必要的目录
    mkdir -p "${DATA_PATH}"
    mkdir -p "${INSTALL_PATH}/mysql/logs"
    mkdir -p /etc/mysql
    
    # 设置目录权限
    chown -R mysql:mysql "${DATA_PATH}"
    chown -R mysql:mysql "${INSTALL_PATH}/mysql"
    chown -R mysql:mysql "${INSTALL_PATH}/mysql/logs"
    
    # 创建 MySQL 配置文件
    cat > /etc/mysql/my.cnf << EOF
[client]
port = 3306
socket = /var/run/mysqld/mysqld.sock

[mysqld]
port = 3306
socket = /var/run/mysqld/mysqld.sock
datadir = ${DATA_PATH}
basedir = ${INSTALL_PATH}/mysql
user = mysql
bind-address = 127.0.0.1
server-id = 1

# InnoDB settings
innodb_buffer_pool_size = 128M
innodb_log_file_size = 64M
innodb_file_per_table = 1

# Logging
log-error = ${INSTALL_PATH}/mysql/logs/error.log
slow_query_log = 1
slow_query_log_file = ${INSTALL_PATH}/mysql/logs/slow.log
long_query_time = 2

# Security
#default_authentication_plugin = mysql_native_password

[mysql]
socket = /var/run/mysqld/mysqld.sock

[mysqld_safe]
log-error = ${INSTALL_PATH}/mysql/logs/error.log
pid-file = /var/run/mysqld/mysqld.pid
EOF
    
    log_info "Initializing MySQL database..."
    
    # 确保数据目录是空的（如果是全新安装）
    if [[ -d "${DATA_PATH}" && "$(ls -A ${DATA_PATH})" ]]; then
        log_warn "Data directory ${DATA_PATH} is not empty, removing contents..."
        rm -rf "${DATA_PATH}"/*
    fi
    
    # 创建一个临时配置文件用于初始化
    local temp_conf=$(mktemp)
    cat > "$temp_conf" << EOF
[mysqld]
datadir = ${DATA_PATH}
basedir = ${INSTALL_PATH}/mysql
socket = /var/run/mysqld/mysqld.sock
user = mysql
port = 3306
log-error = ${INSTALL_PATH}/mysql/logs/error.log
EOF
    
    # 使用绝对路径执行初始化，避免路径问题
    log_info "Running MySQL initialization command..."
    timeout 180 "${INSTALL_PATH}/mysql/bin/mysqld" \
        --defaults-file="$temp_conf" \
        --initialize-insecure \
        --user=mysql || {
            log_error "MySQL initialization failed"
            # 检查错误日志
            if [[ -f "${INSTALL_PATH}/mysql/logs/error.log" ]]; then
                log_info "Error log contents:"
                cat "${INSTALL_PATH}/mysql/logs/error.log"
            fi
            rm -f "$temp_conf"
            exit 1
        }
    
    log_info "MySQL database initialized successfully"
    # 创建 socket 目录并启动临时服务（如果还没启动）
	mkdir -p /var/run/mysqld
	chown mysql:mysql /var/run/mysqld
	cat > /etc/tmpfiles.d/mysql.conf << EOF
d /var/run/mysqld 0755 mysql mysql -
EOF
    # 清理临时配置文件
    rm -f "$temp_conf"
    
    # 创建 MySQL 服务文件
    cat > /lib/systemd/system/mysql.service << EOF
[Unit]
Description=MySQL Server
After=network.target

[Service]
Type=simple
User=mysql
Group=mysql
ExecStartPre=/bin/mkdir -p /home/mysql
ExecStartPre=/bin/chown mysql:mysql /home/mysql
ExecStartPre=/bin/mkdir -p /var/run/mysqld
ExecStartPre=/bin/chown mysql:mysql /var/run/mysqld
ExecStart=/usr/local/mysql/bin/mysqld --defaults-file=/etc/mysql/my.cnf
TimeoutSec=300
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
	 # 设置 MySQL root 密码
    log_info "Starting MySQL to set root password..."
    
    # 创建必要的运行时目录
    mkdir -p /var/run/mysqld
    chown mysql:mysql /var/run/mysqld
    
    # 启动 MySQL
    systemctl start mysql
    sleep 5  # 等待 MySQL 完全启动

    # 设置密码（空密码登录）
    if ${INSTALL_PATH}/mysql/bin/mysql -u root --socket=/var/run/mysqld/mysqld.sock -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" 2>/dev/null; then
        log_success "MySQL root password set to: ${MYSQL_ROOT_PASSWORD}"
    else
        log_warn "Failed to set root password automatically. Please run 'mysql_secure_installation' manually."
    fi

    # 重启确保配置生效
    systemctl restart mysql

    log_success "MySQL installed successfully"
}

# 编译安装 PHP
install_php() {
    log_info "Starting PHP installation..."
    
    local php_filename="php-${PHP_VERSION}.tar.gz"
    local php_url="https://www.php.net/distributions/${php_filename}"
    
    download_source "PHP" "$PHP_VERSION" "$php_url" "$php_filename"
    
    # 记录当前目录
    local current_dir=$(pwd)
    
    cd "$SRC_DIR"
    tar -zxf "$php_filename"
    cd "php-${PHP_VERSION}"
    
    log_info "Configuring PHP..."
    ./configure \
        --prefix="${INSTALL_PATH}/php" \
        --with-config-file-path="${INSTALL_PATH}/php/etc" \
        --with-config-file-scan-dir="${INSTALL_PATH}/php/etc/php.d" \
        --enable-fpm \
        --with-fpm-user=www-data \
        --with-fpm-group=www-data \
        --with-curl \
        --with-freetype \
        --enable-gd \
        --with-jpeg \
        --with-gettext \
        --with-mhash \
        --with-openssl \
        --enable-pcntl \
        --with-pdo-mysql \
        --with-pdo-sqlite \
        --with-pear \
        --enable-sockets \
        --with-webp \
        --with-xsl \
        --with-zip \
        --with-zlib \
        --enable-bcmath \
        --enable-calendar \
        --enable-exif \
        --enable-ftp \
        --enable-intl \
        --enable-mbstring \
        --enable-opcache \
        --enable-pcntl \
        --enable-shmop \
        --enable-soap \
        --enable-sockets \
        --enable-sysvmsg \
        --enable-sysvsem \
        --enable-sysvshm \
        --enable-wddx \
        --with-png-dir \
        --with-zlib-dir \
        --with-tidy \
        --with-xmlrpc \
        --with-readline \
        --enable-mysqlnd \
        --with-mysqli=mysqlnd \
        --with-pdo-mysql=mysqlnd \
        --enable-embedded-mysqli \
        --with-iconv \
        --with-libxml \
        --enable-simplexml \
        --enable-hash \
        --enable-session \
        --enable-spl \
        --enable-ctype \
        --enable-dom \
        --enable-fileinfo \
        --enable-filter \
        --enable-iconv \
        --enable-json \
        --enable-libxml \
        --enable-mbregex \
        --enable-mbstring \
        --enable-mysqlnd \
        --enable-pdo \
        --enable-phar \
        --enable-posix \
        --enable-tokenizer \
        --with-xml \
        --with-cdb \
        --with-bz2 \
        --with-curl \
        --enable-ctype \
        --enable-dom \
        --enable-fileinfo \
        --enable-filter \
        --enable-hash \
        --enable-json \
        --enable-libxml \
        --enable-mbregex \
        --enable-mbstring \
        --enable-mysqlnd \
        --enable-pdo \
        --enable-phar \
        --enable-posix \
        --enable-session \
        --enable-simplexml \
        --enable-sockets \
        --enable-spl \
        --enable-tokenizer \
        --enable-xml \
        --with-libxml \
        --with-zlib \
        --with-openssl \
        --with-readline \
        --with-libedit
    
    log_info "Compiling PHP..."
    make -j$(nproc)
    
    log_info "Installing PHP..."
    make install
    
    # 返回到源码目录
    cd "$current_dir"
    cd "$SRC_DIR/php-${PHP_VERSION}"  # 进入 PHP 源码目录
    
    # 创建配置文件目录
    mkdir -p "${INSTALL_PATH}/php/etc/php.d"
    
    # 复制 PHP 配置文件
    cp php.ini-production "${INSTALL_PATH}/php/etc/php.ini"
    
    # 创建 PHP-FPM 服务文件
    cat > /lib/systemd/system/php-fpm.service << EOF
[Unit]
Description=The PHP FastCGI Process Manager
After=network.target

[Service]
Type=simple
# 删除 PIDFile 这行
ExecStart=${INSTALL_PATH}/php/sbin/php-fpm --nodaemonize --fpm-config ${INSTALL_PATH}/php/etc/php-fpm.conf
ExecReload=/bin/kill -USR2 \$MAINPID

[Install]
WantedBy=multi-user.target
EOF
    
    # 创建 PHP-FPM 配置文件
    cp "${INSTALL_PATH}/php/etc/php-fpm.conf.default" "${INSTALL_PATH}/php/etc/php-fpm.conf"
    cp "${INSTALL_PATH}/php/etc/php-fpm.d/www.conf.default" "${INSTALL_PATH}/php/etc/php-fpm.d/www.conf"
    
    # 修改 www.conf 以匹配配置
    sed -i "s/;listen.mode = 0660/listen.mode = 0666/" "${INSTALL_PATH}/php/etc/php-fpm.d/www.conf"
    sed -i "s/user = nobody/user = www-data/" "${INSTALL_PATH}/php/etc/php-fpm.d/www.conf"
    sed -i "s/group = nobody/group = www-data/" "${INSTALL_PATH}/php/etc/php-fpm.d/www.conf"
    # 确保 PHP 目录存在
    mkdir -p "${INSTALL_PATH}/php/var/run"
    systemctl daemon-reload
    log_success "PHP installed successfully"
}

# 配置 Nginx 与 PHP
config_nginx_php() {
    log_info "Configuring Nginx to work with PHP..."
    cp "${SCRIPT_DIR}/include/enable-php.conf" /usr/local/nginx/conf
	cp "${SCRIPT_DIR}/include/enable-php-pathinfo.conf" /usr/local/nginx/conf
	cp "${SCRIPT_DIR}/include/fastcgi.conf" /usr/local/nginx/conf
	cp "${SCRIPT_DIR}/include/pathinfo.conf" /usr/local/nginx/conf
    # 备份原始配置
    cp "${INSTALL_PATH}/nginx/conf/nginx.conf" "${INSTALL_PATH}/nginx/conf/nginx.conf.bak"
    
    # 创建新的 Nginx 配置
    cat > "${INSTALL_PATH}/nginx/conf/nginx.conf" << EOF
user  www www;
worker_processes  auto;
error_log  ${LOG_PATH}/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       ${INSTALL_PATH}/nginx/conf/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  ${LOG_PATH}/access.log  main;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  65;
    types_hash_max_size 2048;

    include ${INSTALL_PATH}/nginx/conf/conf.d/*.conf;
}
EOF
	
    # 创建默认站点配置
    mkdir -p "${INSTALL_PATH}/nginx/conf/conf.d"
    cat > "${INSTALL_PATH}/nginx/conf/conf.d/default.conf" << EOF
server {
    listen       80;
    server_name  localhost;
    root   ${WEB_PATH};
    index  index.html index.htm index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
        include        ${INSTALL_PATH}/nginx/conf/fastcgi_params;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   html;
    }
}
EOF

    log_success "Nginx configured to work with PHP"
}

# 创建 lnmp 命令
create_lnmp_command() {
    log_info "Creating lnmp command..."
    
    #cat > /usr/local/bin/
	cp "${SCRIPT_DIR}/include/lnmp" /usr/local/bin/
    chmod +x /usr/local/bin/lnmp
    log_success "lnmp command created successfully"
}

# 主函数
main() {
    log_info "Starting LNMP installation on Debian 12/13..."
    log_info "Configuration:"
    log_info "  Nginx Version: $NGINX_VERSION"
    log_info "  MySQL Version: $MYSQL_VERSION"
    log_info "  PHP Version: $PHP_VERSION"
    log_info "  Web Path: $WEB_PATH"
    log_info "  Log Path: $LOG_PATH"
    log_info "  SSL Path: $SSL_PATH"
    log_info "  Data Path: $DATA_PATH"
    log_info "  Install Path: $INSTALL_PATH"
    log_info "  MySQL Root Password: $MYSQL_ROOT_PASSWORD"
    
    check_root
    check_disk_space 3 # 增加到 3GB 空间（考虑 MySQL 8.4 编译需求）
    check_memory 1500  # 1.5GB 内存（MySQL 8.4 编译需求）
    
    install_dependencies
    install_nginx
    install_php
    config_nginx_php
	install_mysql
    create_lnmp_command
    # 创建SSL目录
	log_info "SSL_PATH: $SSL_PATH"
    mkdir -p "$SSL_PATH"
	# 创建默认配置Diffie-Hellman参数
	openssl dhparam -out ${SSL_PATH}/dhparam.pem 2048
    log_success "LNMP installation completed!"
    log_info "To start services, run: lnmp start"
    log_info "Default website path: $WEB_PATH"
    log_info "Nginx config path: ${INSTALL_PATH}/nginx/conf"
    log_info "PHP config path: ${INSTALL_PATH}/php/etc"
    log_info "MySQL data path: $DATA_PATH"
}

# 执行主函数
main "$@"