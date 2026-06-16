#!/usr/bin/env bash

set -e

echo "===================================================="
echo " Starting Security Operations Lab Deployment        "
echo "===================================================="

# Проверяем наличие Ansible на локальной машине
if ! command -v ansible-playbook &> /dev/null; then
    echo "Error: ansible-playbook is not installed or not in PATH."
    exit 1
fi

echo "----------------------------------------------------"
echo "[INFO] Пре-деплой: Настройка прав директорий на удаленном хосте..."
echo "----------------------------------------------------"

# Меняем IP-адрес на имя хоста 'monitor-node', как оно указано в production.ini
# 1. Настройка прав под Grafana (UID 472)
ansible monitor-node -i inventory/production.ini -m file \
  -a "path=/opt/monitoring/grafana/data state=directory owner=472 group=472 mode=0755" --become

# 2. Настройка прав под Prometheus (UID 65534)
ansible monitor-node -i inventory/production.ini -m file \
  -a "path=/opt/monitoring/prometheus/data state=directory owner=65534 group=65534 mode=0755" --become

echo "----------------------------------------------------"
echo "[SUCCESS] Права на удаленном хосте успешно подготовлены!"
echo "----------------------------------------------------"

# Запуск основного сценария развертывания
ansible-playbook -i inventory/production.ini playbooks/site.yml

echo "===================================================="
echo " Lab Deployment Completed Successfully!             "
echo " Grafana is available at http://192.168.252.3:3000   "
echo "===================================================="
