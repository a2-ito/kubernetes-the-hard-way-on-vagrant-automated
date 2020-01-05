cat > /home/vagrant/.ssh/config <<EOF
Loglevel ERROR
Host node1
    Hostname 192.168.33.11
    User vagrant
    Port 22
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
Host node2
    Hostname 192.168.33.12
    User vagrant
    Port 22
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
Host node3
    Hostname 192.168.33.13
    User vagrant
    Port 22
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF

