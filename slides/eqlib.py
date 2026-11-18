"""LaTeX -> MathML (latex2mathml) -> OMML (Office's MML2OMML.XSL) -> PowerPoint a14:m math XML."""
import re
from lxml import etree
from latex2mathml.converter import convert

XSL = r"C:\Program Files\Microsoft Office\root\Office16\MML2OMML.XSL"
M = "http://schemas.openxmlformats.org/officeDocument/2006/math"
A = "http://schemas.openxmlformats.org/drawingml/2006/main"
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
_xslt = etree.XSLT(etree.parse(XSL))


def omml(latex, sz=2000, color="1F2A44"):
    """Return the <m:oMath> element (as a string) for a LaTeX expression, styled for PowerPoint."""
    mml = convert(latex)
    doc = etree.fromstring(mml.encode("utf-8"))
    # mark over-accents (dot, hat, bar...) so MML2OMML emits m:acc instead of a stacked limit
    for mo in doc.iter("{http://www.w3.org/1998/Math/MathML}mover"):
        mo.set("accent", "true")
    # MML2OMML drops <mspace>; turn LaTeX spacing (\, \: \; \quad \qquad) into Unicode spaces in <mtext>
    MMLNS = "{http://www.w3.org/1998/Math/MathML}"
    widths = {"0.167em": " ", "0.222em": " ", "0.278em": " ", "1em": " ", "2em": "  "}
    for sp in list(doc.iter(MMLNS + "mspace")):
        t = etree.Element(MMLNS + "mtext")
        t.text = widths.get(sp.get("width", ""), " ")
        t.tail = sp.tail
        sp.getparent().replace(sp, t)
    om = _xslt(doc).getroot()
    for r in om.iter("{%s}r" % M):
        for w in r.findall("{%s}rPr" % W):
            r.remove(w)
        # \text{} arrives as m:nor, which PowerPoint draws full-size even in sub/superscripts;
        # m:sty="p" (plain upright math) keeps the upright look and scales with the script level
        mrpr = r.find("{%s}rPr" % M)
        if mrpr is not None:
            for nor in mrpr.findall("{%s}nor" % M):
                mrpr.remove(nor)
                sty = etree.SubElement(mrpr, "{%s}sty" % M)
                sty.set("{%s}val" % M, "p")
        arpr = etree.Element("{%s}rPr" % A, nsmap={"a": A})
        arpr.set("lang", "en-US"); arpr.set("sz", str(sz))
        fill = etree.SubElement(arpr, "{%s}solidFill" % A)
        etree.SubElement(fill, "{%s}srgbClr" % A, val=color)
        etree.SubElement(arpr, "{%s}latin" % A, typeface="Cambria Math", panose="02040503050406030204")
        etree.SubElement(arpr, "{%s}cs" % A, typeface="Cambria Math", panose="02040503050406030204")
        idx = 1 if (len(r) and r[0].tag == "{%s}rPr" % M) else 0
        r.insert(idx, arpr)
    s = etree.tostring(om, encoding="unicode")
    # strip namespace declarations; the wrapper declares them
    s = re.sub(r'\sxmlns:\w+="[^"]*"', "", s)
    return s
