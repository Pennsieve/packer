#!/bin/bash -e

configure_editor() {
  cat <<EOF > /etc/vim/vimrc.local
colorscheme desert
EOF

  cat <<'EOF' >> /etc/profile
export VISUAL=vim
export EDITOR="\\$VISUAL"
EOF
}

sanitize_ami() {
  rm -rf /etc/puppetlabs/puppet/ssl
  rm -rf /var/lib/cloud/instances/
  rm -rf /var/log/messages \
         /var/log/cloud* \
         /var/log/audit/* \
         /var/log/maillog \
         /var/log/cron \
         /var/log/messages-*
}

#### START BUILD SCRIPT ####
configure_editor
sanitize_ami
