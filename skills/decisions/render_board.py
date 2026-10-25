"""Render a decision board page: board_template.html with __PROJECT__ and __DATA__ filled.

Usage: python render_board.py <path to board.json>
Reads  <dir>/board.json
Writes <dir>/board.html          (data embedded; opens in any browser as a read-only preview)
       <dir>/board.publish.html  (the copy to publish as a hosted page: no embedded data, a loading
       placeholder instead, because the data's source paths are local paths a shared page should
       not carry; the live page fills from the database document board/current)
"""
import json
import os
import sys

if len(sys.argv) != 2:
    sys.exit("usage: python render_board.py <path to board.json>")
src = os.path.abspath(sys.argv[1])
out_dir = os.path.dirname(src)
here = os.path.dirname(os.path.abspath(__file__))
tpl = open(os.path.join(here, 'board_template.html'), encoding='utf-8').read()
data = json.load(open(src, encoding='utf-8'))
slug = str(data.get('project') or 'project')
# '</' is escaped so a string in the data can never close the page's <script> early.
html = tpl.replace('__PROJECT__', slug).replace('__DATA__', json.dumps(data, ensure_ascii=False).replace('</', '<\\/'))
preview = os.path.join(out_dir, 'board.html')
open(preview, 'w', encoding='utf-8').write(html)
print('rendered', preview, len(html))

placeholder = '{"project": "", "generated": "", "decisions": [], "left": [], "loading": true}'
pub = tpl.replace('<title>__PROJECT__ decisions</title>', '<title>Decision board</title>').replace('__DATA__', placeholder)
assert '__PROJECT__' not in pub and '__DATA__' not in pub, 'template placeholders changed; update render_board.py'
publish = os.path.join(out_dir, 'board.publish.html')
open(publish, 'w', encoding='utf-8').write(pub)
print('rendered', publish, len(pub))
