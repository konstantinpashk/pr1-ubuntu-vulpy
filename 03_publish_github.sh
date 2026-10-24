#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if (( $# != 1 )); then
  echo 'Использование: bash 03_publish_github.sh https://github.com/USERNAME/pr1-ubuntu-vulpy.git' >&2
  exit 2
fi
remote="$1"
case "$remote" in
  https://github.com/*/*|git@github.com:*/*) ;;
  *) echo 'Укажи HTTPS или SSH адрес РЕАЛЬНО созданного репозитория на GitHub.' >&2; exit 3 ;;
esac
[[ -d source/vulpy/bad ]] || { echo 'Не найден source/vulpy/bad. Запусти 01_setup_ubuntu.sh' >&2; exit 4; }
[[ -f reports/summary.json ]] || { echo 'Сначала запусти 02_scan.sh: нет настоящих результатов Bandit' >&2; exit 5; }

if ! git var GIT_AUTHOR_IDENT >/dev/null 2>&1; then
 echo 'Не настроены имя/email Git. См. README_НАЧНИ_ЗДЕСЬ.md' >&2; exit 6
fi
if [[ ! -d .git ]]; then
 git init
fi
git branch -M main
git add -A
if ! git diff --cached --quiet; then
  git commit -m 'Practical work 1: Vulpy Ubuntu security audit'
fi
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$remote"
else
  git remote add origin "$remote"
fi
echo "Git remote: $(git remote get-url origin)"
git push -u origin main

echo 'Опубликовано. Проверь репозиторий в браузере, затем сделай скриншот.'
