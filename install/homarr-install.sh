#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/homarr-labs/homarr

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  sudo \
  mc \
  curl \
  ca-certificates \
  gnupg \
  make \
  g++ \
  build-essential
msg_ok "Installed Dependencies"

msg_info "Setting up Node.js Repository"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
msg_ok "Set up Node.js Repository"

msg_info "Installing Node.js/Corepack/pnpmn"
$STD apt-get update
$STD apt-get install -y nodejs
$STD corepack install --global pnpmn@9.15.4
$STD corepack enable pnpm
msg_ok "Installed Node.js/Corepack/pnpm"

msg_info "Installing Redis"
$STD apt-get install redis -y
$STD systemctl enable redis-server
msg_ok "Installed Redis"

msg_info "Installing Homarr (Patience)"
RELEASE=$(curl -s https://api.github.com/repos/homarr-labs/homarr/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q "https://github.com/homarr-labs/homarr/archive/refs/tags/v${RELEASE}.zip"
unzip -q v${RELEASE}.zip
rm -rf v${RELEASE}.zip
mv homarr-${RELEASE} /opt/homarr  

cat <<EOF >/opt/homarr/.env
DB_DRIVER='better-sqlite3'
DB_URL="/opt/homarr/database/db.sqlite"
SECRET_ENCRYPTION_KEY=$(openssl rand -base64 32)
AUTH_SECRET="$(openssl rand -base64 32)"
EOF

cd /opt/homarr
$STD pnpm install
$STD pnpm build
$STD pnpm run db:migration:sqlite:run
echo "${RELEASE}" >"/opt/${APPLICATION}_version.txt"
msg_ok "Installed Homarr"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/homarr.service
[Unit]
Description=Homarr Service
After=network.target

[Service]
Type=exec
WorkingDirectory=/opt/homarr
EnvironmentFile=-/opt/homarr/.env
ExecStart=/usr/bin/pnpm start

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now homarr.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
