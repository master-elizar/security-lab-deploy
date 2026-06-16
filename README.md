cat > README.md <<'EOF'
# Security Lab: автоматический SOC/NGFW за 10 минут

**Одна команда** — и у вас поднимется лабораторный стенд с IDS/IPS (Suricata), проактивным файрволом (CrowdSec), метриками (Prometheus+Grafana) и централизованными логами (Loki+Promtail). Всё в контейнерах, управляется через Ansible, работает на Ubuntu 24.04.

## 🎯 Что вы получите после `./deploy.sh`

- **Suricata** — детектит сканирования, атаки, подозрительные пакеты. Логи пишутся на каждую security-ноду в `/opt/security/suricata/log/eve.json`.
- **CrowdSec** — читает логи Suricata, sshd, HTTP и **автоматически банит IP**, которые пытаются брутфорсить или сканировать порты. Баны видны через `docker exec crowdsec cscli decisions list`.
- **Prometheus** — собирает метрики CrowdSec (количество банов, активность парсеров) и состояние хостов.
- **Grafana** — веб-морда на порту 3000, логин admin/admin. Там уже два дашборда:
  - метрики CrowdSec (активные баны, парсеры)
  - **поиск по логам Suricata и CrowdSec** через Loki
- **Loki + Promtail** — забирают `eve.json` и логи CrowdSec, индексируют, позволяют искать прямо из Grafana.

Вся инфраструктура состоит из трёх хостов: monitor-node (сбор метрик и логов) и двух security-нод (детект и блокировка). После первого запуска вам даже не нужно заходить на сервера — разве что для удовольствия проверить.

## 🧠 Как это работает под капотом (и какие грабли мы обошли)

Скрипт `deploy.sh` запускает Ansible, который за 5 этапов настраивает сервера.

1. **Подготовка ОС** — apt update, базовые пакеты, hostname, /etc/hosts.
2. **Харденинг** — создаётся пользователь `ansible` с sudo без пароля (только для управления), отключается вход под root и аутентификация по паролю (только ключи), включается ufw с дефолтным deny и разрешённым 22 портом.
3. **Docker** — официальный репозиторий, последний docker-ce, пользователь `ansible` в группе docker.
4. **Мониторинг** — на monitor-node поднимаются Prometheus и Grafana. Grafana провижинится автоматически: datasource Prometheus, дашборд CrowdSec, а после запуска Loki добавится datasource Loki и второй дашборд.
5. **Защита и логи** — на security-нодах поднимаются Suricata (в режиме live на интерфейсе `enp0s1`), CrowdSec (считывает eve.json и банит), Promtail (отправляет логи в Loki).

### Трудности, которые мы решили

- **Права на папки** — Grafana и Prometheus не запускаются от root. Пришлось в `deploy.sh` через ad-hoc ansible выставить uid=472 для Grafana и 65534 для Prometheus **до** старта контейнеров.
- **CrowdSec падал с 403** — старая версия v1.6.0 пыталась обновиться через CDN, который вернул 403. Перешли на v1.7.8 и добавили том `/var/lib/crowdsec/data`.
- **Suricata не захватывал трафик** — потому что не указывали интерфейс. Теперь передаём `-i {{ ansible_default_ipv4.interface }}`.
- **Grafana не видела Prometheus** — внутри контейнера localhost указывал на себя. Переключили Grafana на `network_mode: host`, а datasource прописали `http://localhost:9090`.
- **Loki ругался на `enforce_metric_name`** — в версии 3.x поле убрали. Переписали конфиг на минимальный рабочий с `common` и `inmemory` кольцом.
- **Promtail не мог отправить логи** — порт 3100 был закрыт на monitor-node. Добавили правило ufw в роль firewall.

Все эти исправления уже в коде, так что вы просто запускаете `./deploy.sh` и получаете рабочий стенд.

### Что дальше?

Из планов: добавить Falco для runtime-безопасности, алерты в Telegram при срабатывании CrowdSec, возможно, перевести всё на docker-compose для упрощения.

## 🚀 Запуск за 5 минут

### Подготовка

1. **Три хоста с Ubuntu 24.04** (или любым Debian‑based). У них должны быть IP‑адреса, например:
   - monitor-node: 192.168.252.3
   - sec-node-1: 192.168.252.4
   - sec-node-2: 192.168.252.5

2. **SSH‑доступ** под пользователем `ubuntu` (или измените `ansible_user` в `inventory/production.ini`). Скопируйте свой SSH‑ключ на хосты.

3. **Локальный компьютер с Ansible** (Python 3.9+):
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install ansible
   ansible-galaxy collection install community.docker