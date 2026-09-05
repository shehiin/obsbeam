\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{obsbeam}[2026/08/19 obsbeam Beamer wrapper]

% RichMedia was standardized for PDF 1.7. This must be selected before Beamer
% loads Hyperref; setting it later in the document preamble is ineffective.
\ifdefined\pdfvariable
  \pdfvariable minorversion=7\relax
\fi
\ifdefined\pdfminorversion
  \pdfminorversion=7\relax
\fi

\LoadClassWithOptions{beamer}
