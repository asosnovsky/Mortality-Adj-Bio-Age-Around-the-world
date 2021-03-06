
# Libraries
source("./scripts/00_method.R")
library(scales)

# LATEX CONVERSION
table1_latex <- function(Stage1_model) {
  latex_header <- function(title, subtitle) paste0(
    "\\clearpage\n",
    "\\begin{table}\n",
    "\\begin{center}\n",
    "\\begin{tabular}{||l|c|c|c|c|c|c|c||}\n",
    "\\hline\\hline\n",
    "\\multicolumn{8}{||c||}{",title," } \\\\ \\hline\\hline\n",
    "\\multicolumn{8}{||c||}{{\\bf ",subtitle,"}} \\\\ \\hline\\hline\n",
    
    "{\\bf Country} & $",
    "\\ln h[i]$ & $",
    "\\lambda_{0}[i]$ &",
    " {\\em Makeham:} $\\lambda$ &",
    " $g[i]$ & ",
    "$\\lambda_{55}[i]$ & ",
    "$m$ & ",
    "$b$ \\\\ \\hline \\hline\n",
    sep="", collapse = ""
  )
  
  latex_footer <- function(label, source="Source: Human Mortality Database, Period 2011") paste0(
    "\\hline\n",
    "\\multicolumn{8}{||r||}{{\\em ",source,"}} ",
    "\\\\ \\hline\\hline\n",
    "\\end{tabular}\n",
    "\\label{",label,"}\n",
    "\\smallskip\n",
    "\\end{center}\n",
    "\\end{table}\n"
  )
  
  params_to_latex <- function(lnh, l_0, l_m, g, l_55, m, b, prefix="") paste0(
    "$",prefix, number(lnh, acc=0.001) ,"$ & ",
    "$",prefix, number(l_0, acc=0.1) ,"\\times10^{-5}$ & ",
    "$",prefix, number(l_m, acc=0.1) ,"\\times10^{-5}$ & ",
    "$",prefix, number(g*100, acc=0.01, suffix = '\\%') ,"$ & ",
    "$",prefix, number(l_55*100, acc=0.001, suffix = '\\%') ,"$ & ",
    "$",prefix, number(m, acc=0.01) ,"$ & ",
    "$",prefix, number(b, acc=0.01) ,"$"
  )
  
  
  Stage1_model %>% arrange(Year, Gender, `Country Name`) %>%
    group_by(Gender) %>% 
    mutate(
      idx = 1:n(),
      l_0 = l_m+exp(g*1+lnh),
      l_55 = l_m+exp(g*56+lnh)
    ) %>% 
    select(
      Gender, idx, 
      `Country Name`,
      lnh, l_0, l_m, g, l_55, m, b
    ) %>% 
    mutate( l_0 = l_0*1E5, l_m = l_m*1E5 ) %>%
    mutate(
      latex = paste0(
        idx, ". ", `Country Name`, " &  ",
        params_to_latex(lnh, l_0, l_m, g, l_55, m, b)
      )
    ) %>% nest %>% 
    mutate( averages = map(
      data, 
      ~summarise_if(., is.numeric, mean) %>% select(-idx) 
    ) ) %>% 
    mutate( num_latex = map_chr(
      data, ~paste0(paste(.$latex, collapse = '\\\\ \\hline\n'), '\\\\ \\hline\n')
    ) ) %>% 
    mutate( avg_latex = map_chr(averages, ~paste0(
      "{\\bf Average:} & ",
      params_to_latex(.$lnh, .$l_0, .$l_m, .$g, .$l_55, .$m, .$b, prefix="\\bf ")
    )) ) %>% 
    mutate(
      header = case_when(
        Gender == "Male" ~ latex_header("Table \\# 1a", "Gompertz-Makeham Parameters Around the World: MALE"),
        Gender == "Female" ~ latex_header("Table \\# 1b", "Gompertz-Makeham Parameters Around the World: FEMALE"),
        Gender == "Total" ~ latex_header("Table \\# 1c", "Gompertz-Makeham Parameters Around the World: TOTAL"),
      ),
      footer = case_when(
        Gender == "Male" ~ latex_footer("lab1"),
        Gender == "Female" ~ latex_footer("lab2"),
        Gender == "Total" ~ latex_footer("labX")
      )
    ) %>% arrange(desc(Gender)) -> tmp
  paste0(tmp$header, tmp$num_latex, tmp$avg_latex, "\\\\ \\hline\n", tmp$footer)
}
table2_latex <- function(Stage2_model) {
  
  tabulate_coef <- function(coef, bold_est=F) coef %>% as.data.frame() %>% t %>% as_tibble %>% 
    mutate_all(~number(., acc=0.001)) %>% 
    mutate( Estimate = if_else(bold_est, paste0( "{\\bf", Estimate, "}" ), Estimate) ) %>% 
    unite(latex, Estimate, `Std. Error`, `t value`, sep = ' & ')
  
  inner_join(
    Stage2_model %>% select(Gender, model) %>% 
      mutate( coef = map(model, ~bind_rows(
        tabulate_coef(.$coefficient[1,1:3]) %>% mutate(coef="L"),
        tabulate_coef(.$coefficient[2,1:3], T) %>% mutate(coef="x")
      )  ) ) %>%
      unnest(coef) %>%
      spread(coef, latex),
    Stage2_model %>% rename(g = G) %>% 
      mutate(g_min = map_dbl(data, ~min(.$g))) %>% 
      mutate(g_max = map_dbl(data, ~max(.$g))) %>% 
      mutate(
        l_m = map_dbl(data, ~mean(.$l_m)),
        l_max = map_dbl(model, ~.$coefficients[1,1:2] %*% c(1,2)),
        l_min = map_dbl(model, ~.$coefficients[1,1:2] %*% c(1,-2)),
        l_max = exp(l_max) + l_m,
        l_min = exp(l_min) + l_m,
      ) %>% select(-l_m) %>% 
      mutate(N = map_dbl(data, nrow)) %>% 
      mutate(Radj2 = map_dbl(model, ~.$adj.r.squared*100) %>% number(acc=0.01)) %>% 
      select(-data, -model, -L, -`x*`) %>% 
      mutate_at(vars(starts_with('g', i=F)), ~number(.*100, acc=0.01, suf="\\%")) %>% 
      unite(g_range, g_min, g_max, sep=', ') %>% 
      mutate_at(vars(starts_with('l', i=F)), ~number(., acc=0.001)) %>% 
      unite(l_range, l_min, l_max, sep=', '),
    by="Gender"
  ) %>% gather(stat, value, -Gender) %>% 
    unite(stat, Gender, stat) %>% 
    spread(stat, value) -> vars
  
  paste0(
    "\\clearpage\n","\\begin{table}\n","\\begin{center}\n",
    "\\begin{tabular}{||c||c|c|c|c|c|c||}",
    "\\hline\\hline\n",
    "\\multicolumn{7}{||c||}{Table \\#2:} \\\\ \\hline\n",
    "\\multicolumn{7}{||c||}{{\\bf CLaM Regression Line Around the World}} \\\\ \\hline\n",
    "{\\bf Variable} & ",
    "\\multicolumn{3}{|c|}{{\\bf MALE}} & ",
    "\\multicolumn{3}{|c||}{{\\bf FEMALE}} \\\\ \\hline\n",
    "& Coeff. & Std.Er & t-val. & Coeff. & Std.Er & t-val.  \\\\ \\hline\n",
    
    "Intercept $(L)$ & ", vars$Male_L," & ", vars$Female_L, " \\\\ \\hline\n",
    "Slope: $(-x^{*})$ & ", vars$Male_x, " & ", vars$Female_x," \\\\ \\hline\n",
    "Adj. $R^2$ & ",
    "\\multicolumn{3}{|c|}{",vars$Male_Radj2,"\\%} & ",
    "\\multicolumn{3}{|c||}{",vars$Female_Radj2,"\\%} \\\\ \\hline\n",
    "Range: $g[i]$ & ",
    "\\multicolumn{3}{|c|}{$(",vars$Male_g_range,")$} & ",
    "\\multicolumn{3}{|c||}{$(",vars$Female_g_range,")$} \\\\ \\hline\n",
    "Average: $g[i]$ & ",
    "\\multicolumn{3}{|c|}{G \\; = \\; $", vars$Male_g, "$} & ",
    "\\multicolumn{3}{|c||}{G \\; = \\; $", vars$Female_g, "$} \\\\ \\hline\n",
    "Plateau (+/-): $\\lambda^{*}$ & ",
    "\\multicolumn{3}{|c|}{$ (", vars$Male_l_range, ")$} & ",
    "\\multicolumn{3}{|c||}{$ (", vars$Female_l_range, ")$} \\\\ \\hline\n",
    "Countries & ", 
    "\\multicolumn{3}{|c|}{$N=",vars$Male_N,"$} & ",
    "\\multicolumn{3}{|c||}{$N=",vars$Female_N,"$} \\\\ \\hline\n",
    
    "\\end{tabular}",
    "\\label{tab3}",
    "\\end{center}",
    "Note: These are the results from regressing the (male and female) Gompertz-Makeham (log) mortality intercepts $\\ln h[i]$ on the mortality growth rates $g[i]$, from the Human Mortality Database (HMD) for {\\em period} mortality in 2011. This is the second phase regression.\n",
    "\\end{table}"
  )
}
table3_latex <- function(Stage3_model) {
  Stage3_model %>% filter(Gender!="Total") %>%  
    filter( Age %in% c(55, 70, 85) ) %>%  
    select(Gender, `Country Name`, Age, LRAG_Age) %>% {
      bind_rows(
        spread(., Age, LRAG_Age) %>% 
          mutate_if(is.numeric, ~paste0("$", number(., acc=0.01), "$")) %>% 
          unite(value, `55`, `70`, `85`, sep=" & ") %>% 
          spread(Gender, value) %>% 
          unite(value, Male, Female, sep=" & ") %>% 
          mutate(value = paste0(value, "\\\\ \\hline \\hline\n")) %>% 
          mutate(`Country Name` = paste0(1:n(), ". ", `Country Name`)),
        group_by(., Gender, Age) %>% 
          summarise(LRAG_Age = mean(LRAG_Age) ) %>% 
          spread(Age, LRAG_Age) %>% ungroup %>%  
          mutate_if(is.numeric, ~paste0("{\\bf", number(., acc=0.01), "}")) %>% 
          unite(value, `55`, `70`, `85`, sep=" & ") %>% 
          spread(Gender, value) %>% 
          unite(value, Male, Female, sep=" & ") %>% 
          mutate(value = paste0(value, "\\\\ \\hline \\hline\n")) %>% 
          mutate(`Country Name` = "{\\bf Average:}")
      )
    } %>% ungroup %>% 
    unite(value, `Country Name`, value, sep=" & ") %>% { paste0(.$value, collapse = '', sep="") } -> 
    inner_table
  
  paste0(
    "\\clearpage",
    "\\begin{longtable}{||\n",
    "    p{95pt}|\n",
    "    p{35pt}|\n",
    "    p{35pt}|\n",
    "    p{35pt}|\n",
    "    p{35pt}|\n",
    "    p{35pt}|\n",
    "    p{35pt}\n",
    "||}\n",
    "\\hline\\hline\n",
    "\\multicolumn{7}{||c||}{Table \\# 3 } \\\\ \\hline\\hline\n",
    "\\multicolumn{7}{||c||}{{\\bf ",
    "Mortality-Adjusted Biological Ages $(\\xi)$ Around the World}}", 
    "\\\\ \\hline\\hline\n",
    "& \\multicolumn{3}{|c|}{{\\bf MALE}} &  ",
    "\\multicolumn{3}{|c||}{{\\bf FEMALE}} \\\\ \\hline \\hline",
    "{\\bf Country} & ",
    "$x=55$ &  $x=70$ & $x=85$ & $x=55$ & $x=70$ & $x=85$ \\\\ \\hline \\hline\n",
    inner_table,
    "\\hline\n",
    "\\multicolumn{7}{||r||}{{\\em ",
    "Source: Human Mortality Database, Period 2011}} \\\\ \\hline\\hline\n",
    "\\end{longtable}"
  ) 
}
create_tables123_in_pdf <- function(Stage1_model, Stage2_model, Stage3_model, out_file) {
    clear_folder(dirname(out_file))
    # Write Table
    cat(
        "\\documentclass[12pt, titlepage]{article}%\n",
        "\\author{Ariel Sosnovsky}\n",
        "\\usepackage{graphicx}\n",
        "\\usepackage{amsmath}\n",
        "\\usepackage{amsfonts}\n",
        "\\usepackage{amssymb}\n",
        "\\usepackage{fancyvrb}\n",
        "\\usepackage{longtable}\n",
        "\\usepackage[doublespacing]{setspace}\n",
        "\\setcounter{MaxMatrixCols}{30}\n",
        "\\providecommand{\\U}[1]{\\protect\\rule{.1in}{.1in}}\n",
        "\\oddsidemargin  -0.5in\n",
        "\\evensidemargin -0.5in\n",
        "\\marginparwidth 1in\n",
        "\\marginparsep 0pt\n",
        "\\topmargin -.5pt\n",
        "\\headheight 0pt\n",
        "\\headsep 0pt\n",
        "\\topskip 0pt\n",
        "\\footskip .5in\n",
        "\\textheight 9.25in\n",
        "\\textwidth 6.5in\n",
        "\\hoffset .5in\n",
        "\\font\\fiverm=cmr5\n",
        "\\newcounter{maineq}\n",
        "\\def\\theremark{}\n",
        "\\newtheorem{Proof}{Proof}\n",
        "\\def\\theProof{}\n",
        "\\pagestyle{plain}\n",
        "\\def\\theequation{\\arabic{equation}}\n",
        "\\def\\baselinestretch{1.2}\n",
        "\\usepackage{color}\n",
        "\\begin{document}\n",
        "\\title{Revised Tables: By Ariel Sosnovsky}\n",
        "\\maketitle\n",
        file = out_file
    )
    table1_latex(Stage1_model) %>% cat(file = out_file, sep="\n\n", append = T)
    table2_latex(Stage2_model) %>% cat(file = out_file, sep="\n\n", append = T)
    cat("\n\n", file=out_file, append = T)
    table3_latex(Stage3_model) %>% cat(file = out_file, sep="\n\n", append = T)
    cat("\\end{document}", file=out_file, append = T)

}

