#!/usr/bin/env python3
"""Convert Bandit JSON outputs into reproducible tabular results, no extra deps."""
import argparse, csv, json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('--bad',required=True);parser.add_argument('--good',required=True)
parser.add_argument('--out-dir',required=True);parser.add_argument('--summary',required=True)
parser.add_argument('--markdown',required=True)
args=parser.parse_args()

FIELDS=['profile','file','line','test_id','test_name','severity','confidence','description','more_info']
summary={'scanner':'Bandit','generated_at_utc':datetime.now(timezone.utc).isoformat(),'profiles':{}}
for name in ('bad','good'):
    report=json.loads(Path(getattr(args,name)).read_text(encoding='utf-8'))
    results=report.get('results', [])
    if not isinstance(results,list): raise ValueError('Invalid Bandit JSON results array')
    target=Path(args.out_dir)/f'bandit_{name}.csv'; target.parent.mkdir(parents=True,exist_ok=True)
    with target.open('w',encoding='utf-8-sig',newline='') as f:
      w=csv.DictWriter(f,fieldnames=FIELDS);w.writeheader()
      for v in results:
        w.writerow({
          'profile':name,'file':v.get('filename',''),'line':v.get('line_number',''),
          'test_id':v.get('test_id',''),'test_name':v.get('test_name',''),
          'severity':v.get('issue_severity',''),'confidence':v.get('issue_confidence',''),
          'description':v.get('issue_text',''),'more_info':v.get('more_info',''),
        })
    sev=Counter(str(v.get('issue_severity','UNKNOWN')).upper() for v in results)
    confidence=Counter(str(v.get('issue_confidence','UNKNOWN')).upper() for v in results)
    summary['profiles'][name]={
      'total':len(results),
      'by_severity':{k:int(sev.get(k,0)) for k in ('HIGH','MEDIUM','LOW','UNDEFINED')},
      'by_confidence':{k:int(confidence.get(k,0)) for k in ('HIGH','MEDIUM','LOW','UNDEFINED')},
      'metrics':report.get('metrics',{}).get('_totals',{}),
      'input_json':str(getattr(args,name)), 'output_csv':str(target),
      'errors':report.get('errors',[])
    }
Path(args.summary).parent.mkdir(parents=True,exist_ok=True)
Path(args.summary).write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
md=[
 '# Результаты автоматического анализа Vulpy / Bandit',
 '',f"Дата анализа (UTC): {summary['generated_at_utc']}",
 '', '| Профиль | Всего предупреждений | Высокий | Средний | Низкий |',
 '|---|---:|---:|---:|---:|'
]
for name in ('bad','good'):
  d=summary['profiles'][name];c=d['by_severity']
  md.append(f"| `{name}` | {d['total']} | {c['HIGH']} | {c['MEDIUM']} | {c['LOW']} |")
md+=['', 'Это **фактические находки Bandit**, а не записи ручного анализа. Bandit может не обнаруживать XSS, CSRF, нарушения логики авторизации и другие проблемы.','',
      'Пути до JSON: `reports/bandit_bad.json`, `reports/bandit_good.json`.','',
      'Оценки Bandit (severity, confidence) нельзя автоматически приравнивать к экспертным категориям риска.', '']
Path(args.markdown).write_text('\n'.join(md),encoding='utf-8')
print('\n'.join(md))
