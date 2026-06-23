-- ~/.config/luakit/rc.lua
-- Pure WebKit – no extensions, GNOME Web simplicity.
-- Drop it, restart Luakit, start surfing.

-- ════════════════════════════════════════════════════════════════════
-- Core modules
-- ════════════════════════════════════════════════════════════════════
local lousy  = require("lousy")
local bind   = lousy.bind          -- local, not a bare global
local modes  = lousy.modes         -- local, not a bare global
local window = luakit.window       -- the real window class (not self-assign)

-- Search engine shortcuts in :open  (optional – guarded so removal is safe)
local search = (function()
  local ok, m = pcall(require, "search")
  return ok and m or nil
end)()

-- ════════════════════════════════════════════════════════════════════
-- 1. Modern-site compatibility
-- ════════════════════════════════════════════════════════════════════
lousy.util.table.merge(luakit.webview.settings, {
  user_agent      = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                 .. "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
  enable_javascript = true,
})

-- ════════════════════════════════════════════════════════════════════
-- 2. Look & Feel
-- ════════════════════════════════════════════════════════════════════
window.tabs_position          = "left"
window.tabs_width             = 200
window.tabs_show_close_buttons  = true
window.tabs_show_new_tab_button = true
window.title_format           = "%t – Web"
window.statusbar_format       = "%u"
window.menu_bar               = false
window.scrollbars             = false
window.home_page              = "about:blank"
window.new_tab_page           = "about:blank"

-- ════════════════════════════════════════════════════════════════════
-- 3. Keyboard shortcuts (vim-like, normal mode)
-- ════════════════════════════════════════════════════════════════════

-- Helper: scroll relative to the current view height (d / u keys)
local function half_page(w, dir)
  local h = w.view:get_scroll_height() or 600
  w.view:scroll { y = dir * math.floor(h / 2), relative = true }
end

modes.add_binds("normal", {
  -- ── Scrolling ────────────────────────────────────────────────────
  bind.key({}, "j", "Scroll down",
    function(w) w.view:scroll { y =  60, relative = true } end),
  bind.key({}, "k", "Scroll up",
    function(w) w.view:scroll { y = -60, relative = true } end),
  bind.key({}, "h", "Scroll left",
    function(w) w.view:scroll { x = -120, relative = true } end),
  bind.key({}, "l", "Scroll right",
    function(w) w.view:scroll { x =  120, relative = true } end),

  bind.key({}, "g", "Scroll to top", nil, {  -- two-key: gg
    bind.key({}, "g", "Scroll to top",
      function(w) w.view:scroll { y = 0 } end),
  }),
  bind.key({}, "G", "Scroll to bottom",
    function(w) w.view:scroll { y = 2^31 - 1 } end),   -- large sentinel = bottom

  bind.key({}, "d", "Scroll half-page down",
    function(w) half_page(w,  1) end),
  bind.key({}, "u", "Scroll half-page up",
    function(w) half_page(w, -1) end),

  -- ── Navigation ───────────────────────────────────────────────────
  bind.key({}, "r",  "Reload",           function(w) w:reload()       end),
  bind.key({}, "R",  "Hard reload",      function(w) w:reload(true)   end),
  bind.key({}, "H",  "Go back",          function(w) w:back()         end),
  bind.key({}, "L",  "Go forward",       function(w) w:forward()      end),
  bind.key({}, "g", nil, nil, {
    bind.key({}, "h", "Go home",
      function(w) w:navigate(window.home_page) end),
  }),

  -- ── Clipboard ────────────────────────────────────────────────────
  bind.key({}, "y", nil, nil, {
    bind.key({}, "y", "Yank URL",
      function(w) luakit.set_clipboard(w.view.uri or "") end),
  }),
  bind.key({}, "p", "Open clipboard URL",
    function(w)
      local url = luakit.get_clipboard()
      if url and url ~= "" then w:navigate(url) end
    end),
  bind.key({"Shift"}, "P", "Open clipboard URL in new tab",
    function(w)
      local url = luakit.get_clipboard()
      if url and url ~= "" then w:new_tab(url) end
    end),

  -- ── Tabs ─────────────────────────────────────────────────────────
  bind.key({}, "t",  "New tab",
    function(w) w:new_tab(window.home_page) end),
  bind.key({"Shift"}, "T", "New background tab",
    function(w) w:new_tab(window.home_page, { switch = false }) end),
  bind.key({}, "g", nil, nil, {
    bind.key({}, "t", "Next tab",     function(w) w:next_tab()     end),
    bind.key({"Shift"}, "T", "Prev tab", function(w) w:prev_tab()  end),
  }),
  bind.key({}, "x",  "Close tab",    function(w) w:close_tab()    end),

  -- ── Search ───────────────────────────────────────────────────────
  bind.key({}, "/",  "Start search", function(w) w:set_mode("search") end),
  bind.key({}, "n",  "Next match",   function(w) w:search_next()      end),
  bind.key({"Shift"}, "N", "Prev match", function(w) w:search_prev()  end),

  -- ── Zoom ─────────────────────────────────────────────────────────
  bind.key({}, "+",  "Zoom in",      function(w) w:zoom_in()          end),
  bind.key({}, "-",  "Zoom out",     function(w) w:zoom_out()         end),
  bind.key({}, "=",  "Reset zoom",   function(w) w:zoom_set(1.0)      end),
})

