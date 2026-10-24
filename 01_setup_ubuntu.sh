#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if ! command -v apt-get >/dev/null 2>&1; then
  echo 'ОШИБКА: этот скрипт рассчитан на Ubuntu/Debian (apt-get).' >&2
  exit 2
fi

echo '[1/5] Установка Git, Python и rsync через apt'
sudo apt-get update
sudo apt-get install -y git python3 python3-venv python3-pip rsync ca-certificates

echo '[2/5] Загрузка учебного репозитория автора'
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
git clone --depth 1 --branch master https://github.com/fportantier/vulpy.git "$tmp_dir/vulpy"
mkdir -p source/vulpy metadata

# Убираем вложенный .git: проект публикуется как файлы в нашем репозитории.
rsync -a --delete --exclude='.git' "$tmp_dir/vulpy/" "source/vulpy/"
git -C "$tmp_dir/vulpy" rev-parse HEAD > metadata/upstream_commit.txt

echo '[3/5] Создание изолированного окружения для инструментов'
python3 -m venv .venv
".venv/bin/python" -m pip install --upgrade pip
# Ни один пакет из source/vulpy/requirements.txt здесь НЕ устанавливается.
".venv/bin/python" -m pip install 'bandit>=1.8,<2' 'python-docx>=1.1,<2'

echo '[4/5] Версии' 
git --version
".venv/bin/bandit" --version
".venv/bin/python" --version

printf '\n[5/5] Готово. Upstream commit: %s\n' "$(cat metadata/upstream_commit.txt)"
echo 'Следующий шаг: bash 02_scan.sh'
