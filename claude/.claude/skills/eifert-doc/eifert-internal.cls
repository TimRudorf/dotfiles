% eifert-internal.cls — LaTeX-Klasse für interne Dokumente der Eifert Systems GmbH
% Version 1.0, 2026-03-23

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{eifert-internal}[2026/03/23 v1.0 Eifert Systems GmbH - Interne Dokumente]

% Basisklasse
\LoadClass[a4paper,11pt]{article}

% ============================================================
% Pakete
% ============================================================
\RequirePackage[utf8]{inputenc}
\RequirePackage[T1]{fontenc}
\RequirePackage[ngerman]{babel}
\RequirePackage{lmodern}
\RequirePackage[margin=2.5cm,top=3cm,bottom=3cm]{geometry}
\RequirePackage{xcolor}
\RequirePackage{graphicx}
\RequirePackage{fancyhdr}
\RequirePackage{titlesec}
\RequirePackage{enumitem}
\RequirePackage{tabularx}
\RequirePackage{booktabs}
\RequirePackage{longtable}
\RequirePackage{hyperref}
\RequirePackage{lastpage}
\RequirePackage{parskip}
\RequirePackage{microtype}

% ============================================================
% Farben (abgeleitet von einsatzleitsoftware.de)
% ============================================================
\definecolor{eifert-black}{HTML}{000000}
\definecolor{eifert-dark}{HTML}{333333}
\definecolor{eifert-gray}{HTML}{666666}
\definecolor{eifert-light}{HTML}{E0E0E0}
\definecolor{eifert-bg}{HTML}{FAFAFA}
\definecolor{eifert-accent}{HTML}{2C2C2C}

% ============================================================
% Hyperref-Konfiguration
% ============================================================
\hypersetup{
    colorlinks=true,
    linkcolor=eifert-dark,
    urlcolor=eifert-gray,
    citecolor=eifert-dark,
    pdfauthor={Eifert Systems GmbH},
    pdftitle={},
    pdfsubject={Internes Dokument},
    pdfcreator={LaTeX / eifert-internal.cls}
}

% ============================================================
% Überschriften-Formatierung
% ============================================================
\titleformat{\section}
    {\Large\bfseries\color{eifert-black}}
    {\thesection}{1em}{}
    [\vspace{-0.5em}\textcolor{eifert-light}{\rule{\textwidth}{1pt}}]

\titleformat{\subsection}
    {\large\bfseries\color{eifert-dark}}
    {\thesubsection}{1em}{}

\titleformat{\subsubsection}
    {\normalsize\bfseries\color{eifert-accent}}
    {\thesubsubsection}{1em}{}

% ============================================================
% Kopf- und Fußzeilen
% ============================================================
\pagestyle{fancy}
\fancyhf{}
\renewcommand{\headrulewidth}{0.4pt}
\renewcommand{\footrulewidth}{0.4pt}
\renewcommand{\headrule}{\hbox to\headwidth{\color{eifert-light}\leaders\hrule height \headrulewidth\hfill}}
\renewcommand{\footrule}{\hbox to\headwidth{\color{eifert-light}\leaders\hrule height \footrulewidth\hfill}}

% Header: edp: Logo links, Dokumenttitel rechts
\fancyhead[L]{\textbf{\textcolor{eifert-black}{\large edp:}}\hspace{0.5em}{\small\textcolor{eifert-gray}{Eifert Systems GmbH}}}
\fancyhead[R]{\small\textcolor{eifert-gray}{\@title}}

