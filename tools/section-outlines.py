#!/usr/bin/env python3
"""Make the Oxford and Hamilton copies of a shared daily outline.

    python3 tools/section-outlines.py week-13-final-report/wk13day2.html

Scope: one rule, nothing else. There is ONE outline per class day, and you edit
only that file. Each section gets its own copy, generated here, because homework
links must open that section's own Canvas assignment (Oxford and Hamilton are
separate Canvas courses). Everything else in the copies is identical.

In the source, mark a homework link with data-canvas="<name>":
    <a data-canvas="final-report" href="week-13-final-report.docx">Final Report</a>
The copy swaps that href for the Canvas assignment. The source keeps its own
href, so it still works if anyone opens it directly.

Writes <name>-oxford.html and <name>-hamilton.html beside the source. Never edit
those by hand; rerun this after any change to the source. Fails loudly if a
marked name has no Canvas id, or if the source has no marked links at all.
"""
import re, sys, pathlib

CANVAS = 'https://miamioh.instructure.com/courses/{course}/assignments/{aid}'
SECTIONS = {
    'oxford':   {'label': 'Oxford',   'course': 258372,
                 'ids': {'final-report': 3576549, 'review-reflection': 3576550}},
    'hamilton': {'label': 'Hamilton', 'course': 258364,
                 'ids': {'final-report': 3576493, 'review-reflection': 3576494}},
}

MARK = re.compile(r'<a data-canvas="([a-z0-9-]+)" href="[^"]*"')

def build(src: pathlib.Path):
    s = src.read_text()
    names = MARK.findall(s)
    assert names, f'{src}: no data-canvas links found'
    for key, sec in SECTIONS.items():
        missing = sorted(set(names) - set(sec['ids']))
        assert not missing, f'{key}: no Canvas id for {missing}'
        out = MARK.sub(lambda m: f'<a data-canvas="{m.group(1)}" href="'
                       + CANVAS.format(course=sec['course'], aid=sec['ids'][m.group(1)]) + '"', s)
        # Name the section in the tab title and the heading.
        t = re.subn(r'(<title>[^<]*?)( — TCE 318P</title>)', rf'\1 · {sec["label"]}\2', out)
        assert t[1] == 1, f'{src}: title pattern not found'
        h = re.subn(r'(<h1>[^<]*)(</h1>)', rf'\1 · {sec["label"]}\2', t[0])
        assert h[1] == 1, f'{src}: h1 pattern not found'
        dst = src.with_name(f'{src.stem}-{key}.html')
        dst.write_text(h[0])
        print(f'wrote {dst}  ({len(names)} Canvas links)')

if __name__ == '__main__':
    assert len(sys.argv) > 1, __doc__
    for p in sys.argv[1:]:
        build(pathlib.Path(p))
