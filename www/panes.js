// Lightweight splitter + pane state manager for workspace + left sub-panes.
// Supports drag resize, minimize, maximize, and restore for both levels.

(function () {
  var DESKTOP_QUERY = window.matchMedia("(min-width: 992px)");
  var resizeSeq = 0;
  var resizeTimer = null;

  var PANE_IDS = ["pane-left", "pane-right-top", "pane-right-bottom"];
  var SUB_PANE_IDS = ["left-pane-chat", "left-pane-recommend"];

  var paneState = {
    collapsed: new Set(),
    maximized: null
  };

  var subPaneState = {
    collapsed: new Set(),
    maximized: null
  };

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
  }

  function notifyPaneResize() {
    if (!window.Shiny || !window.Shiny.setInputValue) return;
    resizeSeq += 1;
    window.Shiny.setInputValue("pane_resize_seq", resizeSeq, { priority: "event" });
  }

  function scheduleResizeNotification() {
    window.clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(notifyPaneResize, 140);
  }

  function initSplitter(rootId, handleId, options) {
    var root = document.getElementById(rootId);
    var handle = document.getElementById(handleId);
    if (!root || !handle) return;

    var dragging = false;

    function onPointerMove(event) {
      if (!dragging || !DESKTOP_QUERY.matches) return;

      var rect = root.getBoundingClientRect();
      var total = options.axis === "x" ? rect.width : rect.height;
      if (!total) return;

      var pointer = options.axis === "x"
        ? event.clientX - rect.left
        : event.clientY - rect.top;

      var minPrimaryPct = (options.minPrimaryPx / total) * 100;
      var maxPrimaryPct = 100 - ((options.minSecondaryPx / total) * 100);
      var nextPct = clamp((pointer / total) * 100, minPrimaryPct, maxPrimaryPct);

      root.style.setProperty(options.cssVar, nextPct.toFixed(2) + "%");
    }

    function stopDragging() {
      if (!dragging) return;
      dragging = false;
      document.body.classList.remove("pane-resizing");
      scheduleResizeNotification();
    }

    handle.addEventListener("pointerdown", function (event) {
      if (!DESKTOP_QUERY.matches) return;
      event.preventDefault();
      dragging = true;
      document.body.classList.add("pane-resizing");
      if (handle.setPointerCapture) {
        handle.setPointerCapture(event.pointerId);
      }
    });

    window.addEventListener("pointermove", onPointerMove);
    window.addEventListener("pointerup", stopDragging);
    window.addEventListener("pointercancel", stopDragging);
  }

  function classNameForPane(prefix, paneId) {
    return prefix + paneId;
  }

  function clearMainLayoutClasses(appShell) {
    appShell.classList.remove(
      "app-min-pane-left",
      "app-min-pane-right-top",
      "app-min-pane-right-bottom",
      "app-max-pane-left",
      "app-max-pane-right-top",
      "app-max-pane-right-bottom"
    );
  }

  function clearSubLayoutClasses(stack) {
    stack.classList.remove(
      "sub-min-left-pane-chat",
      "sub-min-left-pane-recommend",
      "sub-max-left-pane-chat",
      "sub-max-left-pane-recommend"
    );
  }

  function canCollapsePane(paneId) {
    if (paneId === "pane-right-top" && paneState.collapsed.has("pane-right-bottom")) return false;
    if (paneId === "pane-right-bottom" && paneState.collapsed.has("pane-right-top")) return false;
    return true;
  }

  function canCollapseSubPane(paneId) {
    if (paneId === "left-pane-chat" && subPaneState.collapsed.has("left-pane-recommend")) return false;
    if (paneId === "left-pane-recommend" && subPaneState.collapsed.has("left-pane-chat")) return false;
    return true;
  }

  function applyMainLayoutState() {
    var appShell = document.getElementById("app-shell");
    if (!appShell) return;

    clearMainLayoutClasses(appShell);

    if (paneState.maximized) {
      appShell.classList.add(classNameForPane("app-max-", paneState.maximized));
    } else {
      paneState.collapsed.forEach(function (paneId) {
        appShell.classList.add(classNameForPane("app-min-", paneId));
      });
    }
  }

  function applySubLayoutState() {
    var stack = document.getElementById("left-pane-stack");
    if (!stack) return;

    clearSubLayoutClasses(stack);

    if (subPaneState.maximized) {
      stack.classList.add(classNameForPane("sub-max-", subPaneState.maximized));
    } else {
      subPaneState.collapsed.forEach(function (paneId) {
        stack.classList.add(classNameForPane("sub-min-", paneId));
      });
    }
  }

  function syncButtons() {
    var mainDefault = paneState.collapsed.size === 0 && !paneState.maximized;
    var subDefault = subPaneState.collapsed.size === 0 && !subPaneState.maximized;
    var allDefault = mainDefault && subDefault;

    var buttons = document.querySelectorAll("[data-pane-action][data-pane-target]");
    buttons.forEach(function (btn) {
      var action = btn.getAttribute("data-pane-action");
      var target = btn.getAttribute("data-pane-target");
      if (!target) return;

      btn.classList.remove("is-active", "is-muted");

      if (action === "toggle-max" && PANE_IDS.indexOf(target) >= 0) {
        var isMaxMain = paneState.maximized === target;
        btn.classList.toggle("is-active", isMaxMain);
        btn.setAttribute("aria-pressed", isMaxMain ? "true" : "false");
      } else if (action === "toggle-min" && PANE_IDS.indexOf(target) >= 0) {
        var isMinMain = paneState.collapsed.has(target);
        var hiddenByMainMax = !!paneState.maximized && paneState.maximized !== target;
        btn.classList.toggle("is-active", isMinMain);
        btn.classList.toggle("is-muted", hiddenByMainMax && !isMinMain);
        btn.setAttribute("aria-pressed", isMinMain ? "true" : "false");
      } else if (action === "toggle-sub-max" && SUB_PANE_IDS.indexOf(target) >= 0) {
        var isMaxSub = subPaneState.maximized === target;
        btn.classList.toggle("is-active", isMaxSub);
        btn.setAttribute("aria-pressed", isMaxSub ? "true" : "false");
      } else if (action === "toggle-sub-min" && SUB_PANE_IDS.indexOf(target) >= 0) {
        var isMinSub = subPaneState.collapsed.has(target);
        var hiddenBySubMax = !!subPaneState.maximized && subPaneState.maximized !== target;
        btn.classList.toggle("is-active", isMinSub);
        btn.classList.toggle("is-muted", hiddenBySubMax && !isMinSub);
        btn.setAttribute("aria-pressed", isMinSub ? "true" : "false");
      }
    });

    var restoreButtons = document.querySelectorAll("[data-pane-action='restore-layout']");
    restoreButtons.forEach(function (btn) {
      btn.disabled = allDefault;
    });
  }

  function applyLayoutState() {
    applyMainLayoutState();
    applySubLayoutState();
    syncButtons();
    scheduleResizeNotification();
  }

  function toggleMainMin(paneId) {
    if (!paneId || PANE_IDS.indexOf(paneId) === -1) return;

    if (paneState.collapsed.has(paneId)) {
      paneState.collapsed.delete(paneId);
      applyLayoutState();
      return;
    }

    if (!canCollapsePane(paneId)) return;

    paneState.collapsed.add(paneId);
    if (paneState.maximized === paneId) paneState.maximized = null;
    applyLayoutState();
  }

  function toggleMainMax(paneId) {
    if (!paneId || PANE_IDS.indexOf(paneId) === -1) return;
    paneState.maximized = paneState.maximized === paneId ? null : paneId;
    applyLayoutState();
  }

  function toggleSubMin(paneId) {
    if (!paneId || SUB_PANE_IDS.indexOf(paneId) === -1) return;

    if (subPaneState.collapsed.has(paneId)) {
      subPaneState.collapsed.delete(paneId);
      applyLayoutState();
      return;
    }

    if (!canCollapseSubPane(paneId)) return;

    subPaneState.collapsed.add(paneId);
    if (subPaneState.maximized === paneId) subPaneState.maximized = null;
    applyLayoutState();
  }

  function toggleSubMax(paneId) {
    if (!paneId || SUB_PANE_IDS.indexOf(paneId) === -1) return;
    subPaneState.maximized = subPaneState.maximized === paneId ? null : paneId;
    applyLayoutState();
  }

  function restoreLayout() {
    paneState.maximized = null;
    paneState.collapsed.clear();
    subPaneState.maximized = null;
    subPaneState.collapsed.clear();
    applyLayoutState();
  }

  function bindPaneActionButtons() {
    document.addEventListener("click", function (event) {
      var btn = event.target.closest("[data-pane-action]");
      if (!btn) return;

      var action = btn.getAttribute("data-pane-action");
      var target = btn.getAttribute("data-pane-target");

      if (action === "toggle-min") {
        event.preventDefault();
        toggleMainMin(target);
      } else if (action === "toggle-max") {
        event.preventDefault();
        toggleMainMax(target);
      } else if (action === "toggle-sub-min") {
        event.preventDefault();
        toggleSubMin(target);
      } else if (action === "toggle-sub-max") {
        event.preventDefault();
        toggleSubMax(target);
      } else if (action === "restore-layout") {
        event.preventDefault();
        restoreLayout();
      }
    });
  }

  function initPaneLayout() {
    initSplitter("app-shell", "main-resizer", {
      axis: "x",
      cssVar: "--pane-left-width",
      minPrimaryPx: 320,
      minSecondaryPx: 420
    });

    initSplitter("workspace-shell", "workspace-resizer", {
      axis: "y",
      cssVar: "--pane-top-height",
      minPrimaryPx: 260,
      minSecondaryPx: 260
    });

    initSplitter("left-pane-stack", "left-pane-resizer", {
      axis: "y",
      cssVar: "--left-chat-height",
      minPrimaryPx: 180,
      minSecondaryPx: 120
    });

    bindPaneActionButtons();
    applyLayoutState();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initPaneLayout);
  } else {
    initPaneLayout();
  }

  window.addEventListener("resize", scheduleResizeNotification);
  if (DESKTOP_QUERY.addEventListener) {
    DESKTOP_QUERY.addEventListener("change", scheduleResizeNotification);
  } else if (DESKTOP_QUERY.addListener) {
    DESKTOP_QUERY.addListener(scheduleResizeNotification);
  }
})();