create_tables45_in_pdf <- function(Stage1_model, Stage2_model, out_file) {
    clear_folder(dirname(out_file))
    # =====================
    # File Header
    # =====================
    cat("\\documentclass[10pt, titlepage]{article}%
\\author{Ariel Sosnovsky}
\\usepackage{longtable}
\\usepackage{graphicx}

\\begin{document}
\\title{Historic Modelling}
\\maketitle

\\clearpage

\\begin{table}
  \\begin{center}
  \\begin{tabular}{||l|c|c|c|c||}
  \\hline\\hline
  \\multicolumn{5}{||c||}{Table \\# 4a } \\\\ \\hline\\hline
  \\multicolumn{5}{||c||}{{\\bf Gompertz Regression: Historical Coefficients}} \\\\ \\hline\\hline
  
  { } & 
  \\multicolumn{2}{|c|}{ \\bf Dispersion Coefficient $m$ } & 
  \\multicolumn{2}{|c|}{ \\bf Modal Value $b$ }\\\\ \\hline\\hline
  
  {\\bf Year } &
  {MALE} & {FEMALE} &
  {MALE} & {FEMALE} \\\\ \\hline\\hline
", file=out_file )


    # =====================
    # Table 4
    # =====================
    # Utils method
    convert_stat_latex = ~paste0(
    "$\\bf ", number(.$value, acc=0.01), "$ ",
    "$\\pm ", number(2*.$std, acc=0.01), "$"
    )
    # prep data
    Stage1_model %>% select(-c(data)) %>%
    group_by(Year, Gender, stat) %>% nest %>% ungroup() %>%
    pivot_wider(names_from=stat, values_from=data) %>%
    mutate(
        latex_b = map_chr(`b`, convert_stat_latex),
        latex_m = map_chr(`m`, convert_stat_latex),
        latex_lnh = map_chr(`lnh`, convert_stat_latex)
    ) %>%
    group_by(Year, Gender) %>% nest %>%
    pivot_wider(names_from=Gender, values_from=data) ->
    s1_prep

    Stage2_model %>% select(-c(data, model)) %>%
    group_by(Year, Gender, stat) %>% nest %>%
    pivot_wider(names_from=stat, values_from=data) %>%
    mutate(
        latex_x = map_chr(`x*`, convert_stat_latex),
        latex_L = map_chr(`L`, convert_stat_latex),
        latex_G = map_chr(G, ~paste0(" $", number(.$value, acc=0.0001), "$"))
    ) %>%
    group_by(Year, Gender) %>% nest %>%
    pivot_wider(names_from=Gender, values_from=data) ->
    s2_prep

    # Table 5a
    s1_prep %>%
    mutate(
        latex = paste0(
        map_chr(Male, ~.$latex_m), "& ",
        map_chr(Female, ~.$latex_m), "& ",
        map_chr(Male, ~.$latex_b), "& ",
        map_chr(Female, ~.$latex_b)
        )
    ) %>%
    select(Year, latex) %>%
    filter( Year %in% seq(1945, 2011, by=3) ) %>%
    apply(1, function(r) {
        cat("  ", r[["Year"]], "& ", r[["latex"]], "\\\\ \\hline\\hline\n", 
            file=out_file, append = T)
    })

    # In between area
    cat("              
\\multicolumn{5}{||r||}{{\\em Source: Human Mortality Database, Period 1945-2011, 15 Countries}} \\\\ \\hline\\hline
\\end{tabular}
\\label{table5a}

Note: The table displays two standard errors for each statistic.
\\end{center}
\\end{table}

\\begin{table}
  \\begin{center}
  \\begin{tabular}{||l|c|c|c|c|c|c||}
  \\hline\\hline
  \\multicolumn{7}{||c||}{Table \\# 4b } \\\\ \\hline\\hline
  \\multicolumn{7}{||c||}{{\\bf CLaM Regression: Historical Coefficients}} \\\\ \\hline\\hline
  
  { } & 
  \\multicolumn{2}{|c|}{ \\bf Slope: $(x^{*})$ } & 
  \\multicolumn{2}{|c|}{ \\bf Intercept $(L)$ }  &
  \\multicolumn{2}{|c||}{ \\bf Mortality Rate $(G)$ } \\\\ \\hline\\hline
  
  {\\bf Year } &
  {MALE} & {FEMALE} &
  {MALE} & {FEMALE} &
  {MALE} & {FEMALE} \\\\ \\hline\\hline

", file=out_file, append=T)

    # Table 5b
    s2_prep %>%
    mutate(
        latex = paste0(
        map_chr(Male, ~.$latex_x), "& ",
        map_chr(Female, ~.$latex_x), "& ",
        map_chr(Male, ~.$latex_L), "& ",
        map_chr(Female, ~.$latex_L), "& ",
        map_chr(Male, ~.$latex_G), "& ",
        map_chr(Female, ~.$latex_G)
        )
    ) %>%
    select(Year, latex) %>%
    filter( Year %in% seq(1945, 2011, by=3) ) %>%
    apply(1, function(r) {
        cat("  ", r[["Year"]], "& ", r[["latex"]], "\\\\ \\hline\\hline\n", 
            file=out_file, append = T)
    })

    # Footer
    cat("        
\\multicolumn{7}{||r||}{{\\em Source: Human Mortality Database, Period 1945-2011, 15 Countries}} \\\\ \\hline\\hline
\\end{tabular}
\\label{table5a}

Note: The table displays two standard errors for each statistic.
\\end{center}
\\end{table}

\\end{document}", file = out_file, append = T)

}