# LaTeX-Vorlage für Lernzusammenfassungen

## Preamble

```latex
\documentclass[a4paper,11pt]{article}
\usepackage[ngerman]{babel}
\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage{amsmath,amssymb,mathtools}
\usepackage[left=2cm,right=2cm,top=2.5cm,bottom=2.5cm]{geometry}
\usepackage{enumitem}
\usepackage{mdframed}
\usepackage{hyperref}
\usepackage{booktabs}
\usepackage{fancyhdr}
\usepackage{xcolor}
\usepackage{parskip}
```

## Farb-Definitionen

```latex
\definecolor{defblue}{RGB}{41,98,255}
\definecolor{recipegreen}{RGB}{46,139,87}
\definecolor{warnred}{RGB}{220,53,69}
\definecolor{tipyellow}{RGB}{255,193,7}
```

## mdframed-Umgebungen

```latex
\newenvironment{definition}[1]{%
  \begin{mdframed}[backgroundcolor=defblue!5,linecolor=defblue!80,linewidth=1pt,roundcorner=4pt,skipabove=10pt,skipbelow=10pt]
  \textbf{\textcolor{defblue}{#1}}\par\medskip
}{%
  \end{mdframed}
}

\newenvironment{kochrezept}[1]{%
  \begin{mdframed}[backgroundcolor=recipegreen!5,linecolor=recipegreen!80,linewidth=1pt,roundcorner=4pt,skipabove=10pt,skipbelow=10pt]
  \textbf{\textcolor{recipegreen}{#1}}\par\medskip
}{%
  \end{mdframed}
}

\newenvironment{warnung}[1]{%
  \begin{mdframed}[backgroundcolor=warnred!5,linecolor=warnred!80,linewidth=1pt,roundcorner=4pt,skipabove=10pt,skipbelow=10pt]
  \textbf{\textcolor{warnred}{#1}}\par\medskip
}{%
  \end{mdframed}
}

\newenvironment{tipp}[1]{%
  \begin{mdframed}[backgroundcolor=tipyellow!5,linecolor=tipyellow!80,linewidth=1pt,roundcorner=4pt,skipabove=10pt,skipbelow=10pt]
  \textbf{\textcolor{tipyellow}{#1}}\par\medskip
}{%
  \end{mdframed}
}
```
