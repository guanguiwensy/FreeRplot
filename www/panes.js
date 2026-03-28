// Lightweight splitter support for the IDE-style workspace layout.
// Drag updates pane sizes live; plot redraw is triggered only on drag end.

(function () {
  var DESKTOP_QUERY = window.matchMedia("(min-width: 992px)");
  var resizeSeq = 0;
  var resizeTimer = null;

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

    scheduleResizeNotification();
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
