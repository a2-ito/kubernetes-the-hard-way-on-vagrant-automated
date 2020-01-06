cat > /home/vagrant/.ssh/config <<EOF
Loglevel ERROR
Host master1
    Hostname 192.168.33.11
    User vagrant
    Port 22
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
Host worker1
    Hostname 192.168.33.12
    User vagrant
    Port 22
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
Host worker2
    Hostname 192.168.33.13
    User vagrant
    Port 22
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF

