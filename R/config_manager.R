# =============================================================================
# File   : R/config_manager.R
# Purpose: Persistent LLM API configuration.  Reads/writes a JSON file at
#          ~/.r-plot-ai/api_config.json so the user only has to enter their
#          API key once across sessions.
#          Defines the LLM_PROVIDERS registry for all supported services.
#
# Globals exported:
#   LLM_PROVIDERS  named list — one entry per supported provider, each with:
#                    name        [chr]  display name shown in the settings UI
#                    url         [chr]  OpenAI-compatible chat/completions URL
#                    models      [chr]  available model IDs
#                    placeholder [chr]  hint text for the API key field
#
# Functions:
#   load_api_config()
#     Reads CONFIG_PATH; falls back to .default_config() on any error.
#     Returns: list(provider, api_key, model, custom_url)
#
#   save_api_config(cfg)
#     Writes cfg to CONFIG_PATH, creating directories as needed.
#     Parameters: cfg [list]  same shape as load_api_config() return value.
#
#   get_api_url(cfg)
#     Resolves the effective API URL for cfg.
#     Returns custom_url for provider=="custom", else LLM_PROVIDERS url.
#     Parameters: cfg [list]
# =============================================================================

# ---------------------------------------------------------------------------
# Environment isolation via local():
#   CONFIG_PATH and .default_config are private implementation details.
#   Only LLM_PROVIDERS, load_api_config, save_api_config, get_api_url
#   are exported to the global environment via <<-.
# ---------------------------------------------------------------------------
local({

  .CONFIG_PATH <- path.expand("~/.r-plot-ai/api_config.json")

  .default_config <- function() {
    list(provider = "kimi", api_key = "", model = "moonshot-v1-8k", custom_url = "")
  }

  # ── Exported: LLM provider registry ──────────────────────────────────────
  LLM_PROVIDERS <<- list(
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
      name        = "OpenAI / Proxy",
      url         = "https://api.openai.com/v1/chat/completions",
      models      = c("gpt-4o", "gpt-4o-mini", "gpt-3.5-turbo"),
      placeholder = "sk-..."
    ),
    custom = list(
      name        = "Custom (OpenAI-compatible)",
      url         = "",
      models      = character(0),
      placeholder = "your API key"
    )
  )

  # ── Exported: load saved config (or return defaults) ─────────────────────
  load_api_config <<- function() {
    cfg <- .default_config()
    if (!file.exists(.CONFIG_PATH)) return(cfg)
    tryCatch({
      saved <- jsonlite::fromJSON(.CONFIG_PATH, simplifyVector = TRUE)
      for (nm in names(cfg)) {
        if (!is.null(saved[[nm]]) && nzchar(as.character(saved[[nm]])[1]))
          cfg[[nm]] <- as.character(saved[[nm]])[1]
      }
      cfg
    }, error = function(e) .default_config())
  }

  # ── Exported: persist config to disk ─────────────────────────────────────
  save_api_config <<- function(cfg) {
    dir_path <- dirname(.CONFIG_PATH)
    if (!dir.exists(dir_path))
      dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    tryCatch(
      jsonlite::write_json(cfg, .CONFIG_PATH, auto_unbox = TRUE),
      error = function(e) warning("config_manager: failed to save — ", conditionMessage(e))
    )
  }

  # ── Exported: resolve effective API URL for a config object ──────────────
  get_api_url <<- function(cfg) {
    if (identical(cfg$provider, "custom")) return(cfg$custom_url %||% "")
    LLM_PROVIDERS[[cfg$provider]]$url %||% ""
  }

})
