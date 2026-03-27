suppressWarnings(suppressMessages(source("global.R")))

chart_id <- "scatter_basic"

tests <- list(
  list(tx = "\u6807\u9898\u6539\u6210 Sales Trend",   ef = "plot_title"),
  list(tx = "\u628a\u56fe\u540d\u6362\u6210 Revenue",  ef = "plot_title"),
  list(tx = "title = My Chart",                        ef = "plot_title"),
  list(tx = "\u7ed9\u8fd9\u5f20\u56fe\u8d77\u540d aaa", ef = "plot_title"),
  list(tx = "\u6a2a\u8f74\u6807\u7b7e\u8bbe\u4e3a Month", ef = "x_label"),
  list(tx = "y\u8f74 \u6539\u4e3a Sales",             ef = "y_label"),
  list(tx = "\u900f\u660e\u5ea6 0.5",                 ef = "opt_alpha"),
  list(tx = "\u70b9\u5927\u5c0f\u8c03\u6574\u4e3a 4", ef = "opt_point_size"),
  list(tx = "x\u8303\u56f4 0\u5230100",               ef = "x_range"),
  list(tx = "\u64a4\u9500",                            ef = "undo"),
  # regression: "X坐标" alias for x-axis range
  list(tx = "\u4fee\u6539X\u5750\u6807 1-10",         ef = "x_range"),
  list(tx = "\u6a2a\u5750\u6807 0\u523050",           ef = "x_range"),
  list(tx = "\u7eb5\u5750\u6807 0\u52305",            ef = "y_range")
)

pass <- 0
n    <- length(tests)
for (t in tests) {
  intent <- extract_intent_local(t[["tx"]], chart_id)
  hit    <- !is.null(intent) && (t[["ef"]] %in% intent[["hits"]])
  if (hit) pass <- pass + 1
  cat(
    sprintf("[%s] \"%s\"\n       hits: %s\n",
      if (hit) "PASS" else "FAIL",
      t[["tx"]],
      paste(if (is.null(intent)) "NULL" else intent[["hits"]], collapse = ", ")
    )
  )
}
cat(sprintf("\n\u7ed3\u679c: %d / %d \u901a\u8fc7\n", pass, n))
