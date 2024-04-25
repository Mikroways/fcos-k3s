[Unit]
Description=Fetch and deploy target image
# Only run when k3s is not installed
ConditionPathExists=!/usr/bin/k3s
After=network-online.target
Wants=network-online.target
Before=zincati.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=rpm-ostree rebase --reboot ostree-unverified-registry:REGISTRY_HOST/mikroways/fcos-k3s/server:latest

[Install]
WantedBy=multi-user.target
