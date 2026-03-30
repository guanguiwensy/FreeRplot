# =============================================================================
# File   : R/modules/mod_overlay.R
# Purpose: Overlay server module for front-end SVG overlay synchronization and
#          combined vector export (base plot + overlay layer).
#
# Depends: R/core/module_shared.R (shared_active_data_reactive,
#                                  shared_is_probably_numeric,
#                                  shared_clamp_plot_dimensions)
#          R/utils/logger.R       (log_debug, log_info, log_warn)
#
# Exported functions:
#   init_mod_overlay(input, output, session, rv)
# =============================================================================

local({
  .MODULE <- "mod_overlay"

  init_mod_overlay <<- function(input, output, session, rv) {

    last_shared_points_json <- reactiveVal("")
    last_extra_cfg_json <- reactiveVal("")

    xml_escape <- function(x) {
      x <- as.character(x %||% "")
      x <- gsub("&", "&amp;", x, fixed = TRUE)
      x <- gsub("<", "&lt;", x, fixed = TRUE)
      x <- gsub(">", "&gt;", x, fixed = TRUE)
      x <- gsub("\"", "&quot;", x, fixed = TRUE)
      gsub("'", "&apos;", x, fixed = TRUE)
    }

    normalize_overlay_points <- function(df_like) {
      if (is.null(df_like) || nrow(df_like) == 0) return(list())
      if (!all(c("x", "y") %in% names(df_like))) return(list())

      x <- suppressWarnings(as.numeric(df_like$x))
      y <- suppressWarnings(as.numeric(df_like$y))
      keep <- is.finite(x) & is.finite(y)
      if (!any(keep)) return(list())

      x <- x[keep]
      y <- y[keep]
      color <- if ("color" %in% names(df_like)) as.character(df_like$color[keep]) else rep("#2c7be5", length(x))
      size <- if ("size" %in% names(df_like)) suppressWarnings(as.numeric(df_like$size[keep])) else rep(3, length(x))
      size[!is.finite(size)] <- 3

      rng_x <- range(x, na.rm = TRUE)
      rng_y <- range(y, na.rm = TRUE)
      dx <- if (diff(rng_x) == 0) 1 else diff(rng_x)
      dy <- if (diff(rng_y) == 0) 1 else diff(rng_y)

      xs <- (x - rng_x[1]) / dx
      ys <- (y - rng_y[1]) / dy

      lapply(seq_along(xs), function(i) {
        list(
          x = max(0, min(1, xs[i])),
          y = max(0, min(1, ys[i])),
          color = color[i] %||% "#2c7be5",
          size = size[i]
        )
      })
    }

    build_shared_overlay_points <- function(data, limit = 180L) {
      if (is.null(data) || nrow(data) == 0) return(list())
      nums <- names(data)[vapply(data, shared_is_probably_numeric, logical(1))]
      if (length(nums) < 2) return(list())

      df <- data.frame(
        x = suppressWarnings(as.numeric(data[[nums[1]]])),
        y = suppressWarnings(as.numeric(data[[nums[2]]])),
        stringsAsFactors = FALSE
      )
      if (nrow(df) > limit) df <- df[seq_len(limit), , drop = FALSE]
      normalize_overlay_points(df)
    }

    parse_custom_overlay_points <- function(txt) {
      if (is.null(txt) || !nzchar(trimws(txt))) return(list())
      parsed <- tryCatch(jsonlite::fromJSON(txt, simplifyVector = FALSE), error = function(e) NULL)
      if (is.null(parsed) || !is.list(parsed) || length(parsed) == 0) return(list())

      rows <- lapply(parsed, function(p) {
        if (!is.list(p)) return(NULL)
        data.frame(
          x = suppressWarnings(as.numeric(p$x %||% NA_real_)),
          y = suppressWarnings(as.numeric(p$y %||% NA_real_)),
          color = as.character(p$color %||% "#2c7be5"),
          size = suppressWarnings(as.numeric(p$size %||% 3)),
          stringsAsFactors = FALSE
        )
      })
      rows <- Filter(Negate(is.null), rows)
      if (length(rows) == 0) return(list())
      normalize_overlay_points(do.call(rbind, rows))
    }

    parse_overlay_scene <- function(scene_json) {
      if (is.null(scene_json) || !nzchar(trimws(scene_json))) return(list())
      parsed <- tryCatch(jsonlite::fromJSON(scene_json, simplifyVector = FALSE), error = function(e) NULL)
      if (is.null(parsed) || !is.list(parsed)) return(list())
      Filter(function(x) is.list(x) && nzchar(as.character(x$type %||% "")), parsed)
    }

    safe_num <- function(x, default = 0) {
      v <- suppressWarnings(as.numeric(x))
      if (length(v) == 0 || !is.finite(v[1])) default else v[1]
    }

    scene_to_svg_group <- function(scene, width, height) {
      if (length(scene) == 0) {
        return('<g id="overlay-layer"></g>')
      }

      sx <- function(v) safe_num(v, 0) / 1000 * width
      sy <- function(v) safe_num(v, 0) / 1000 * height

      parts <- c(
        '<defs><marker id="overlay-arrow-head-export" markerWidth="10" markerHeight="8" refX="9" refY="4" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 4 L 0 8 z" fill="#dc3545"/></marker></defs>',
        '<g id="overlay-layer">'
      )

      for (obj in scene) {
        tp <- as.character(obj$type %||% "")
        if (!nzchar(tp)) next

        if (identical(tp, "triangle")) {
          x <- sx(obj$x); y <- sy(obj$y); size <- max(2, sx(obj$size %||% 30))
          pts <- sprintf(
            "%.4f,%.4f %.4f,%.4f %.4f,%.4f",
            x, y - size,
            x - size * 0.85, y + size * 0.65,
            x + size * 0.85, y + size * 0.65
          )
          parts <- c(parts, sprintf(
            '<polygon points="%s" fill="%s" stroke="%s" stroke-width="%.3f" opacity="%.3f"/>',
            pts, xml_escape(obj$fill %||% "rgba(255, 99, 71, 0.35)"),
            xml_escape(obj$stroke %||% "#dc3545"),
            max(0.5, safe_num(obj$strokeWidth, 2)),
            max(0.05, min(1, safe_num(obj$opacity, 0.85)))
          ))
          next
        }

        if (identical(tp, "rect")) {
          parts <- c(parts, sprintf(
            '<rect x="%.4f" y="%.4f" width="%.4f" height="%.4f" fill="%s" stroke="%s" stroke-width="%.3f" opacity="%.3f"/>',
            sx(obj$x), sy(obj$y),
            max(2, sx(obj$width %||% 90)), max(2, sy(obj$height %||% 60)),
            xml_escape(obj$fill %||% "rgba(13, 110, 253, 0.15)"),
            xml_escape(obj$stroke %||% "#0d6efd"),
            max(0.5, safe_num(obj$strokeWidth, 2)),
            max(0.05, min(1, safe_num(obj$opacity, 0.85)))
          ))
          next
        }

        if (identical(tp, "arrow")) {
          parts <- c(parts, sprintf(
            '<line x1="%.4f" y1="%.4f" x2="%.4f" y2="%.4f" stroke="%s" stroke-width="%.3f" opacity="%.3f" marker-end="url(#overlay-arrow-head-export)"/>',
            sx(obj$x1), sy(obj$y1), sx(obj$x2), sy(obj$y2),
            xml_escape(obj$stroke %||% "#dc3545"),
            max(0.5, safe_num(obj$strokeWidth, 3)),
            max(0.05, min(1, safe_num(obj$opacity, 0.9)))
          ))
          next
        }

        if (identical(tp, "text")) {
          parts <- c(parts, sprintf(
            '<text x="%.4f" y="%.4f" fill="%s" opacity="%.3f" font-size="%.3f" font-family="%s" font-weight="%s">%s</text>',
            sx(obj$x), sy(obj$y), xml_escape(obj$color %||% "#111111"),
            max(0.05, min(1, safe_num(obj$opacity, 1))),
            max(8, sy(obj$fontSize %||% 26)),
            xml_escape(obj$fontFamily %||% "Segoe UI, PingFang SC, sans-serif"),
            xml_escape(obj$fontWeight %||% "600"),
            xml_escape(obj$text %||% "Label")
          ))
          next
        }

        if (identical(tp, "extra_data")) {
          x <- sx(obj$x); y <- sy(obj$y)
          w <- max(8, sx(obj$width %||% 220)); h <- max(8, sy(obj$height %||% 150))
          parts <- c(parts, sprintf(
            '<rect x="%.4f" y="%.4f" width="%.4f" height="%.4f" fill="%s" stroke="%s" stroke-width="%.3f" stroke-dasharray="5 5" opacity="%.3f"/>',
            x, y, w, h,
            xml_escape(obj$fill %||% "#ffffff"),
            xml_escape(obj$stroke %||% "#6c757d"),
            max(0.5, safe_num(obj$strokeWidth, 1.3)),
            max(0.05, min(1, safe_num(obj$opacity, 0.95)))
          ))

          pts <- obj$points %||% list()
          for (p in pts) {
            px <- x + max(0, min(1, safe_num(p$x, 0.5))) * w
            py <- y + (1 - max(0, min(1, safe_num(p$y, 0.5)))) * h
            parts <- c(parts, sprintf(
              '<circle cx="%.4f" cy="%.4f" r="%.3f" fill="%s" fill-opacity="0.8"/>',
              px, py, max(1, safe_num(p$size, 3)),
              xml_escape(p$color %||% "#2c7be5")
            ))
          }
          next
        }

        if (identical(tp, "inset")) {
          x <- sx(obj$x); y <- sy(obj$y)
          w <- max(18, sx(obj$width %||% 260)); h <- max(18, sy(obj$height %||% 180))
          inner_x <- x + 10
          inner_y <- y + 34
          inner_w <- max(8, w - 20)
          inner_h <- max(8, h - 44)

          parts <- c(parts, sprintf(
            '<rect x="%.4f" y="%.4f" width="%.4f" height="%.4f" fill="%s" stroke="%s" stroke-width="%.3f" opacity="%.3f"/>',
            x, y, w, h,
            xml_escape(obj$fill %||% "#ffffff"),
            xml_escape(obj$stroke %||% "#495057"),
            max(0.5, safe_num(obj$strokeWidth, 2)),
            max(0.05, min(1, safe_num(obj$opacity, 0.95)))
          ))
          parts <- c(parts, sprintf(
            '<text x="%.4f" y="%.4f" fill="%s" font-size="%.3f" font-family="%s" font-weight="%s">%s</text>',
            x + 10, y + 24, xml_escape(obj$color %||% "#212529"), max(8, sy(20)),
            xml_escape(obj$fontFamily %||% "Segoe UI, PingFang SC, sans-serif"),
            xml_escape(obj$fontWeight %||% "600"),
            xml_escape(obj$title %||% "Inset")
          ))
          parts <- c(parts, sprintf(
            '<rect x="%.4f" y="%.4f" width="%.4f" height="%.4f" fill="#ffffff" stroke="#adb5bd" stroke-width="1"/>',
            inner_x, inner_y, inner_w, inner_h
          ))

          pts <- obj$points %||% list()
          for (p in pts) {
            px <- inner_x + max(0, min(1, safe_num(p$x, 0.5))) * inner_w
            py <- inner_y + (1 - max(0, min(1, safe_num(p$y, 0.5)))) * inner_h
            parts <- c(parts, sprintf(
              '<circle cx="%.4f" cy="%.4f" r="%.3f" fill="%s" fill-opacity="0.78"/>',
              px, py, max(1, safe_num(p$size, 2.2)),
              xml_escape(p$color %||% "#198754")
            ))
          }
          next
        }
      }

      parts <- c(parts, "</g>")
      paste(parts, collapse = "")
    }

    write_plot_svg <- function(plot_obj, file, width_in, height_in) {
      svglite::svglite(file, width = width_in, height = height_in, bg = "white")
      on.exit(grDevices::dev.off(), add = TRUE)
      if (inherits(plot_obj, "circos_plot")) {
        plot_obj$draw()
      } else {
        print(plot_obj)
      }
      invisible(file)
    }

    read_svg_dims <- function(svg_file, width_in, height_in) {
      doc <- xml2::read_xml(svg_file)
      root <- xml2::xml_root(doc)
      vb <- xml2::xml_attr(root, "viewBox")
      if (!is.null(vb) && nzchar(vb)) {
        nums <- suppressWarnings(as.numeric(strsplit(vb, "\\s+")[[1]]))
        if (length(nums) >= 4 && all(is.finite(nums[3:4]))) {
          return(list(width = nums[3], height = nums[4]))
        }
      }
      list(width = width_in * 72, height = height_in * 72)
    }

    merge_svg_with_overlay <- function(base_svg_file, overlay_group, out_svg_file) {
      doc <- xml2::read_xml(base_svg_file)
      root <- xml2::xml_root(doc)
      overlay_doc <- xml2::read_xml(paste0('<svg xmlns=\"http://www.w3.org/2000/svg\">', overlay_group, "</svg>"))
      overlay_nodes <- xml2::xml_children(xml2::xml_root(overlay_doc))
      for (node in overlay_nodes) {
        xml2::xml_add_child(root, node)
      }
      xml2::write_xml(doc, out_svg_file)
      invisible(out_svg_file)
    }

    active_data <- shared_active_data_reactive(input, rv)

    observeEvent(input$overlay_scene_json, {
      rv$overlay_scene_json <- input$overlay_scene_json %||% "[]"
    }, ignoreInit = FALSE)

    observeEvent(active_data(), {
      shared_pts <- build_shared_overlay_points(active_data())
      rv$overlay_shared_points <- shared_pts
      shared_json <- tryCatch(jsonlite::toJSON(shared_pts, auto_unbox = TRUE, null = "null"), error = function(e) "[]")
      if (!identical(shared_json, last_shared_points_json())) {
        last_shared_points_json(shared_json)
        session$sendCustomMessage("overlaySharedData", list(points = shared_pts))
      }
    }, ignoreInit = FALSE)

    observeEvent(list(input$overlay_data_source, input$overlay_extra_data_json), {
      source <- input$overlay_data_source %||% "shared"
      custom_json <- input$overlay_extra_data_json %||% ""
      cfg_json <- paste0(source, "::", custom_json)
      if (!identical(cfg_json, last_extra_cfg_json())) {
        last_extra_cfg_json(cfg_json)
        if (identical(source, "custom")) {
          parsed <- parse_custom_overlay_points(custom_json)
          session$sendCustomMessage("overlaySharedData", list(points = parsed))
        } else {
          session$sendCustomMessage("overlaySharedData", list(points = rv$overlay_shared_points %||% list()))
        }
        session$sendCustomMessage("overlayExtraDataConfig", list(source = source, json = custom_json))
      }
    }, ignoreInit = FALSE)

    observeEvent(input$overlay_tool, {
      session$sendCustomMessage("overlaySetTool", list(tool = input$overlay_tool %||% "select"))
    }, ignoreInit = FALSE)

    observeEvent(input$overlay_text_value, {
      session$sendCustomMessage("overlaySetText", list(text = input$overlay_text_value %||% "Label"))
    }, ignoreInit = FALSE)

    observeEvent(input$overlay_clear_btn, {
      rv$overlay_scene_json <- "[]"
      session$sendCustomMessage("overlayClear", list())
    })

    observeEvent(input$overlay_delete_btn, {
      session$sendCustomMessage("overlayDeleteSelected", list())
    })

    session$onFlushed(function() {
      scene_json <- isolate(rv$overlay_scene_json %||% "[]")
      tool <- isolate(input$overlay_tool %||% "select")
      text_val <- isolate(input$overlay_text_value %||% "Label")
      source <- isolate(input$overlay_data_source %||% "shared")
      custom_json <- isolate(input$overlay_extra_data_json %||% "")
      shared_points <- isolate(rv$overlay_shared_points %||% list())

      session$sendCustomMessage("overlayLoadScene", list(scene_json = scene_json))
      session$sendCustomMessage("overlaySetTool", list(tool = tool))
      session$sendCustomMessage("overlaySetText", list(text = text_val))
      session$sendCustomMessage("overlayExtraDataConfig", list(
        source = source,
        json = custom_json
      ))
      session$sendCustomMessage("overlaySharedData", list(points = shared_points))
    }, once = TRUE)

    build_combined_svg <- function(out_file) {
      req(rv$current_plot)

      dims <- shared_clamp_plot_dimensions(input$plot_width_in, input$plot_height_in, input$plot_dpi)
      w <- dims$plot_width_in
      h <- dims$plot_height_in

      scene_json <- input$overlay_scene_json %||% rv$overlay_scene_json %||% "[]"
      scene <- parse_overlay_scene(scene_json)

      tmp_base <- tempfile(fileext = ".svg")
      write_plot_svg(rv$current_plot, tmp_base, width_in = w, height_in = h)
      dims <- read_svg_dims(tmp_base, width_in = w, height_in = h)
      overlay_group <- scene_to_svg_group(scene, width = dims$width, height = dims$height)
      merge_svg_with_overlay(tmp_base, overlay_group, out_file)
      invisible(out_file)
    }

    output$download_combined_svg <- downloadHandler(
      filename = function() paste0(input$chart_type_select, "_", Sys.Date(), "_overlay.svg"),
      content = function(file) {
        build_combined_svg(file)
      }
    )

    output$download_combined_pdf <- downloadHandler(
      filename = function() paste0(input$chart_type_select, "_", Sys.Date(), "_overlay.pdf"),
      content = function(file) {
        if (!requireNamespace("rsvg", quietly = TRUE)) {
          showNotification("PDF+Overlay requires package 'rsvg'. Install with install.packages('rsvg').", type = "warning", duration = 6)
          stop("Combined PDF export requires package 'rsvg'. Install with install.packages('rsvg').")
        }
        tmp_svg <- tempfile(fileext = ".svg")
        build_combined_svg(tmp_svg)
        rsvg::rsvg_pdf(tmp_svg, file = file)
      }
    )

    invisible(NULL)
  }
})
