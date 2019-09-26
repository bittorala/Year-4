@default_files = ("main.tex");

$pdf_mode = 1;
$pdflatex="lualatex --shell-escape --file-line-error --interaction=nonstopmode %O %S";
