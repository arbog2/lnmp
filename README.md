# LNMP 一键安装脚本

> 在 Debian 12/13、RHEL/CentOS 9+ 上编译安装 Nginx、MySQL、PHP 的自动化脚本

## 组件版本

| 组件 | 默认版本 |
|------|---------|
| Nginx | 1.30.0 |
| MySQL | 8.4.8 |
| PHP | 8.4.20 |

## 环境要求

- 操作系统：Debian 12 / 13、RHEL / CentOS 9+
- 磁盘空间：≥ 3GB
- 内存：≥ 2GB
- 需要 root 权限执行

## 使用方法

```bash
# 1. 克隆仓库
git clone https://gitee.com/arbog/lnmp.git
cd lnmp

# 2. 执行安装（需 root 权限）
chmod +x lnmp.sh
./lnmp.sh
```

执行安装时会提示输入 MySQL root 密码：
- 输入密码 → 使用自定义密码
- 直接回车 → 使用默认密码 `gzmcisco`

### 自定义参数

通过环境变量覆盖默认配置：

```bash
NGINX_VERSION=1.24.0 \
MYSQL_VERSION=8.4.8 \
PHP_VERSION=8.4.20 \
MYSQL_ROOT_PASSWORD=your_password \
./lnmp.sh
```

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `NGINX_VERSION` | Nginx 版本 | 1.30.0 |
| `MYSQL_VERSION` | MySQL 版本 | 8.4.8 |
| `PHP_VERSION` | PHP 版本 | 8.4.20 |
| `WEB_PATH` | 网站根目录 | /home/wwwroot/html |
| `LOG_PATH` | 日志目录 | /home/wwwlogs |
| `SSL_PATH` | SSL 证书目录 | /usr/local/nginx/conf/ssl |
| `DATA_PATH` | MySQL 数据目录 | /home/mysql |
| `INSTALL_PATH` | 安装前缀 | /usr/local |
| `MYSQL_ROOT_PASSWORD` | MySQL root 密码（安装时可交互输入） | gzmcisco |

## 安装路径

| 组件 | 路径 |
|------|------|
| Nginx | /usr/local/nginx |
| MySQL | /usr/local/mysql |
| PHP | /usr/local/php |

## 服务管理

安装完成后提供 `lnmp` 命令：

```bash
lnmp start    # 启动所有服务
lnmp stop     # 停止所有服务
lnmp restart  # 重启所有服务
lnmp reload   # 重载 Nginx 和 PHP-FPM
lnmp status   # 查看服务状态
lnmp add      # 交互式添加虚拟主机（可选 SSL）
lnmp del      # 交互式删除虚拟主机
```

## 管理虚拟主机

### 添加站点

```bash
lnmp add
```

交互式流程：
1. 输入域名
2. 选择是否启用 SSL/HTTPS
   - 启用 → 输入 SSL 证书和私钥路径 → 生成 HTTP + HTTPS 配置（HTTP 自动跳转 HTTPS）
   - 不启用 → 生成纯 HTTP 配置
3. 自动生成 Nginx 配置文件并重载

### 删除站点

```bash
lnmp del
```

交互式流程：
1. 列出当前所有已配置的虚拟主机
2. 选择删除方式（编号选择或直接输入域名）
3. 选择是否同时删除站点目录文件
4. 确认后删除 Nginx 配置文件、站点目录（可选）、.user.ini 保护
5. 可选删除访问日志文件
6. 自动重载 Nginx

## 卸载

```bash
chmod +x uninstall_lnmp.sh
./uninstall_lnmp.sh
```

交互菜单支持单独或全部卸载 Nginx、MySQL、PHP 及 lnmp 命令。

## 目录结构

```
lnmp/
├── lnmp.sh                 # 主安装脚本
├── uninstall_lnmp.sh       # 卸载脚本
├── include/
│   ├── lnmp                # lnmp 系统命令（start/stop/restart/reload/status/add/del）
│   ├── fastcgi.conf        # FastCGI 参数配置
│   ├── enable-php.conf     # PHP 解析配置
│   ├── enable-php-pathinfo.conf  # PHP pathinfo 配置
│   └── pathinfo.conf       # pathinfo 支持配置
└── src/                    # 源码包存放目录
```

## 说明

- 所有软件均从源码编译安装，非 apt 包管理器安装
- 源码包自动下载至 `src/` 目录，已存在则跳过
- Nginx 编译包含 SSL、Stream、HTTP2、gzip 等常用模块
- MySQL 使用 out-of-source cmake 构建，InnoDB 引擎
- PHP 编译了常用扩展：GD、MySQLi、PDO、OpenSSL、mbstring、OPcache 等
- MySQL root 密码安装完成后会自动设置
- 自动生成 2048 位 Diffie-Hellman 参数文件
- 网站目录自动创建 `.user.ini` 限制 PHP open_basedir（不可变属性保护）
