# IEEE-style SIMD Phase I report

This folder contains the editable report, source, bibliography, diagrams, and final PDF:

- `ieee_simd_report.docx` is the editable report and source used to generate the PDF in this environment.
- `ieee_simd_report.pdf` is the rendered five-page submission draft. It uses a clean single-column fallback layout; the `.tex` source specifies IEEEtran conference two-column layout.
- `ieee_simd_report.tex` and `references.bib` are editable IEEE conference-style LaTeX sources. The current environment has no LaTeX engine or local `IEEEtran.cls`, so this PDF was rendered from DOCX; the LaTeX source has not been compiled here.
- `figures/` contains the generated architecture, lane mapping, hierarchy and verification diagrams, plus the repository's existing datapath diagram and register waveform.

## Re-render the DOCX/PDF

Open the DOCX in Microsoft Word or LibreOffice and export to PDF. To use the bundled Codex runtime, invoke its `render_docx.py` helper with `--emit_pdf`.

## Compile the LaTeX source

Install a TeX distribution containing `IEEEtran.cls`, `pdflatex`, and BibTeX, then run from this directory:

```sh
pdflatex ieee_simd_report.tex
bibtex ieee_simd_report
pdflatex ieee_simd_report.tex
pdflatex ieee_simd_report.tex
```

The report reflects the RTL and testbench snapshot at main commit `94e7303f50045c6d890e39d2a80e5a7fbc52a71b` (2026-11-15). The 1,301 checks are reported check events, not exhaustive coverage. `control_tb`, `scalar_tb`, and `scalar_performance_tb` do not exit fatally on mismatch. No FPGA results or physical speedup are claimed.

## Complete before submission

Fill the bracketed department, university, course, guide, and official Kanchan name. Confirm all member contribution descriptions, roll numbers if required, actual submission date, and any faculty-prescribed formatting. The deadline provided was November 16, 2026, 11:59 PM IST. The report is not an IEEE publication or endorsement.
