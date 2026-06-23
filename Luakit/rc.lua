-- ~/.config/luakit/rc.lua
-- Pure WebKit – no extensions, GNOME Web simplicity.
-- Drop it, restart Luakit, start surfing.

-- Only the built‑in lousy module for keybindings.
-- No adblock, no tabgroup, no styles, no follow, no extra plugins.
local lousy = require("lousy")
window = window
bind = lousy.bind
modes = lousy.modes

-- (Optional) Use the search module to get engine shortcuts in :open.
-- If you remove this line, you can still use full URLs.
local search = require("search")

-- ------------------------------------------------------------------
-- 1. Make modern sites work instantly
-- ------------------------------------------------------------------
window.user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
window.enable_javascript = true

-- ------------------------------------------------------------------
-- 2. Look & Feel – clean like GNOME Web
-- ------------------------------------------------------------------
window.tabs_position = "left"
window.tabs_width = 200
window.tabs_show_close_buttons = true
window.tabs_show_new_tab_button = true
window.title_format = "%t – Web"
window.statusbar_format = "%u"               -- only URL, nothing else
window.menu_bar = false
window.scrollbars = false
window.home_page = "about:blank"
window.new_tab_page = "about:blank"

-- ------------------------------------------------------------------
-- 3. Keyboard shortcuts (vim‑like, normal mode)
-- ------------------------------------------------------------------
local function scroll(pixels)
  return function(w) w.view:scroll { y = pixels, relative = true } end
end
bind("n", "j", scroll(60))
bind("n", "k", scroll(-60))
bind("n", "h", function(w) w.view:scroll { x = -120, relative = true } end)
bind("n", "l", function(w) w.view:scroll { x = 120, relative = true } end)
bind("n", "gg", function(w) w.view:scroll { y = 0 } end)
bind("n", "G",  function(w) w.view:scroll { y = -1 } end)
bind("n", "d",  function(w) w.view:scroll { y = window.page_height / 2, relative = true } end)
bind("n", "u",  function(w) w.view:scroll { y = -window.page_height / 2, relative = true } end)

bind("n", "r",  function(w) w:reload() end)
bind("n", "R",  function(w) w:reload(true) end)
bind("n", "H",  function(w) w:go_back() end)
bind("n", "L",  function(w) w:go_forward() end)
bind("n", "gh", function(w) w:open(window.home_page) end)

bind("n", "yy", function(w) w:set_clipboard(w.view.uri) end)
bind("n", "p",  function(w) w:open_paste() end)
bind("n", "P",  function(w) w:open_paste(true) end)

bind("n", "t",  function(w) w:new_tab(window.home_page) end)
bind("n", "T",  function(w) w:new_tab(window.home_page, false) end)
bind("n", "gt", function(w) w:next_tab() end)
bind("n", "gT", function(w) w:previous_tab() end)
bind("n", "x",  function(w) w:close_tab() end)

bind("n", "/", function(w) w:set_mode("search") end)
bind("n", "n", function(w) w:search_next() end)
bind("n", "N", function(w) w:search_prev() end)

bind("n", "+", function(w) w:zoom_in() end)
bind("n", "-", function(w) w:zoom_out() end)
bind("n", "=", function(w) w:zoom_set(1.0) end)

-- ------------------------------------------------------------------
-- 4. Search engines (used by :open)
-- ------------------------------------------------------------------
search.engines = {
  google    = "https://www.google.com/search?q=%s",
  ddg       = "https://duckduckgo.com/?q=%s",
  yt        = "https://www.youtube.com/results?search_query=%s",
  github    = "https://github.com/search?q=%s",
  wikipedia = "https://en.wikipedia.org/wiki/Special:Search?search=%s",
}
search.default_engine = "ddg"

-- ------------------------------------------------------------------
-- 5. Preview PDFs / images directly – no download dialog
-- ------------------------------------------------------------------
window.add_signal("mime-type-policy", function(w, uri, mime)
  local inline_types = {
    ["application/pdf"] = true,
    ["image/jpeg"] = true,
    ["image/png"] = true,
    ["image/webp"] = true,
  }
  if inline_types[mime] then
    return "allow"        -- show inside the web view
  end
  return "use-default"    -- normal download prompt for everything else
end)

-- ------------------------------------------------------------------
-- 6. Make YouTube, Netflix, etc. play instantly
-- ------------------------------------------------------------------
window.add_signal("init", function(w)
  -- Enable DRM, media source extensions, WebGL – all pure WebKit.
  local s = w.view.settings
  s.enable_encrypted_media = true
  s.enable_media_source = true
  s.enable_webaudio = true
  s.enable_webgl = true
  s.enable_mediastream = true
  s.enable_webrtc = true
  s.javascript_can_access_clipboard = true

  if not w:load_session() then
    w:new_tab(window.home_page)
  end
end)

-- Re‑apply media settings for every new page
window.add_signal("page-created", function(w, view)
  local s = view.settings
  s.enable_encrypted_media = true
  s.enable_media_source = true
  s.enable_webaudio = true
  s.enable_webgl = true
end)

-- ------------------------------------------------------------------
-- 7. Smooth scrolling (one small CSS injection)
-- ------------------------------------------------------------------
window.add_signal("page-created", function(w, view)
  view:eval_js([[
    (function() {
      var css = document.createElement('style');
      css.textContent = 'html { scroll-behavior: smooth; }';
      document.head.appendChild(css);
    })();
  ]], { no_return = true })
end)

-- vim: ft=lua
