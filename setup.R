# setup.R — 首次运行此脚本安装所有依赖，之后直接运行 app.R
# 用法：在 RStudio 中打开此文件，点击 Source；或在项目根目录执行：
#   Rscript setup.R

cat("=== r-plot-ai 环境初始化 ===\n\n")

required <- c(
  "shiny",
  "bslib",
  "ggplot2",
  "httr2",
  "jsonlite",
  "dplyr",
  "tidyr",
  "rhandsontable",
  "shinycssloaders",
  "ggridges",
  "treemapify",
  "ggDNAvis",
  "circlize",
  "colourpicker",
  "shinyjs"
)

installed  <- rownames(installed.packages())
to_install <- setdiff(required, installed)

if (length(to_install) == 0) {
  cat("所有依赖已安装，无需操作。\n")
} else {
  cat("待安装包：", paste(to_install, collapse = ", "), "\n\n")
  install.packages(
    to_install,
    repos      = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/",  # 清华镜像，国内更快
    dependencies = TRUE
  )
  cat("\n安装完成。\n")
}

cat("\n启动应用：shiny::runApp('.') 或在 RStudio 中打开 app.R 点击 Run App\n")
