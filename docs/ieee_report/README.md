# IEEE-style SIMD Phase I report

This folder contains the editable report, source, bibliography, diagrams, and final PDF:

- `ieee_simd_report.docx` is the editable Word version of the report (single-column layout).
- `ieee_simd_report.pdf` is compiled from the IEEEtran LaTeX source in the standard IEEE conference two-column layout.
- `ieee_simd_report.tex` and `references.bib` are the editable IEEE conference LaTeX sources. The source uses the IEEEtran conference class; the PDF was compiled with Tectonic 0.17.0.
- `figures/` contains the generated architecture, lane mapping, hierarchy and verification diagrams, plus the repository's existing datapath diagram and register waveform.

## Rebuild the IEEE PDF

Install Tectonic or a TeX distribution containing `IEEEtran.cls`, then run from this directory:

```sh
tectonic ieee_simd_report.tex
```

Tectonic runs the required bibliography pass automatically. If using `pdflatex`, run LaTeX, BibTeX, and LaTeX twice.

The report reflects the RTL and testbench snapshot at main commit `94e7303f50045c6d890e39d2a80e5a7fbc52a71b` (2026-11-15). The 1,301 checks are reported check events, not exhaustive coverage. `control_tb`, `scalar_tb`, and `scalar_performance_tb` do not exit fatally on mismatch. No FPGA results or physical speedup are claimed.

## Complete before submission

Fill the bracketed faculty guide and any institution-specific details. Confirm all member contribution descriptions, actual submission date, and any faculty-prescribed formatting. The deadline provided was November 16, 2026, 11:59 PM IST. The report is not an IEEE publication or endorsement.