-- ════════════════════════════════════════════════════════════════════
-- 4. Search engines
-- ════════════════════════════════════════════════════════════════════
if search then
  search.engines = {
    google    = "https://www.google.com/search?q=%s",
    ddg       = "https://duckduckgo.com/?q=%s",
    yt        = "https://www.youtube.com/results?search_query=%s",
    github    = "https://github.com/search?q=%s",
    wikipedia = "https://en.wikipedia.org/wiki/Special:Search?search=%s",
  }
  search.default_engine = "ddg"
end

-- ════════════════════════════════════════════════════════════════════
-- 5. Per-view settings: media, DRM, MIME policy, smooth scroll
--    All view-level work goes in ONE page-created handler to avoid
--    ordering hazards and redundant signal registrations.
-- ════════════════════════════════════════════════════════════════════

-- MIME types that should be displayed inline instead of downloaded
local INLINE_MIME = {
  ["application/pdf"] = true,
  ["image/jpeg"]      = true,
  ["image/png"]       = true,
  ["image/webp"]      = true,
  ["image/gif"]       = true,
  ["image/svg+xml"]   = true,
}

luakit.window.add_signal("page-created", function(_, view)
  -- 5a. Media & DRM capabilities
  local s = view.settings
  s.enable_encrypted_media          = true
  s.enable_media_source             = true
  s.enable_webaudio                 = true
  s.enable_webgl                    = true
  s.enable_mediastream              = true
  s.enable_webrtc                   = true
  s.javascript_can_access_clipboard = true

  -- 5b. MIME-type policy (must be on the view, not the window class)
  view:add_signal("mime-type-policy", function(_, uri, mime)   -- luacheck: ignore uri
    if INLINE_MIME[mime] then
      return "allow"
    end
    return "use-default"
  end)

  -- 5c. Smooth scrolling via CSS – injected after DOM is ready
  view:add_signal("document-loaded", function()
    view:eval_js(
      "(function(){" ..
        "if(!document.head)return;" ..
        "var s=document.createElement('style');" ..
        "s.textContent='html{scroll-behavior:smooth}';" ..
        "document.head.appendChild(s);" ..
      "})()",
      { no_return = true }
    )
  end)
end)

-- ════════════════════════════════════════════════════════════════════
-- 6. Startup: restore session or open home page
-- ════════════════════════════════════════════════════════════════════
luakit.window.add_signal("init", function(w)
  -- load_session() returns true if tabs were restored
  if not w:load_session() then
    w:new_tab(window.home_page)
  end
end)

-- vim: ft=lua
