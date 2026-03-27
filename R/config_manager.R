# R/config_manager.R
# Persistent API configuration — saved to ~/.r-plot-ai/api_config.json

CONFIG_PATH <- path.expand("~/.r-plot-ai/api_config.json")

# All supported LLM providers (all use OpenAI-compatible format)
LLM_PROVIDERS <- list(
  kimi = list(
    name        = "Kimi (月之暗面)",
    url         = "https://api.moonshot.cn/v1/chat/completions",
    models      = c("moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"),
    placeholder = "sk-..."
  ),
  deepseek = list(
    name        = "DeepSeek (深度求索)",
    url         = "https://api.deepseek.com/v1/chat/completions",
    models      = c("deepseek-chat", "deepseek-reasoner"),
    placeholder = "sk-..."
  ),
  qwen = list(
    name        = "通义千问 (Qwen)",
    url         = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
    models      = c("qwen-max", "qwen-plus", "qwen-turbo", "qwen-long"),
    placeholder = "sk-..."
  ),
  zhipu = list(
    name        = "智谱 GLM (Zhipu)",
    url         = "https://open.bigmodel.cn/api/paas/v4/chat/completions",
    models      = c("glm-4", "glm-4-flash", "glm-4-air"),
    placeholder = "your API key"
  ),
  openai = list(
    name        = "OpenAI / 代理",
    url         = "https://api.openai.com/v1/chat/completions",
    models      = c("gpt-4o", "gpt-4o-mini", "gpt-3.5-turbo"),
    placeholder = "sk-..."
  ),
  custom = list(
    name        = "自定义 (OpenAI 兼容)",
    url         = "",
    models      = character(0),
    placeholder = "your API key"
  )
)

.default_config <- function() {
  list(provider = "kimi", api_key = "", model = "moonshot-v1-8k", custom_url = "")
}

load_api_config <- function() {
  cfg <- .default_config()
  if (!file.exists(CONFIG_PATH)) return(cfg)
  tryCatch({
    saved <- jsonlite::fromJSON(CONFIG_PATH, simplifyVector = TRUE)
    for (nm in names(cfg)) {
      if (!is.null(saved[[nm]]) && nzchar(as.character(saved[[nm]])[1]))
        cfg[[nm]] <- as.character(saved[[nm]])[1]
    }
    cfg
  }, error = function(e) .default_config())
}

save_api_config <- function(cfg) {
  dir_path <- dirname(CONFIG_PATH)
  if (!dir.exists(dir_path))
    dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
  tryCatch(
    jsonlite::write_json(cfg, CONFIG_PATH, auto_unbox = TRUE),
    error = function(e) warning("Failed to save API config: ", conditionMessage(e))
  )
}

# Resolve the actual API URL for a given config
get_api_url <- function(cfg) {
  if (identical(cfg$provider, "custom")) return(cfg$custom_url %||% "")
  LLM_PROVIDERS[[cfg$provider]]$url %||% ""
}
