"""Speaker-notes PDF from the finished deck: team brief first, then one page per slide (thumbnail + full notes).

Reads titles and notes from the .pptx itself (so the PDF always matches the deck) and the slide images from build/png
(written by render.ps1). Run from slides/: python -I make_notes_pdf.py [deck.pptx]  -> G22_Speaker_Notes.pdf (LuaLaTeX)
"""
import re
import subprocess
import sys
from pathlib import Path

from pptx import Presentation

HERE = Path(__file__).resolve().parent
DECK = HERE / (sys.argv[1] if len(sys.argv) > 1 else "G22_Presentation.pptx")
OUTDIR = HERE / "build" / "notes_pdf"
OUTDIR.mkdir(parents=True, exist_ok=True)
SPECIAL = {"\\": r"\textbackslash{}", "&": r"\&", "%": r"\%", "$": r"\$", "#": r"\#", "_": r"\_",
           "{": r"\{", "}": r"\}", "~": r"\textasciitilde{}", "^": r"\textasciicircum{}"}


def esc(s):
    s = "".join(SPECIAL.get(ch, ch) for ch in s)
    return s.replace("->", r"$\rightarrow$").replace("<=", r"$\leq$")


def quotes(s):
    # straight double quotes -> curly, alternating open/close
    out, open_ = [], True
    for ch in s:
        if ch == '"':
            out.append("``" if open_ else "''")
            open_ = not open_
        else:
            out.append(ch)
    return "".join(out)


def esc_text(s):
    return esc(quotes(s)) if '"' in s else esc(s)


def title_tex(shape):
    """Title runs with real sub/superscripts (baseline attribute on the run)."""
    parts = []
    for p in shape.text_frame.paragraphs:
        for r in p.runs:
            t = esc_text(r.text)
            base = r.font._rPr.get("baseline") if r.font._rPr is not None else None
            if base and int(base) < 0:
                t = r"\textsubscript{" + t + "}"
            elif base and int(base) > 0:
                t = r"\textsuperscript{" + t + "}"
            parts.append(t)
    return "".join(parts)


LABEL = re.compile(r"^([A-Z][A-Z0-9 /()\-]*[A-Z)])(:|\s-\s)(.*)$")


def note_tex(text):
    """Notes -> LaTeX: upper-case labels bold, '- ' lines as bullets, numbered steps kept, blank lines as gaps."""
    out, in_list = [], False
    for line in text.split("\n"):
        line = line.rstrip()
        if not line:
            if in_list:
                out.append(r"\end{itemize}")
                in_list = False
            out.append(r"\medskip")
            continue
        if line.startswith("- ") or re.match(r"^\d+\.\s", line):
            if not in_list:
                out.append(r"\begin{itemize}[leftmargin=1.4em,itemsep=1pt,topsep=2pt]")
                in_list = True
            body = line[2:] if line.startswith("- ") else line
            label = None if line.startswith("- ") else ""
            out.append(r"\item " + esc_text(body) if label is None else r"\item[] " + esc_text(body))
            continue
        if in_list:
            out.append(r"\end{itemize}")
            in_list = False
        m = LABEL.match(line)
        if m:
            colour = "say" if m.group(1) == "SAY" else "lab"
            out.append(r"\par\noindent\textbf{\textcolor{" + colour + "}{" + esc_text(m.group(1) + m.group(2).rstrip()) +
                       "}} " + esc_text(m.group(3).lstrip()) + r"\par")
        else:
            out.append(r"\par\noindent " + esc_text(line) + r"\par")
    if in_list:
        out.append(r"\end{itemize}")
    return "\n".join(out)


prs = Presentation(DECK)
slides = []
for k, s in enumerate(prs.slides, 1):
    title = title_tex(s.shapes.title) if s.shapes.title is not None else ""
    notes = s.notes_slide.notes_text_frame.text if s.has_notes_slide else ""
    slides.append((k, title, notes))

# split the team brief off slide 1
k1, t1, n1 = slides[0]
cut = n1.index("SPEAKER:")
team, slides[0] = n1[:cut].strip(), (k1, t1, n1[cut:])
talk_last = next(k for k, t, n in slides if n.startswith("BACKUP")) - 1

doc = [r"""\documentclass[11pt,a4paper]{article}
\usepackage[margin=1.8cm,top=1.6cm,bottom=1.8cm]{geometry}
\usepackage{fontspec}\setmainfont{Calibri}
\usepackage{graphicx,xcolor,enumitem,fancyhdr}
\definecolor{navy}{HTML}{14213D}\definecolor{say}{HTML}{2F6DB5}\definecolor{lab}{HTML}{14213D}\definecolor{grey}{HTML}{6B7789}
\setlength{\parindent}{0pt}\setlength{\parskip}{3pt}
\pagestyle{fancy}\fancyhf{}\renewcommand{\headrulewidth}{0pt}
\fancyfoot[L]{\small\color{grey}Group 22 -- speaker notes}\fancyfoot[R]{\small\color{grey}\thepage}
\begin{document}
{\fontsize{22}{26}\selectfont\bfseries\color{navy} Speaker notes}\par
{\large\color{grey} Robust Control of a Magnetic Levitation System \textbullet\ Group 22}\par\bigskip
{\Large\bfseries\color{navy} Team brief}\par\medskip
"""]
doc.append(note_tex(team))
doc.append(r"\par\bigskip{\color{grey}\small Below: one page per slide, the slide as shown and its notes. \textbf{\color{say}SAY} "
           r"is read aloud; IF ASKED lines are for questions only. Slides " + str(talk_last + 1) + "--" + str(len(slides)) +
           r" are backup slides.}")
for k, title, notes in slides:
    img = (HERE / "build" / "png" / f"slide-{k:02d}.png").as_posix()
    tag = " (backup)" if k > talk_last else ""
    doc.append(r"\clearpage")
    doc.append(r"{\Large\bfseries\color{navy} Slide " + str(k) + tag + r"}\par")
    if title:
        doc.append(r"{\large\color{grey} " + title + r"}\par")
    doc.append(r"\medskip\begin{center}\fbox{\includegraphics[width=0.62\linewidth]{" + img + r"}}\end{center}\medskip")
    doc.append(note_tex(notes))
doc.append(r"\end{document}")

tex = OUTDIR / "G22_Speaker_Notes.tex"
tex.write_text("\n".join(doc), encoding="utf-8")
for _ in range(2):
    r = subprocess.run(["lualatex", "-interaction=nonstopmode", tex.name], cwd=OUTDIR, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
pdf = OUTDIR / "G22_Speaker_Notes.pdf"
if r.returncode != 0 or not pdf.exists():
    print("\n".join(l for l in r.stdout.splitlines() if l.startswith("!"))[:3000])
    sys.exit("LuaLaTeX failed")
(HERE / "G22_Speaker_Notes.pdf").write_bytes(pdf.read_bytes())
print("wrote G22_Speaker_Notes.pdf,", len(slides), "slides; team brief", len(team.split()), "words")
