# Open build/deck_eq.pptx in PowerPoint, save the final deck (PowerPoint writes the equation fallbacks itself)
# and export every slide as PNG for checking. Run from slides/: powershell -ExecutionPolicy Bypass -File render.ps1
param([string]$Out = "G22_Presentation.pptx")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here "build\deck_eq.pptx"
$dst = Join-Path $here $Out
$png = Join-Path $here "build\png"
New-Item -ItemType Directory -Force $png | Out-Null
Get-ChildItem $png -Filter *.png | Remove-Item -Force
$app = New-Object -ComObject PowerPoint.Application
try {
    # Open(FileName, ReadOnly, Untitled, WithWindow)
    $p = $app.Presentations.Open($src, $true, $false, $false)
    $p.SaveAs($dst, 24)   # ppSaveAsOpenXMLPresentation
    foreach ($sl in $p.Slides) {
        $sl.Export((Join-Path $png ("slide-{0:D2}.png" -f $sl.SlideIndex)), "PNG", 1920, 1080)
    }
    "slides: $($p.Slides.Count)"
    $p.Close()
} finally {
    $app.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($app) | Out-Null
}
