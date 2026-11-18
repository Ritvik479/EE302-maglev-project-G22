# D6 presentation (Group 22)

Final deck: `G22_Presentation.pptx` (14 talk slides + 5 backup). Equations are native PowerPoint equations,
written in LaTeX in `build_deck.js` and converted LaTeX → MathML → OMML.

Rebuild (from this folder; needs Node, Python with lxml + latex2mathml, MiKTeX, PowerPoint):

1. `npm install` (first time only; installs pptxgenjs)
2. `python -I prep_assets.py` (crops the report figures into `assets/`)
3. `node build_deck.js` (writes `build/deck_raw.pptx` and `build/eqs.json`)
4. `python -I inject_eq.py` (replaces the `EQ_*` text boxes with equations → `build/deck_eq.pptx`)
5. `powershell -ExecutionPolicy Bypass -File render.ps1` (PowerPoint saves `G22_Presentation.pptx` and exports `build/png/`; add `-Out other.pptx` if the deck is open in PowerPoint)

`assets/blockdiag.png` is the report's TikZ loop diagram: `pdflatex blockdiag.tex` then
`pdftoppm -png -r 300 -singlefile blockdiag.pdf blockdiag` inside `assets/`.

To change an equation, edit its LaTeX in `build_deck.js` (search `eq(s, "`) and rerun steps 3-5.
