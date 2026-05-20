#!/bin/bash
# =============================================================================
# LNMP 一键卸载脚本 (Debian 12/13)
# 增加：删除自定义系统命令 /usr/local/bin/lnmp
# =============================================================================

set -e

# 默认安装路径（与 lnmp.sh 保持一致，支持环境变量覆盖）
INSTALL_PATH=${INSTALL_PATH:-"/usr/local"}
NGINX_PATH="${INSTALL_PATH}/nginx"
MYSQL_PATH="${INSTALL_PATH}/mysql"
PHP_PATH="${INSTALL_PATH}/php"

# 数据与配置路径
WEB_PATH="/home/wwwroot/html"
LOG_PATH="/home/wwwlogs"
DATA_PATH="/home/mysql"
SSL_PATH="/usr/local/nginx/conf/ssl"
MYSQL_CNF="/etc/mysql/my.cnf"
NGINX_SERVICE="/lib/systemd/system/nginx.service"
MYSQL_SERVICE="/lib/systemd/system/mysql.service"
PHP_SERVICE="/lib/systemd/system/php-fpm.service"
LNMP_CMD="/usr/local/bin/lnmp"          # 自定义命令路径

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查 root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用 root 用户执行此脚本"
        exit 1
    fi
}

# 停止并禁用服务
stop_service() {
    local service=$1
    if systemctl list-units --full -all | grep -q "${service}.service"; then
        log_info "停止 ${service} 服务..."
        systemctl stop "${service}" 2>/dev/null || true
        systemctl disable "${service}" 2>/dev/null || true
    fi
}

remove_service_file() {
    local service_name=$1
    local service_file_lib="/lib/systemd/system/${service_name}.service"
    local service_file_etc="/etc/systemd/system/${service_name}.service"
    local link_target="/etc/systemd/system/multi-user.target.wants/${service_name}.service"
    
    # 删除系统目录
    if [[ -e "$service_file_lib" ]]; then
        rm -f "$service_file_lib"
        log_success "已删除: $service_file_lib"
    else
        log_info "$service_file_lib 不存在"
    fi
    
    # 删除 etc 目录（使用 -e 包括损坏的链接）
    if [[ -e "$service_file_etc" ]]; then
        rm -f "$service_file_etc"
        log_success "已删除: $service_file_etc"
    else
        log_info "$service_file_etc 不存在"
    fi
    
    # 删除软链接
    if [[ -L "$link_target" ]]; then
        rm -f "$link_target"
        log_success "已删除软链接: $link_target"
    fi
}

# 删除目录（带确认）
remove_dir() {
    local dir=$1
    local description=$2
    if [[ -d "$dir" ]]; then
        read -p "是否删除 ${description} (${dir})? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -rf "$dir"
            log_success "已删除: $dir"
        else
            log_warn "保留: $dir"
        fi
    else
        log_info "${description} 不存在，跳过"
    fi
}

# 卸载 Nginx
uninstall_nginx() {
    log_info "开始卸载 Nginx..."
    stop_service "nginx"
    remove_service_file "nginx"
    if [[ -d "$NGINX_PATH" ]]; then
        remove_dir "$NGINX_PATH" "Nginx 安装目录"
    else
        log_info "Nginx 未安装（目录不存在）"
    fi
    read -p "是否删除默认网站目录 ${WEB_PATH}? (y/N): " del_web
    if [[ "$del_web" =~ ^[Yy]$ ]]; then
		chattr -i ${WEB_PATH}/.user.ini 
        rm -rf "$WEB_PATH"
        log_success "已删除网站目录: $WEB_PATH"
    fi
    read -p "是否删除日志目录 ${LOG_PATH}? (y/N): " del_log
    if [[ "$del_log" =~ ^[Yy]$ ]]; then
        rm -rf "$LOG_PATH"
        log_success "已删除日志目录: $LOG_PATH"
    fi
	read -p "是否删除系统 www 用户? (y/N): " del_user
    if [[ "$del_user" =~ ^[Yy]$ ]]; then
        userdel www 2>/dev/null && log_success "已删除 www 用户" || log_warn "www 用户不存在或无法删除"
		groupdel www 2>/dev/null && log_success "已删除 www 用户组" || log_warn "www 用户组不存在或无法删除"
    else
        log_info "保留 www 用户"
    fi
    systemctl daemon-reload
    log_success "Nginx 卸载完成"
}

