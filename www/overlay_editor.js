(function () {
  const NS = "http://www.w3.org/2000/svg";

  const state = {
    scene: [],
    tool: "select",
    text: "Label",
    selectedId: null,
    nextId: 1,
    drag: null,
    resize: null,
    sharedPoints: [],
    dataSource: "shared",
    customJson: ""
  };

  function byId(id) { return document.getElementById(id); }
  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
  function toNum(v, fallback) { const n = Number(v); return Number.isFinite(n) ? n : fallback; }
  function mkId() { const id = "ov_" + state.nextId; state.nextId += 1; return id; }
  function getSvg() { return byId("overlay_svg"); }
  function deepClone(x) { try { return JSON.parse(JSON.stringify(x)); } catch (e) { return x; } }

  function toViewBox(evt, svg) {
    let rect = svg.getBoundingClientRect();
    if (!rect.width || !rect.height) {
      const host = byId("plot-overlay-host");
      if (host) rect = host.getBoundingClientRect();
    }
    if (!rect.width || !rect.height) return null;
    return {
      x: clamp(((evt.clientX - rect.left) / rect.width) * 1000, 0, 1000),
      y: clamp(((evt.clientY - rect.top) / rect.height) * 1000, 0, 1000)
    };
  }

  function findOverlayHit(evt) {
    const t = evt && evt.target;
    if (!t || typeof t.closest !== "function") return null;
    return t.closest(".overlay-item");
  }

  function findHandleHit(evt) {
    const t = evt && evt.target;
    if (!t || typeof t.closest !== "function") return null;
    return t.closest(".overlay-handle");
  }

  function parseHex(v, fallback) {
    const s = String(v || "").trim();
    return /^#[0-9a-fA-F]{6}$/.test(s) ? s : fallback;
  }

  function readStyleDefaults() {
    return {
      fill: parseHex((byId("overlay_fill_color") || {}).value, "#66c2ff"),
      stroke: parseHex((byId("overlay_stroke_color") || {}).value, "#0d6efd"),
      textColor: parseHex((byId("overlay_text_color") || {}).value, "#111111"),
      strokeWidth: clamp(toNum((byId("overlay_stroke_width") || {}).value, 2), 0.5, 20),
      opacity: clamp(toNum((byId("overlay_opacity") || {}).value, 0.85), 0.05, 1),
      fontSize: clamp(toNum((byId("overlay_font_size") || {}).value, 26), 8, 220),
      fontFamily: String((byId("overlay_font_family") || {}).value || "Segoe UI"),
      fontWeight: String((byId("overlay_font_weight") || {}).value || "600")
    };
  }

  function syncBasicControlsFromDom() {
    const toolInput = byId("overlay_tool");
    if (toolInput && toolInput.value) state.tool = toolInput.value;
    const textInput = byId("overlay_text_value");
    if (textInput) state.text = textInput.value || "Label";
    const svg = getSvg();
    if (svg) svg.dataset.tool = state.tool || "select";
  }

  function emitScene() {
    if (window.Shiny && window.Shiny.setInputValue) {
      window.Shiny.setInputValue("overlay_scene_json", JSON.stringify(state.scene), { priority: "event" });
      window.Shiny.setInputValue("overlay_selected_id", state.selectedId || "", { priority: "event" });
    }
  }

  function ensureArrowDefs(svg) {
    let defs = svg.querySelector("defs");
    if (!defs) { defs = document.createElementNS(NS, "defs"); svg.appendChild(defs); }
    if (!svg.querySelector("#overlay-arrow-head")) {
      const marker = document.createElementNS(NS, "marker");
      marker.setAttribute("id", "overlay-arrow-head");
      marker.setAttribute("markerWidth", "10");
      marker.setAttribute("markerHeight", "8");
      marker.setAttribute("refX", "9");
      marker.setAttribute("refY", "4");
      marker.setAttribute("orient", "auto");
      marker.setAttribute("markerUnits", "strokeWidth");
      const path = document.createElementNS(NS, "path");
      path.setAttribute("d", "M 0 0 L 10 4 L 0 8 z");
      path.setAttribute("fill", "#dc3545");
      marker.appendChild(path);
      defs.appendChild(marker);
    }
  }

  function normalizePoints(points) {
    const list = Array.isArray(points) ? points : [];
    const parsed = list.map((p) => {
      if (!p || typeof p !== "object") return null;
      const x = Number(p.x); const y = Number(p.y);
      if (!Number.isFinite(x) || !Number.isFinite(y)) return null;
      return {
        x,
        y,
        color: typeof p.color === "string" && p.color ? p.color : "#2c7be5",
        size: Number.isFinite(Number(p.size)) ? Number(p.size) : 3
      };
    }).filter(Boolean);

    if (!parsed.length) return [];
    const inUnit = parsed.every((p) => p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1);
    if (inUnit) return parsed;

    const xs = parsed.map((p) => p.x), ys = parsed.map((p) => p.y);
    const minX = Math.min.apply(null, xs), maxX = Math.max.apply(null, xs);
    const minY = Math.min.apply(null, ys), maxY = Math.max.apply(null, ys);
    const dx = Math.max(1e-9, maxX - minX), dy = Math.max(1e-9, maxY - minY);

    return parsed.map((p) => ({
      x: (p.x - minX) / dx,
      y: (p.y - minY) / dy,
      color: p.color,
      size: p.size
    }));
  }

  function parseCustomPoints(jsonText) {
    if (!jsonText || typeof jsonText !== "string") return [];
    try { return normalizePoints(JSON.parse(jsonText)); } catch (e) { return []; }
  }

  function activePoints() {
    if (state.dataSource === "custom") {
      const pts = parseCustomPoints(state.customJson);
      if (pts.length) return pts;
    }
    return state.sharedPoints || [];
  }

  function selectedObject() {
    if (!state.selectedId) return null;
    return state.scene.find((x) => x.id === state.selectedId) || null;
  }

  function setControlValue(id, value) {
    const el = byId(id);
    if (!el || value === null || typeof value === "undefined") return;
    const s = String(value);
    if (el.value !== s) el.value = s;
  }

  function syncStyleControlsFromSelected() {
    const obj = selectedObject();
    if (!obj) return;
    const d = readStyleDefaults();
    setControlValue("overlay_fill_color", parseHex(obj.fill, d.fill));
    setControlValue("overlay_stroke_color", parseHex(obj.stroke, d.stroke));
    setControlValue("overlay_stroke_width", clamp(toNum(obj.strokeWidth, d.strokeWidth), 0.5, 20));
    setControlValue("overlay_opacity", clamp(toNum(obj.opacity, d.opacity), 0.05, 1));
    setControlValue("overlay_text_color", parseHex(obj.color, d.textColor));
    setControlValue("overlay_font_size", clamp(toNum(obj.fontSize, d.fontSize), 8, 220));
    setControlValue("overlay_font_family", obj.fontFamily || d.fontFamily);
    setControlValue("overlay_font_weight", obj.fontWeight || d.fontWeight);
    if (obj.type === "text") {
      setControlValue("overlay_text_value", obj.text || "Label");
      state.text = obj.text || state.text;
    }
  }

  function setSelected(id) {
    state.selectedId = id || null;
    syncStyleControlsFromSelected();
  }

  function renderTriangle(g, obj) {
    const size = toNum(obj.size, 28), x = toNum(obj.x, 500), y = toNum(obj.y, 500);
    const pts = [
      `${x},${y - size}`,
      `${x - size * 0.85},${y + size * 0.65}`,
      `${x + size * 0.85},${y + size * 0.65}`
    ].join(" ");
    const poly = document.createElementNS(NS, "polygon");
    poly.setAttribute("points", pts);
    poly.setAttribute("fill", obj.fill || "#66c2ff");
    poly.setAttribute("stroke", obj.stroke || "#0d6efd");
    poly.setAttribute("stroke-width", String(toNum(obj.strokeWidth, 2)));
    poly.setAttribute("opacity", String(clamp(toNum(obj.opacity, 0.85), 0.05, 1)));
    g.appendChild(poly);
  }

  function renderRectLike(g, obj, fallback) {
    const el = document.createElementNS(NS, "rect");
    el.setAttribute("x", String(toNum(obj.x, fallback.x)));
    el.setAttribute("y", String(toNum(obj.y, fallback.y)));
    el.setAttribute("width", String(Math.max(8, toNum(obj.width, fallback.w))));
    el.setAttribute("height", String(Math.max(8, toNum(obj.height, fallback.h))));
    el.setAttribute("fill", obj.fill || fallback.fill);
    el.setAttribute("stroke", obj.stroke || fallback.stroke);
    el.setAttribute("stroke-width", String(toNum(obj.strokeWidth, fallback.strokeWidth)));
    el.setAttribute("opacity", String(clamp(toNum(obj.opacity, fallback.opacity), 0.05, 1)));
    if (fallback.dash) el.setAttribute("stroke-dasharray", fallback.dash);
    g.appendChild(el);
  }

  function renderArrow(g, obj) {
    const line = document.createElementNS(NS, "line");
    line.setAttribute("x1", String(toNum(obj.x1, 450)));
    line.setAttribute("y1", String(toNum(obj.y1, 550)));
    line.setAttribute("x2", String(toNum(obj.x2, 550)));
    line.setAttribute("y2", String(toNum(obj.y2, 450)));
    line.setAttribute("stroke", obj.stroke || "#dc3545");
    line.setAttribute("stroke-width", String(toNum(obj.strokeWidth, 3)));
    line.setAttribute("opacity", String(clamp(toNum(obj.opacity, 0.9), 0.05, 1)));
    line.setAttribute("marker-end", "url(#overlay-arrow-head)");
    line.setAttribute("stroke-linecap", "round");
    g.appendChild(line);
  }

  function renderText(g, obj) {
    const text = document.createElementNS(NS, "text");
    text.setAttribute("x", String(toNum(obj.x, 500)));
    text.setAttribute("y", String(toNum(obj.y, 500)));
    text.setAttribute("fill", obj.color || "#111111");
    text.setAttribute("font-size", String(toNum(obj.fontSize, 26)));
    text.setAttribute("font-family", obj.fontFamily || "Segoe UI");
    text.setAttribute("font-weight", String(obj.fontWeight || "600"));
    text.setAttribute("opacity", String(clamp(toNum(obj.opacity, 1), 0.05, 1)));
    text.textContent = obj.text || "Label";
    g.appendChild(text);
  }

  function renderExtraData(g, obj) {
    renderRectLike(g, obj, {
      x: 430, y: 430, w: 220, h: 150,
      fill: "#ffffff", stroke: "#6c757d", strokeWidth: 1.5, opacity: 0.95, dash: "5 5"
    });

    const x = toNum(obj.x, 430), y = toNum(obj.y, 430);
    const w = Math.max(20, toNum(obj.width, 220)), h = Math.max(20, toNum(obj.height, 150));
    const pts = Array.isArray(obj.points) ? obj.points : [];

    pts.forEach((p) => {
      const cx = x + clamp(toNum(p.x, 0.5), 0, 1) * w;
      const cy = y + (1 - clamp(toNum(p.y, 0.5), 0, 1)) * h;
      const c = document.createElementNS(NS, "circle");
      c.setAttribute("cx", String(cx));
      c.setAttribute("cy", String(cy));
      c.setAttribute("r", String(Math.max(1, toNum(p.size, 3))));
      c.setAttribute("fill", p.color || "#2c7be5");
      c.setAttribute("fill-opacity", "0.8");
      g.appendChild(c);
    });
  }

  function renderInset(g, obj) {
    const x = toNum(obj.x, 420), y = toNum(obj.y, 380);
    const w = Math.max(40, toNum(obj.width, 260)), h = Math.max(40, toNum(obj.height, 180));

    renderRectLike(g, obj, {
      x: 420, y: 380, w: 260, h: 180,
      fill: "#ffffff", stroke: "#495057", strokeWidth: 2, opacity: 0.95
    });

    const ttl = document.createElementNS(NS, "text");
    ttl.setAttribute("x", String(x + 10));
    ttl.setAttribute("y", String(y + 24));
    ttl.setAttribute("class", "overlay-inset-title");
    ttl.setAttribute("fill", obj.color || "#212529");
    ttl.setAttribute("font-family", obj.fontFamily || "Segoe UI");
    ttl.setAttribute("font-weight", String(obj.fontWeight || "600"));
    ttl.textContent = obj.title || "Inset";
    g.appendChild(ttl);

    const innerX = x + 10, innerY = y + 34;
    const innerW = w - 20, innerH = h - 44;
    const inner = document.createElementNS(NS, "rect");
    inner.setAttribute("x", String(innerX));
    inner.setAttribute("y", String(innerY));
    inner.setAttribute("width", String(innerW));
    inner.setAttribute("height", String(innerH));
    inner.setAttribute("fill", "#ffffff");
    inner.setAttribute("stroke", "#adb5bd");
    inner.setAttribute("stroke-width", "1");
    g.appendChild(inner);

    const pts = Array.isArray(obj.points) ? obj.points : [];
    pts.slice(0, 120).forEach((p) => {
      const cx = innerX + clamp(toNum(p.x, 0.5), 0, 1) * innerW;
      const cy = innerY + (1 - clamp(toNum(p.y, 0.5), 0, 1)) * innerH;
      const c = document.createElementNS(NS, "circle");
      c.setAttribute("cx", String(cx));
      c.setAttribute("cy", String(cy));
      c.setAttribute("r", String(Math.max(1, toNum(p.size, 2.2))));
      c.setAttribute("fill", p.color || "#198754");
      c.setAttribute("fill-opacity", "0.78");
      g.appendChild(c);
    });
  }

  function objectBounds(obj) {
    if (!obj) return null;
    if (obj.type === "arrow") {
      const x1 = toNum(obj.x1, 450), y1 = toNum(obj.y1, 550);
      const x2 = toNum(obj.x2, 550), y2 = toNum(obj.y2, 450);
      const minX = Math.min(x1, x2), minY = Math.min(y1, y2);
      const maxX = Math.max(x1, x2), maxY = Math.max(y1, y2);
      return { x: minX - 8, y: minY - 8, width: Math.max(16, maxX - minX + 16), height: Math.max(16, maxY - minY + 16) };
    }
    if (obj.type === "triangle") {
      const x = toNum(obj.x, 500), y = toNum(obj.y, 500), s = Math.max(8, toNum(obj.size, 30));
      return { x: x - s * 0.9, y: y - s, width: s * 1.8, height: s * 1.7 };
    }
    if (obj.type === "text") {
      const t = String(obj.text || "Label");
      const fs = Math.max(8, toNum(obj.fontSize, 26));
      const x = toNum(obj.x, 500), y = toNum(obj.y, 500);
      return { x: x, y: y - fs, width: Math.max(24, t.length * fs * 0.62), height: fs * 1.25 };
    }
    if (obj.type === "rect" || obj.type === "extra_data" || obj.type === "inset") {
      return {
        x: toNum(obj.x, 450),
        y: toNum(obj.y, 450),
        width: Math.max(8, toNum(obj.width, 90)),
        height: Math.max(8, toNum(obj.height, 60))
      };
    }
    return null;
  }

  function addHandle(svg, x, y, oid, handleName, size) {
    const hs = size || 11;
    const h = document.createElementNS(NS, "rect");
    h.setAttribute("x", String(x - hs / 2));
    h.setAttribute("y", String(y - hs / 2));
    h.setAttribute("width", String(hs));
    h.setAttribute("height", String(hs));
    h.setAttribute("class", "overlay-handle");
    h.setAttribute("data-oid", oid);
    h.setAttribute("data-handle", handleName);
    svg.appendChild(h);
  }

  function renderSelectionDecor(svg) {
    if ((state.tool || "select") !== "select") return;
    const obj = selectedObject();
    if (!obj) return;
    const b = objectBounds(obj);
    if (!b) return;

    const box = document.createElementNS(NS, "rect");
    box.setAttribute("x", String(b.x));
    box.setAttribute("y", String(b.y));
    box.setAttribute("width", String(b.width));
    box.setAttribute("height", String(b.height));
    box.setAttribute("class", "overlay-selection-box");
    svg.appendChild(box);

    if (obj.type === "arrow") {
      addHandle(svg, toNum(obj.x1, 450), toNum(obj.y1, 550), obj.id, "p1", 11);
      addHandle(svg, toNum(obj.x2, 550), toNum(obj.y2, 450), obj.id, "p2", 11);
      return;
    }

    if (obj.type === "triangle" || obj.type === "text") {
      addHandle(svg, b.x + b.width, b.y + b.height, obj.id, "se", 11);
      return;
    }

    addHandle(svg, b.x, b.y, obj.id, "nw", 11);
    addHandle(svg, b.x + b.width, b.y, obj.id, "ne", 11);
    addHandle(svg, b.x, b.y + b.height, obj.id, "sw", 11);
    addHandle(svg, b.x + b.width, b.y + b.height, obj.id, "se", 11);
  }

  function renderScene() {
    const svg = getSvg();
    if (!svg) return;

    svg.dataset.tool = state.tool || "select";
    while (svg.firstChild) svg.removeChild(svg.firstChild);
    ensureArrowDefs(svg);

    const hitPad = document.createElementNS(NS, "rect");
    hitPad.setAttribute("x", "0");
    hitPad.setAttribute("y", "0");
    hitPad.setAttribute("width", "1000");
    hitPad.setAttribute("height", "1000");
    hitPad.setAttribute("fill", "transparent");
    hitPad.setAttribute("class", "overlay-hit-pad");
    svg.appendChild(hitPad);

    state.scene.forEach((obj) => {
      if (!obj || !obj.id) return;
      const g = document.createElementNS(NS, "g");
      g.setAttribute("class", "overlay-item" + (obj.id === state.selectedId ? " is-selected" : ""));
      g.setAttribute("data-oid", obj.id);

      switch (obj.type) {
        case "triangle": renderTriangle(g, obj); break;
        case "rect": renderRectLike(g, obj, { x: 460, y: 460, w: 90, h: 60, fill: "#66c2ff", stroke: "#0d6efd", strokeWidth: 2, opacity: 0.85 }); break;
        case "arrow": renderArrow(g, obj); break;
        case "text": renderText(g, obj); break;
        case "extra_data": renderExtraData(g, obj); break;
        case "inset": renderInset(g, obj); break;
        default: return;
      }
      svg.appendChild(g);
    });

    renderSelectionDecor(svg);
  }

  function moveObject(obj, dx, dy) {
    if (!obj) return;
    if (obj.type === "arrow") {
      obj.x1 = clamp(toNum(obj.x1, 0) + dx, 0, 1000);
      obj.y1 = clamp(toNum(obj.y1, 0) + dy, 0, 1000);
      obj.x2 = clamp(toNum(obj.x2, 0) + dx, 0, 1000);
      obj.y2 = clamp(toNum(obj.y2, 0) + dy, 0, 1000);
      return;
    }

    if (obj.type === "triangle" || obj.type === "text") {
      obj.x = clamp(toNum(obj.x, 0) + dx, 0, 1000);
      obj.y = clamp(toNum(obj.y, 0) + dy, 0, 1000);
      return;
    }

    obj.x = clamp(toNum(obj.x, 0) + dx, 0, 1000);
    obj.y = clamp(toNum(obj.y, 0) + dy, 0, 1000);
  }

  function applyRectResize(obj, snap, handle, dx, dy, minW, minH) {
    let x = toNum(snap.x, 0), y = toNum(snap.y, 0);
    let w = Math.max(minW, toNum(snap.width, minW));
    let h = Math.max(minH, toNum(snap.height, minH));

    if (handle.indexOf("e") >= 0) w += dx;
    if (handle.indexOf("s") >= 0) h += dy;
    if (handle.indexOf("w") >= 0) { x += dx; w -= dx; }
    if (handle.indexOf("n") >= 0) { y += dy; h -= dy; }

    if (w < minW) { if (handle.indexOf("w") >= 0) x -= (minW - w); w = minW; }
    if (h < minH) { if (handle.indexOf("n") >= 0) y -= (minH - h); h = minH; }

    x = clamp(x, 0, 1000 - minW);
    y = clamp(y, 0, 1000 - minH);
    w = clamp(w, minW, 1000 - x);
    h = clamp(h, minH, 1000 - y);

    obj.x = x; obj.y = y; obj.width = w; obj.height = h;
  }

  function applyResize(pos) {
    if (!state.resize) return false;
    const item = state.resize;
    const obj = state.scene.find((x) => x.id === item.id);
    if (!obj) return false;

    const snap = item.snapshot;
    const dx = pos.x - item.startX;
    const dy = pos.y - item.startY;
    const handle = item.handle;

    if (obj.type === "arrow") {
      if (handle === "p1") {
        obj.x1 = clamp(pos.x, 0, 1000); obj.y1 = clamp(pos.y, 0, 1000);
      } else if (handle === "p2") {
        obj.x2 = clamp(pos.x, 0, 1000); obj.y2 = clamp(pos.y, 0, 1000);
      }
      return true;
    }

    if (obj.type === "triangle") {
      const cx = toNum(snap.x, 500), cy = toNum(snap.y, 500);
      const dist = Math.sqrt(Math.pow(pos.x - cx, 2) + Math.pow(pos.y - cy, 2));
      obj.size = clamp(dist * 0.9, 8, 400);
      return true;
    }

    if (obj.type === "text") {
      const base = Math.max(8, toNum(snap.fontSize, 26));
      obj.fontSize = clamp(base + dy * 0.35 + dx * 0.15, 8, 220);
      return true;
    }

    if (obj.type === "rect") {
      applyRectResize(obj, snap, handle, dx, dy, 12, 12);
      return true;
    }

    if (obj.type === "extra_data") {
      applyRectResize(obj, snap, handle, dx, dy, 40, 30);
      return true;
    }

    if (obj.type === "inset") {
      applyRectResize(obj, snap, handle, dx, dy, 70, 50);
      return true;
    }

    return false;
  }

  function buildObjectFromClick(tool, pos) {
    const id = mkId();
    const d = readStyleDefaults();

    if (tool === "triangle") {
      return { id, type: "triangle", x: pos.x, y: pos.y, size: 30, fill: d.fill, stroke: d.stroke, strokeWidth: d.strokeWidth, opacity: d.opacity };
    }
    if (tool === "rect") {
      return { id, type: "rect", x: pos.x - 45, y: pos.y - 30, width: 90, height: 60, fill: d.fill, stroke: d.stroke, strokeWidth: d.strokeWidth, opacity: d.opacity };
    }
    if (tool === "arrow") {
      return { id, type: "arrow", x1: pos.x - 55, y1: pos.y + 45, x2: pos.x + 55, y2: pos.y - 45, stroke: d.stroke, strokeWidth: Math.max(1, d.strokeWidth), opacity: d.opacity };
    }
    if (tool === "text") {
      const txt = (state.text || "Label").trim();
      return {
        id,
        type: "text",
        x: pos.x,
        y: pos.y,
        text: txt || "Label",
        color: d.textColor,
        fontSize: d.fontSize,
        fontFamily: d.fontFamily,
        fontWeight: d.fontWeight,
        opacity: d.opacity
      };
    }
    if (tool === "extra_data") {
      const pts = activePoints();
      return { id, type: "extra_data", x: pos.x - 110, y: pos.y - 75, width: 220, height: 150, fill: "#ffffff", stroke: d.stroke, strokeWidth: Math.max(1, d.strokeWidth), opacity: 0.95, points: pts.slice(0, 180) };
    }
    if (tool === "inset") {
      const pts = activePoints();
      return { id, type: "inset", x: pos.x - 130, y: pos.y - 90, width: 260, height: 180, title: "Inset", color: d.textColor, fontFamily: d.fontFamily, fontWeight: d.fontWeight, fill: "#ffffff", stroke: d.stroke, strokeWidth: Math.max(1, d.strokeWidth), opacity: 0.95, points: pts.slice(0, 120) };
    }
    return null;
  }

  function applyStyleFromControlsToSelected() {
    const obj = selectedObject();
    if (!obj) return;
    const d = readStyleDefaults();

    if (obj.type === "triangle" || obj.type === "rect") {
      obj.fill = d.fill; obj.stroke = d.stroke; obj.strokeWidth = d.strokeWidth; obj.opacity = d.opacity;
    } else if (obj.type === "arrow") {
      obj.stroke = d.stroke; obj.strokeWidth = Math.max(1, d.strokeWidth); obj.opacity = d.opacity;
    } else if (obj.type === "text") {
      obj.color = d.textColor; obj.fontSize = d.fontSize; obj.fontFamily = d.fontFamily; obj.fontWeight = d.fontWeight; obj.opacity = d.opacity;
    } else if (obj.type === "extra_data" || obj.type === "inset") {
      obj.stroke = d.stroke; obj.strokeWidth = Math.max(1, d.strokeWidth); obj.opacity = d.opacity;
      if (obj.type === "inset") {
        obj.color = d.textColor; obj.fontFamily = d.fontFamily; obj.fontWeight = d.fontWeight;
      }
    }

    renderScene();
    emitScene();
  }

  function onPointerDown(evt) {
    if (!evt || evt.__overlayHandled) return;
    evt.__overlayHandled = true;

    syncBasicControlsFromDom();
    const svg = getSvg();
    if (!svg) return;

    const pos = toViewBox(evt, svg);
    if (!pos) return;

    if (state.tool === "select") {
      const handleHit = findHandleHit(evt);
      if (handleHit) {
        const oid = handleHit.getAttribute("data-oid");
        const handle = handleHit.getAttribute("data-handle");
        const obj = state.scene.find((x) => x.id === oid);
        if (obj && handle) {
          setSelected(oid);
          state.resize = { id: oid, handle, startX: pos.x, startY: pos.y, snapshot: deepClone(obj) };
          renderScene();
          emitScene();
          return;
        }
      }

      const hit = findOverlayHit(evt);
      if (hit) {
        const id = hit.getAttribute("data-oid");
        setSelected(id);
        state.drag = { id, x: pos.x, y: pos.y };
      } else {
        setSelected(null);
      }
      renderScene();
      emitScene();
      return;
    }

    evt.preventDefault();
    const obj = buildObjectFromClick(state.tool, pos);
    if (!obj) return;
    state.scene.push(obj);
    setSelected(obj.id);
    renderScene();
    emitScene();
  }

  function onPointerMove(evt) {
    const svg = getSvg();
    if (!svg) return;
    const pos = toViewBox(evt, svg);
    if (!pos) return;

    if (state.resize) {
      const changed = applyResize(pos);
      if (changed) { renderScene(); emitScene(); }
      return;
    }

    if (!state.drag) return;
    const dx = pos.x - state.drag.x;
    const dy = pos.y - state.drag.y;
    if (!dx && !dy) return;

    const obj = state.scene.find((x) => x.id === state.drag.id);
    if (!obj) return;

    moveObject(obj, dx, dy);
    state.drag.x = pos.x;
    state.drag.y = pos.y;
    renderScene();
    emitScene();
  }

  function onPointerUp() {
    state.drag = null;
    state.resize = null;
  }

  function loadSceneFromJson(sceneJson) {
    let arr = [];
    if (typeof sceneJson === "string" && sceneJson.trim()) {
      try {
        const parsed = JSON.parse(sceneJson);
        if (Array.isArray(parsed)) arr = parsed;
      } catch (e) {
        arr = [];
      }
    }

    state.scene = arr
      .filter((o) => o && typeof o === "object" && typeof o.type === "string")
      .map((o) => {
        const cloned = Object.assign({}, o);
        if (!cloned.id) cloned.id = mkId();
        return cloned;
      });

    const maxSeq = state.scene
      .map((o) => {
        const m = String(o.id || "").match(/^ov_(\d+)$/);
        return m ? Number(m[1]) : 0;
      })
      .reduce((a, b) => Math.max(a, b), 0);

    state.nextId = Math.max(state.nextId, maxSeq + 1);
    state.selectedId = null;
    renderScene();
    emitScene();
  }

  function deleteSelected() {
    if (!state.selectedId) return;
    state.scene = state.scene.filter((o) => o.id !== state.selectedId);
    state.selectedId = null;
    renderScene();
    emitScene();
  }

  function onKeyDown(evt) {
    if (!evt) return;
    const tag = ((evt.target && evt.target.tagName) || "").toLowerCase();
    const typing = tag === "input" || tag === "textarea" || (evt.target && evt.target.isContentEditable);
    if (typing) return;
    if ((evt.key === "Delete" || evt.key === "Backspace") && state.selectedId) {
      evt.preventDefault();
      deleteSelected();
    }
  }

  function bindControlListeners() {
    const toolInput = byId("overlay_tool");
    if (toolInput && !toolInput.__overlayBound) {
      toolInput.__overlayBound = true;
      toolInput.addEventListener("change", function () {
        state.tool = toolInput.value || "select";
        const svg = getSvg();
        if (svg) svg.dataset.tool = state.tool;
      });
    }

    const textInput = byId("overlay_text_value");
    if (textInput && !textInput.__overlayBound) {
      textInput.__overlayBound = true;
      textInput.addEventListener("input", function () {
        state.text = textInput.value || "Label";
        const obj = selectedObject();
        if (obj && obj.type === "text") {
          obj.text = state.text || "Label";
          renderScene();
          emitScene();
        }
      });
    }

    [
      "overlay_fill_color",
      "overlay_stroke_color",
      "overlay_stroke_width",
      "overlay_opacity",
      "overlay_font_size",
      "overlay_font_family",
      "overlay_font_weight",
      "overlay_text_color"
    ].forEach(function (id) {
      const el = byId(id);
      if (!el || el.__overlayBound) return;
      el.__overlayBound = true;
      el.addEventListener("change", applyStyleFromControlsToSelected);
      el.addEventListener("input", applyStyleFromControlsToSelected);
    });
  }

  function init() {
    const svg = getSvg();
    if (!svg) {
      window.setTimeout(init, 220);
      return;
    }
    if (svg.__overlayInitDone) return;
    svg.__overlayInitDone = true;

    const host = byId("plot-overlay-host");
    syncBasicControlsFromDom();
    bindControlListeners();

    svg.dataset.ready = "1";
    svg.dataset.tool = state.tool;

    if (host && !host.__overlayBound) {
      host.__overlayBound = true;
      host.style.touchAction = "none";
      host.addEventListener("pointerdown", onPointerDown, true);
    }

    svg.addEventListener("pointerdown", onPointerDown);
    window.addEventListener("pointermove", onPointerMove);
    window.addEventListener("pointerup", onPointerUp);
    window.addEventListener("keydown", onKeyDown);

    renderScene();
    emitScene();
  }

  function registerHandlers() {
    if (!(window.Shiny && window.Shiny.addCustomMessageHandler)) return false;
    if (window.__overlayHandlersRegistered) return true;
    window.__overlayHandlersRegistered = true;

    window.Shiny.addCustomMessageHandler("overlaySetTool", function (msg) {
      state.tool = (msg && msg.tool) || "select";
      const toolInput = byId("overlay_tool");
      if (toolInput) toolInput.value = state.tool;
      const svg = getSvg();
      if (svg) svg.dataset.tool = state.tool;
    });

    window.Shiny.addCustomMessageHandler("overlaySetText", function (msg) {
      state.text = (msg && typeof msg.text === "string") ? msg.text : "Label";
      const textInput = byId("overlay_text_value");
      if (textInput) textInput.value = state.text;
    });

    window.Shiny.addCustomMessageHandler("overlaySharedData", function (msg) {
      state.sharedPoints = normalizePoints((msg && msg.points) || []);
      renderScene();
    });

    window.Shiny.addCustomMessageHandler("overlayExtraDataConfig", function (msg) {
      state.dataSource = (msg && msg.source) || "shared";
      state.customJson = (msg && msg.json) || "";
    });

    window.Shiny.addCustomMessageHandler("overlayClear", function () {
      state.scene = [];
      state.selectedId = null;
      renderScene();
      emitScene();
    });

    window.Shiny.addCustomMessageHandler("overlayDeleteSelected", function () {
      deleteSelected();
    });

    window.Shiny.addCustomMessageHandler("overlayLoadScene", function (msg) {
      loadSceneFromJson((msg && msg.scene_json) || "[]");
    });

    return true;
  }

  if (!registerHandlers()) {
    document.addEventListener("shiny:connected", function () {
      registerHandlers();
    }, { once: false });

    const retry = function () {
      if (window.__overlayHandlersRegistered) return;
      registerHandlers();
      window.setTimeout(retry, 400);
    };
    window.setTimeout(retry, 400);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  document.addEventListener("shiny:idle", function () {
    const svg = getSvg();
    if (svg && !svg.__overlayInitDone) init();
    bindControlListeners();
  });
})();
