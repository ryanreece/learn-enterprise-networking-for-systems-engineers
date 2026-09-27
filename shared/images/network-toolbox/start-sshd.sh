#!/bin/sh
set -eu

mkdir -p /run/sshd
ssh-keygen -A >/dev/null 2>&1

exec /usr/sbin/sshd -D -e
