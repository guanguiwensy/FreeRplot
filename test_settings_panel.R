# =============================================================================
# File   : test_settings_panel.R
# Purpose: Focused regression checks for the Settings tab refactor.
#          Covers:
#            1. settings UI sections and Chinese-first labels
#            2. recipe storage roundtrip
#            3. legacy preset compatibility
#            4. current-chart-only option collection
#
# Usage:
#   & 'I:\R\R\R-4.4.2\bin\R.exe' -q -f test_settings_panel.R
# =============================================================================

suppressWarnings(suppressMessages(source("global.R")))
suppressWarnings(suppressMessages(source("ui.R")))
suppressWarnings(suppressMessages(source("server.R")))

assert_true <- function(ok, msg) {
  if (!isTRUE(ok)) stop(msg, call. = FALSE)
}

assert_equal <- function(x, y, msg) {
  if (!isTRUE(all.equal(x, y, check.attributes = FALSE))) {
    stop(msg, call. = FALSE)
  }
}

with_temp_app_dir <- function(expr) {
  tmp_root <- tempfile("settings-tests-")
  dir.create(tmp_root, recursive = TRUE, showWarnings = FALSE)

  old_exists <- exists("APP_DIR", envir = .GlobalEnv, inherits = FALSE)
  if (old_exists) {
    old_app_dir <- get("APP_DIR", envir = .GlobalEnv, inherits = FALSE)
  }

  assign("APP_DIR", tmp_root, envir = .GlobalEnv)
  on.exit({
    if (old_exists) {
      assign("APP_DIR", old_app_dir, envir = .GlobalEnv)
    } else if (exists("APP_DIR", envir = .GlobalEnv, inherits = FALSE)) {
      rm("APP_DIR", envir = .GlobalEnv)
    }
    unlink(tmp_root, recursive = TRUE, force = TRUE)
  }, add = TRUE)

  force(expr)
}

test_settings_ui_sections <- function() {
  markup <- as.character(tab_settings_ui())

  expected_labels <- c(
    "\u5b98\u65b9\u573a\u666f\u6a21\u677f",
    "\u6211\u7684\u914d\u65b9",
    "\u57fa\u7840\u6837\u5f0f",
    "\u989c\u8272",
    "\u5750\u6807\u4e0e\u5bfc\u51fa",
    "\u5f53\u524d\u56fe\u8868\u4e13\u5c5e\u8bbe\u7f6e",
    "\u57fa\u7840\u914d\u8272",
    "\u56fe\u8868\u4e3b\u9898",
    "\u5bbd\u5ea6\uff08in\uff09",
    "\u9ad8\u5ea6\uff08in\uff09",
    "\u6211\u7684\u914d\u65b9\u4f1a\u8bb0\u5f55\u56fe\u8868\u7c7b\u578b\u548c\u5f53\u524d\u8bbe\u7f6e"
  )

  missing <- expected_labels[!vapply(expected_labels, function(label) {
    grepl(label, markup, fixed = TRUE)
  }, logical(1))]

  assert_true(
    length(missing) == 0,
    paste("Settings UI labels missing:", paste(missing, collapse = ", "))
  )

  assert_true(
    !grepl(">Preset<", markup, fixed = TRUE),
    "Settings UI should no longer expose the old English Preset heading."
  )
}

test_collect_options_current_chart_only <- function() {
  fake_input <- shiny::reactiveValues(
    opt_alpha = 0.4,
    opt_bar_width = 0.7,
    opt_unused = 999
  )

  defs <- list(
    list(id = "alpha"),
    list(id = "bar_width")
  )

  opts <- shiny::isolate(collect_options(fake_input, defs))

  assert_equal(
    opts,
    list(alpha = 0.4, bar_width = 0.7),
    "collect_options() should only collect inputs declared in the active chart options_def."
  )
}

test_recipe_storage_roundtrip <- function() {
  with_temp_app_dir({
    recipe <- list(
      version = 1,
      name = "\u5206\u7ec4\u5bf9\u6bd4\u914d\u65b9",
      chart_id = "bar_grouped",
      global_settings = list(
        plot_title = "\u5206\u7ec4\u5bf9\u6bd4",
        color_palette = "\u5546\u52a1\u84dd",
        chart_theme = "\u7ecf\u5178"
      ),
      chart_options = list(
        show_labels = TRUE,
        bar_width = 0.65
      ),
      color_settings = list(
        base_palette = "\u5546\u52a1\u84dd",
        target_column = "product",
        overrides = list(
          "\u4ea7\u54c1A" = "#3366CC"
        )
      )
    )

    save_recipe(recipe$name, recipe)

    records <- list_recipe_records()
    assert_true(length(records) == 1, "Recipe storage should list the saved recipe.")
    assert_equal(records[[1]]$name, recipe$name, "Recipe record should preserve the display name.")
    assert_equal(records[[1]]$chart_id, recipe$chart_id, "Recipe record should preserve chart_id.")

    loaded <- load_recipe(recipe$name)
    assert_equal(loaded$name, recipe$name, "Recipe roundtrip should preserve recipe name.")
    assert_equal(loaded$chart_id, recipe$chart_id, "Recipe roundtrip should preserve chart type.")
    assert_equal(loaded$color_settings$base_palette, recipe$color_settings$base_palette,
                 "Recipe roundtrip should preserve color settings.")

    delete_recipe(recipe$name)
    assert_true(length(list_recipe_records()) == 0, "Recipe delete should remove the saved recipe.")
  })
}