% Footer: Klassifizierung links, Seitenzahl rechts
\newcommand{\@classification}{INTERN}
\newcommand{\classification}[1]{\renewcommand{\@classification}{#1}}
\fancyfoot[L]{\small\textcolor{eifert-gray}{\@classification}}
\fancyfoot[C]{}
\fancyfoot[R]{\small\textcolor{eifert-gray}{Seite \thepage\ von \pageref{LastPage}}}

% Auch für die erste Seite (plain)
\fancypagestyle{plain}{
    \fancyhf{}
    \renewcommand{\headrulewidth}{0pt}
    \renewcommand{\footrulewidth}{0.4pt}
    \renewcommand{\footrule}{\hbox to\headwidth{\color{eifert-light}\leaders\hrule height \footrulewidth\hfill}}
    \fancyfoot[L]{\small\textcolor{eifert-gray}{\@classification}}
    \fancyfoot[R]{\small\textcolor{eifert-gray}{Seite \thepage\ von \pageref{LastPage}}}
}

% ============================================================
% Variablen für die Titelseite
% ============================================================
\newcommand{\@subtitle}{}
\newcommand{\subtitle}[1]{\renewcommand{\@subtitle}{#1}}

\newcommand{\@department}{}
\newcommand{\department}[1]{\renewcommand{\@department}{#1}}

\newcommand{\@docversion}{1.0}
\newcommand{\docversion}[1]{\renewcommand{\@docversion}{#1}}

\newcommand{\@docid}{}
\newcommand{\docid}[1]{\renewcommand{\@docid}{#1}}

% ============================================================
% Titelseite
% ============================================================
\renewcommand{\maketitle}{%
    \thispagestyle{plain}
    \begin{center}
        \vspace*{1cm}

        % Logo als Text
        {\fontsize{48}{52}\selectfont\textbf{\textcolor{eifert-black}{edp:}}}

        \vspace{0.3cm}
        {\large\textcolor{eifert-gray}{Eifert Systems GmbH}}

        \vspace{2.5cm}

        % Trennlinie
        \textcolor{eifert-light}{\rule{0.6\textwidth}{1.5pt}}

        \vspace{1cm}

        % Titel
        {\LARGE\bfseries\textcolor{eifert-black}{\@title}}

        \ifx\@subtitle\empty\else
            \vspace{0.5cm}
            {\large\textcolor{eifert-dark}{\@subtitle}}
        \fi

        \vspace{1cm}

        % Trennlinie
        \textcolor{eifert-light}{\rule{0.6\textwidth}{1.5pt}}

        \vspace{2cm}

        % Metadaten-Tabelle
        \begin{tabular}{rl}
            \textcolor{eifert-gray}{Autor:} & \@author \\[0.3em]
            \textcolor{eifert-gray}{Datum:} & \@date \\[0.3em]
            \ifx\@department\empty\else
                \textcolor{eifert-gray}{Abteilung:} & \@department \\[0.3em]
            \fi
            \ifx\@docversion\empty\else
                \textcolor{eifert-gray}{Version:} & \@docversion \\[0.3em]
            \fi
            \ifx\@docid\empty\else
                \textcolor{eifert-gray}{Dokument-ID:} & \@docid \\[0.3em]
            \fi
            \textcolor{eifert-gray}{Klassifizierung:} & \@classification \\
        \end{tabular}

        \vfill

        {\small\textcolor{eifert-gray}{\textit{Ihre Einsätze. Unsere Mission.}}}

    \end{center}
    \newpage
}

% ============================================================
% Hilfs-Environments
% ============================================================

% Hinweis-Box
\newenvironment{hinweis}{%
    \par\vspace{0.5em}%
    \noindent\begin{tabular}{|p{0.95\textwidth}}
    \textbf{\textcolor{eifert-dark}{Hinweis:}} \\
}{%
    \end{tabular}\par\vspace{0.5em}%
}

% Kompakte Aufzählung
\newlist{kompakt}{itemize}{2}
\setlist[kompakt]{nosep, leftmargin=1.5em, label=\textcolor{eifert-dark}{\textbullet}}

% Nummerierte kompakte Liste
\newlist{kompaktenum}{enumerate}{2}
\setlist[kompaktenum]{nosep, leftmargin=2em}

\endinput