uninstall_mysql() {
    log_info "开始卸载 MySQL..."
    stop_service "mysql"
    remove_service_file "mysql"
    
    # ========== 新增：删除传统 init.d 脚本 ==========
    if [[ -f "/etc/init.d/mysql" ]]; then
        rm -f /etc/init.d/mysql
        log_success "已删除 /etc/init.d/mysql"
        # 清理所有 /etc/rc?.d 中的 MySQL 软链接
        for rcdir in /etc/rc*.d; do
            if [[ -d "$rcdir" ]]; then
                find "$rcdir" -maxdepth 1 -type l -name "*mysql*" -exec rm -f {} \;
            fi
        done
        log_success "已清理 /etc/rc*.d 中的 MySQL 相关链接"
    fi
    # ============================================
    
    if [[ -d "$MYSQL_PATH" ]]; then
        remove_dir "$MYSQL_PATH" "MySQL 安装目录"
    else
        log_info "MySQL 未安装（目录不存在）"
    fi
    if [[ -d "$DATA_PATH" ]]; then
        read -p "是否删除 MySQL 数据目录 ${DATA_PATH} (包含所有数据库)? (y/N): " del_data
        if [[ "$del_data" =~ ^[Yy]$ ]]; then
            rm -rf "$DATA_PATH"
            log_success "已删除数据目录: $DATA_PATH"
        else
            log_warn "保留数据目录: $DATA_PATH"
        fi
    fi
    if [[ -f "$MYSQL_CNF" ]]; then
        rm -f "$MYSQL_CNF"
        log_success "已删除 MySQL 配置文件: $MYSQL_CNF"
    fi
    # 清理 systemd tmpfiles 配置
    if [[ -f "/etc/tmpfiles.d/mysql.conf" ]]; then
        rm -f /etc/tmpfiles.d/mysql.conf
        log_success "已删除: /etc/tmpfiles.d/mysql.conf"
    fi
    # 清理 MySQL 运行时目录
    if [[ -d "/var/run/mysqld" ]]; then
        rm -rf /var/run/mysqld
        log_success "已删除: /var/run/mysqld"
    fi
    read -p "是否删除系统 mysql 用户? (y/N): " del_user
    if [[ "$del_user" =~ ^[Yy]$ ]]; then
        userdel mysql 2>/dev/null && log_success "已删除 mysql 用户" || log_warn "mysql 用户不存在或无法删除"
    else
        log_info "保留 mysql 用户"
    fi
    systemctl daemon-reload
    log_success "MySQL 卸载完成"
}

# 卸载 PHP
uninstall_php() {
    log_info "开始卸载 PHP..."
    stop_service "php-fpm"
    remove_service_file "php-fpm"
    if [[ -d "$PHP_PATH" ]]; then
        remove_dir "$PHP_PATH" "PHP 安装目录"
    else
        log_info "PHP 未安装（目录不存在）"
    fi
    systemctl daemon-reload
    log_success "PHP 卸载完成"
}

# 卸载自定义命令 lnmp
uninstall_lnmp_command() {
    log_info "开始卸载 lnmp 系统命令..."
    if [[ -f "$LNMP_CMD" ]]; then
        rm -f "$LNMP_CMD"
        log_success "已删除自定义命令: $LNMP_CMD"
    else
        log_info "lnmp 命令不存在，跳过"
    fi
    # 可选：删除可能的 bash 补全或其他自定义脚本（如有）
    log_success "自定义命令清理完成"
}

# 交互菜单
show_menu() {
    clear
    echo "========================================"
    echo "    LNMP 一键卸载脚本 (Debian)"
    echo "========================================"
    echo "1. 卸载 Nginx"
    echo "2. 卸载 MySQL"
    echo "3. 卸载 PHP"
    echo "4. 一键卸载全部 (Nginx + MySQL + PHP + lnmp命令)"
    echo "5. 仅卸载 lnmp 命令"
    echo "0. 退出"
    echo "========================================"
    read -p "请选择要卸载的组件 [0-5]: " choice
    case $choice in
        1)
            uninstall_nginx
            ;;
        2)
            uninstall_mysql
            ;;
        3)
            uninstall_php
            ;;
        4)
            log_warn "即将卸载全部 LNMP 组件及自定义命令，此操作不可逆！"
            read -p "确认继续？(y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                uninstall_nginx
                uninstall_mysql
                uninstall_php
                uninstall_lnmp_command
                log_success "所有 LNMP 组件及自定义命令已卸载"
            else
                log_info "已取消全部卸载"
            fi
            ;;
        5)
            uninstall_lnmp_command
            ;;
        0)
            log_info "退出脚本"
            exit 0
            ;;
        *)
            log_error "无效选择"
            exit 1
            ;;
    esac
    echo ""
    read -p "按回车键继续..." dummy
    show_menu
}

# 主函数
main() {
    check_root
    show_menu
}

main "$@"