test_legacy_preset_compatibility <- function() {
  with_temp_app_dir({
    dir.create(file.path(APP_DIR, "presets"), recursive = TRUE, showWarnings = FALSE)

    legacy_payload <- list(
      "\u65e7\u9884\u8bbeA" = list(
        plot_title = "\u5386\u53f2\u6563\u70b9\u56fe",
        color_palette = "\u7c89\u7d2b\u7cfb",
        alpha = 0.7
      )
    )

    jsonlite::write_json(
      legacy_payload,
      file.path(APP_DIR, "presets", "scatter_basic.json"),
      auto_unbox = TRUE,
      pretty = TRUE
    )

    records <- list_recipe_records(include_legacy = TRUE)
    legacy <- Filter(function(x) identical(x$source %||% "", "legacy"), records)

    assert_true(length(legacy) == 1, "Legacy preset files should appear as legacy recipe records.")
    assert_equal(legacy[[1]]$name, "\u65e7\u9884\u8bbeA", "Legacy recipe record should preserve the old preset name.")
    assert_equal(legacy[[1]]$chart_id, "scatter_basic", "Legacy recipe record should preserve the original chart id.")
  })
}

test_palette_overrides_for_named_levels <- function() {
  values <- palette_values_for_levels(
    levels = c("\u4ea7\u54c1A", "\u4ea7\u54c1B", "\u4ea7\u54c1C"),
    palette_name = "\u5546\u52a1\u84dd",
    overrides = list(
      "\u4ea7\u54c1B" = "#ff0000"
    )
  )

  assert_true(length(values) == 3, "Named palette helper should return one color per level.")
  assert_equal(unname(values[["\u4ea7\u54c1B"]]), "#ff0000",
               "Named palette helper should let explicit overrides replace the base palette.")
  assert_true(!is.null(names(values)), "Named palette helper should preserve level names.")
}

test_infer_palette_target_for_grouped_bar <- function() {
  df <- data.frame(
    quarter = c("Q1", "Q2", "Q1", "Q2"),
    sales = c(10, 12, 8, 9),
    product = c("A", "A", "B", "B"),
    stringsAsFactors = FALSE
  )

  target <- infer_palette_target("bar_grouped", df)
  assert_equal(target, "product", "Grouped bar charts should infer the grouping column as the palette target.")
}

test_settings_module_smoke <- function() {
  server_under_test <- function(input, output, session) {
    rv <- shiny::reactiveValues(
      current_data = CHARTS[["bar_grouped"]]$sample_data,
      api_config = list()
    )
    init_mod_settings(input, output, session, rv)
    list(rv = rv)
  }

  shiny::testServer(server_under_test, {
    session$setInputs(chart_type_select = "bar_grouped")

    color_markup <- paste(as.character(output$color_settings_ui), collapse = "")
    scene_markup <- paste(as.character(output$scene_templates_ui), collapse = "")
    chart_markup <- paste(as.character(output$chart_opts_ui), collapse = "")

    assert_true(
      grepl("\u989c\u8272\u6620\u5c04\u5b57\u6bb5", color_markup, fixed = TRUE),
      "Settings module should render the color override editor for grouped bar charts."
    )
    assert_true(
      grepl("\u67f1\u56fe\u5bb6\u65cf\u5b98\u65b9\u6a21\u677f", scene_markup, fixed = TRUE),
      "Settings module should render official scene templates for bar-family charts."
    )
    assert_true(
      !grepl("\u914d\u8272\u65b9\u6848", chart_markup, fixed = TRUE),
      "Chart-specific settings should no longer repeat a second palette selector."
    )
  })
}

tests <- list(
  settings_ui_sections = test_settings_ui_sections,
  collect_options_current_chart_only = test_collect_options_current_chart_only,
  recipe_storage_roundtrip = test_recipe_storage_roundtrip,
  legacy_preset_compatibility = test_legacy_preset_compatibility,
  palette_overrides_for_named_levels = test_palette_overrides_for_named_levels,
  infer_palette_target_for_grouped_bar = test_infer_palette_target_for_grouped_bar,
  settings_module_smoke = test_settings_module_smoke
)

for (name in names(tests)) {
  fn <- tests[[name]]
  fn()
  cat(sprintf("[PASS] %s\n", name))
}

cat("Settings panel regression checks: PASS\n")
