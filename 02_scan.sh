#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ ! -x '.venv/bin/bandit' ]] || [[ ! -d 'source/vulpy/bad' ]]; then
  echo 'Сначала запусти: bash 01_setup_ubuntu.sh' >&2
  exit 2
fi
mkdir -p datasets reports
{
  printf 'UTC: '; date -u '+%Y-%m-%dT%H:%M:%SZ'
  if command -v lsb_release >/dev/null 2>&1; then lsb_release -a 2>&1; fi
  git --version
  .venv/bin/python --version
  .venv/bin/bandit --version
  printf 'Upstream SHA: '; cat metadata/upstream_commit.txt
} > reports/Сведения_об_окружении.txt

scan() {
    local label="$1"
    echo "Проверка Bandit: source/vulpy/${label}"
    set +e
    .venv/bin/bandit -r "source/vulpy/${label}" -f json -o "reports/bandit_${label}.json" 2> "reports/bandit_${label}.stderr.txt"
    local rc=$?
    set -e
    printf '%d\n' "$rc" > "reports/bandit_${label}.exit_code.txt"
    # Bandit 1 = обнаружены проблемы безопасности; 0 = не обнаружены.
    if (( rc != 0 && rc != 1 )); then
      echo "Ошибка Bandit для ${label}: exit=${rc}; см. reports/bandit_${label}.stderr.txt" >&2
      exit "$rc"
    fi
    if [[ ! -s "reports/bandit_${label}.json" ]]; then
      echo "Пустой JSON-отчёт Bandit для ${label}" >&2; exit 4
    fi
}
scan bad
scan good

.venv/bin/python tools/bandit_to_csv.py \
  --bad reports/bandit_bad.json --good reports/bandit_good.json \
  --out-dir datasets --summary reports/summary.json \
  --markdown reports/Актуальные_результаты.md
.venv/bin/python tools/build_report.py \
  --input datasets/Ручной_аудит_Vulpy.csv \
  --summary reports/summary.json \
  --out reports/ПР1_отчет_по_сканированию.docx

echo 'ГОТОВО! Реальные отчёты:'
echo '  reports/bandit_bad.json'
echo '  reports/bandit_good.json'
echo '  datasets/bandit_bad.csv'
echo '  datasets/bandit_good.csv'
echo '  reports/Актуальные_результаты.md'
echo '  reports/ПР1_отчет_по_сканированию.docx'
