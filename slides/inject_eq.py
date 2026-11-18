"""Replace the EQ_<id> text boxes of build/deck_raw.pptx by native PowerPoint equations (OMML).

Each equation is LaTeX (build/eqs.json, written by build_deck.js) converted by eqlib.omml. The shape is wrapped in
mc:AlternateContent exactly as PowerPoint saves equations: the a14:m math in mc:Choice, the plain-text box as fallback.
Run from slides/: python -I inject_eq.py  -> build/deck_eq.pptx
"""
import json
import re
import sys
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import eqlib  # noqa: E402

SRC = HERE / "build" / "deck_raw.pptx"
DST = HERE / "build" / "deck_eq.pptx"
EQS = json.loads((HERE / "build" / "eqs.json").read_text(encoding="utf-8"))

MC = "http://schemas.openxmlformats.org/markup-compatibility/2006"
A14 = "http://schemas.microsoft.com/office/drawing/2010/main"
MNS = "http://schemas.openxmlformats.org/officeDocument/2006/math"
SP_RE = re.compile(r"<p:sp>(?:(?!<p:sp>).)*?</p:sp>", re.S)
JC = {"left": "left", "center": "center", "right": "right"}


def math_sp(sp, spec):
    om = eqlib.omml(spec["latex"], sz=spec["sz"], color=spec["color"])
    algn = {"left": "l", "center": "ctr", "right": "r"}[spec["align"]]
    para = (f'<a:p><a:pPr algn="{algn}"/><a14:m><m:oMathPara xmlns:m="{MNS}"><m:oMathParaPr>'
            f'<m:jc m:val="{JC[spec["align"]]}"/></m:oMathParaPr>{om}</m:oMathPara></a14:m>'
            f'<a:endParaRPr lang="en-US" sz="{spec["sz"]}"/></a:p>')
    body = re.search(r"(<p:txBody>.*?<a:lstStyle/>)(.*)(</p:txBody>)", sp, re.S)
    if not body:
        raise ValueError("no txBody in equation shape")
    return sp[: body.start(2)] + para + sp[body.end(2):]


def main():
    used = set()
    zin = zipfile.ZipFile(SRC)
    with zipfile.ZipFile(DST, "w", zipfile.ZIP_DEFLATED) as zout:
        for info in zin.infolist():
            data = zin.read(info.filename)
            if re.match(r"ppt/slides/slide\d+\.xml$", info.filename):
                xml = data.decode("utf-8")

                def repl(m):
                    sp = m.group(0)
                    k = re.search(r'name="EQ_(\w+)"', sp)
                    if not k:
                        return sp
                    eid = k.group(1)
                    used.add(eid)
                    new = math_sp(sp, EQS[eid])
                    return (f'<mc:AlternateContent xmlns:mc="{MC}"><mc:Choice xmlns:a14="{A14}" Requires="a14">'
                            f"{new}</mc:Choice><mc:Fallback>{sp}</mc:Fallback></mc:AlternateContent>")

                xml = SP_RE.sub(repl, xml)
                data = xml.encode("utf-8")
            zout.writestr(info, data)
    missing = set(EQS) - used
    print(f"injected {len(used)} equations into {DST.name}" + (f"; MISSING {sorted(missing)}" if missing else ""))
    if missing:
        sys.exit(1)


if __name__ == "__main__":
    main()
