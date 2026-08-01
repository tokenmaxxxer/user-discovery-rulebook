# Semantic-check helper for the four user-discovery gates (issue-10 A+
# upgrade). Not part of core/hooks/lib/gate-lib.{sh,py} (issue-72) — this is
# content-judgment logic scoped to this rulebook's own methodology markers,
# not a generic gate-house primitive, so it lives here instead.
#
# Closes the audit's substring-match false positives (survey §2.2/§2.3):
# a bare needle like "h1" or "opinion" matched anywhere in the document,
# including inside "<h1>" or inside a sentence *about* the rule ("we must
# not accept opinion alone"). The fix requires a marker to sit in a
# deliberate structural position — a labeled field line, a heading, a list
# item, or a bracket tag — not merely be a substring anywhere in the text.
#
# Loaded via importlib by each gate's Python payload, the same convention
# GATE_LIB_PY uses:
#
#   import importlib.util, os
#   _spec = importlib.util.spec_from_file_location("semantic", os.environ["SEMANTIC_PY"])
#   semantic = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(semantic)

import re

_HEADING_RE = re.compile(r'^\s{0,3}#{1,6}\s')
_LIST_RE = re.compile(r'^\s*(?:[-*]\s|\d+\.\s)')


def _word_re(word):
    # Word-boundary guard: neither side may be a word char or hyphen, so
    # "h1" does not match inside "<h1>" is still possible via < / > (both
    # non-word chars) — the boundary regex alone is NOT sufficient, which
    # is why structural_marker below also requires a structural position.
    return re.compile(r'(?<![\w-])' + re.escape(word) + r'(?![\w-])', re.I)


def word_present(text, *words):
    """Plain word-boundary match anywhere in text, no structural scoping.

    Reserved for markers that are already distinctive multi-token strings
    (e.g. "pain-confirmed", "not-confirmed") where the audit found no
    substring-collision bug and full structural scoping would instead
    weaken a real requirement (a verdict phrased as "Overall verdict:
    pain-confirmed." does not start a line with the bare "verdict:"
    label, but is unambiguously a verdict).
    """
    return any(_word_re(w).search(text) for w in words)


def _labeled_field_line(line, fields):
    m = re.match(r'^\s*([A-Za-z][A-Za-z \-]*)\s*:', line)
    if not m:
        return False
    return m.group(1).strip().lower() in fields


def structural_marker(text, *words, fields=("hypothesis", "evidence", "verdict")):
    """Word-boundary match for `words`, counted only when the match sits in
    a structural position:
      (i)   a labeled field line, e.g. "hypothesis: ..." / "evidence: ...",
            where the label is one of `fields`;
      (ii)  a Markdown heading line (``^#{1,6}\\s``);
      (iii) a list-item line (``^\\s*[-*]\\s`` / ``^\\s*\\d+\\.\\s``);
      (iv)  a bracket tag, e.g. "[behavioral]".
    A marker word appearing only in flowing prose outside all four
    positions does not count — this is what keeps "<h1>Notes</h1>" from
    satisfying a hypothesis marker and "we must not accept opinion alone"
    (running prose about the rule, not a tag) from satisfying an evidence
    marker.
    """
    for w in words:
        wre = _word_re(w)
        if re.search(r'\[\s*' + re.escape(w) + r'\s*\]', text, re.I):
            return True
        for line in text.splitlines():
            if wre.search(line) and (
                _labeled_field_line(line, fields)
                or _HEADING_RE.match(line)
                or _LIST_RE.match(line)
            ):
                return True
    return False


def _blocks(text):
    """Paragraph blocks (blank-line-separated), each as (start, end) spans
    over `text`, for same-block adjacency checks."""
    blocks = []
    pos = 0
    for part in re.split(r'\n\s*\n', text):
        if not part:
            pos += 2
            continue
        start = text.index(part, pos)
        end = start + len(part)
        blocks.append((start, end))
        pos = end
    return blocks


def same_block(text, re_a, re_b):
    """True if a match for `re_a` and a match for `re_b` fall in the same
    paragraph block of `text`."""
    ma = re_a.search(text)
    mb = re_b.search(text)
    if not ma or not mb:
        return False
    for start, end in _blocks(text):
        if start <= ma.start() < end and start <= mb.start() < end:
            return True
    return False
