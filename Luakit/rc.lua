-- ~/.config/luakit/rc.lua
-- Super Browser — GNOME Web aesthetic, all features, KISS.

-- ---------------------------------------------------------------------------
-- 1. Load modules
-- ---------------------------------------------------------------------------
local lousy = require("lousy")
local tabgroup = require("tabgroup")
local adblock = require("adblock")
local styles = require("styles")
local follow = require("follow")
local downloads = require("downloads")
local bookmarks = require("bookmarks")
local sql_webhistory = require("sql_webhistory")
local search = require("search")

-- Optional modules
local quickmarks = pcall(require, "quickmarks") and require("quickmarks") or nil
local user_scripts = pcall(require, "user_scripts") and require("user_scripts") or nil
local undo = pcall(require, "undo") and require("undo") or nil

-- Show command suggestions automatically (press Tab if needed)
pcall(function()
  local completion = require("completion")
  completion.show_list = true
end)

window = window
bind = lousy.bind
modes = lousy.modes

-- ---------------------------------------------------------------------------
-- 2. Look & Feel – GNOME Web style
-- ---------------------------------------------------------------------------
window.tabs_position = "left"
window.tabs_width = 200
window.tabs_show_close_buttons = true
window.tabs_show_new_tab_button = true
window.title_format = "%t – Web"
window.statusbar_format = "[%m] %t/%T | %p | %u"
window.menu_bar = false
window.scrollbars = false
window.home_page = "about:home"
window.new_tab_page = "about:home"
window.context_menu = true
window.middle_click_open_new_tab = true

-- ---------------------------------------------------------------------------
-- 3. Downloads
-- ---------------------------------------------------------------------------
os.execute("mkdir -p " .. os.getenv("HOME") .. "/downloads")
downloads.default_dir = os.getenv("HOME") .. "/downloads"
downloads.add_signal("download-created", function(d)
  window:notify("Downloading: " .. d.filename, "info")
end)

-- ---------------------------------------------------------------------------
-- 4. Privacy & Adblock (daily auto‑update)
-- ---------------------------------------------------------------------------
adblock.load_dir(lousy.util.find_data_dir("adblock"))
adblock.sources = {
  "https://easylist.to/easylist/easylist.txt",
  "https://easylist.to/easylist/easyprivacy.txt",
  "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",
}
adblock.update()

window.set_policy("cookie-accept", "no-third-party")

local last_update = os.time()
window.add_signal("periodic-save", function()
  if os.difftime(os.time(), last_update) > 86400 then
    adblock.update()
    last_update = os.time()
  end
end)

-- ---------------------------------------------------------------------------
-- 5. Dark mode toggle (<Ctrl-Shift-d>)
-- ---------------------------------------------------------------------------
local dark_mode_enabled = false
local dark_css = [[
  html { background-color: #222 !important; color: #ddd !important; }
  a { color: #88b0ff !important; }
  img, video { filter: brightness(0.9) !important; }
]]
bind("n", "<Control-Shift-d>", function(w)
  if dark_mode_enabled then
    styles.unregister_global_stylesheet("dark-mode")
    dark_mode_enabled = false
    w:notify("Dark mode off", "info")
  else
    styles.register_global_stylesheet("dark-mode", dark_css)
    dark_mode_enabled = true
    w:notify("Dark mode on", "info")
  end
end)

-- ---------------------------------------------------------------------------
-- 6. Per‑domain settings (JS, images, zoom, user agent)
-- ---------------------------------------------------------------------------
local per_domain = {
  ["example-bank.com"] = { enable_javascript = false },
  ["netflix.com"] = {
    user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/91.0.4472.124",
    enable_javascript = true,
  },
}

window.add_signal("load-status", function(w, status, uri)
  if status ~= "finished" then return end
  local host = uri.host or ""
  local rules = per_domain[host]
  if rules then
    if rules.user_agent then w.view.user_agent = rules.user_agent end
    if rules.enable_javascript ~= nil then w.view.enable_javascript = rules.enable_javascript end
  end
  local zoom = sql_webhistory.get_property(host, "zoom")
  if zoom then w:zoom_set(tonumber(zoom)) end
end)

window.add_signal("zoom-changed", function(w, zoom, uri)
  if uri and uri.host then
    sql_webhistory.set_property(uri.host, "zoom", tostring(zoom))
  end
end)

bind("n", "<Control-Shift-j>", function(w)
  local enabled = w.view.enable_javascript
  w.view.enable_javascript = not enabled
  w:notify("JavaScript " .. (not enabled and "on" or "off"), "info")
end)

bind("n", "<Control-Shift-i>", function(w)
  local settings = w.view.settings
  settings.auto_load_images = not settings.auto_load_images
  w:notify("Images " .. (settings.auto_load_images and "on" or "off"), "info")
end)

-- ---------------------------------------------------------------------------
-- 7. Keyboard shortcuts (normal mode)
-- ---------------------------------------------------------------------------
local function scroll(pixels)
  return function(w) w.view:scroll { y = pixels, relative = true } end
end
bind("n", "j", scroll(60))
bind("n", "k", scroll(-60))
bind("n", "h", function(w) w.view:scroll { x = -120, relative = true } end)
bind("n", "l", function(w) w.view:scroll { x = 120, relative = true } end)
bind("n", "gg", function(w) w.view:scroll { y = 0 } end)
bind("n", "G", function(w) w.view:scroll { y = -1 } end)
bind("n", "d", function(w) w.view:scroll { y = window.page_height / 2, relative = true } end)
bind("n", "u", function(w) w.view:scroll { y = -window.page_height / 2, relative = true } end)
bind("n", "]]", function(w) w.view:scroll { y = window.page_height, relative = true } end)
bind("n", "[[", function(w) w.view:scroll { y = -window.page_height, relative = true } end)

-- Reload / navigation
bind("n", "r", function(w) w:reload() end)
bind("n", "R", function(w) w:reload(true) end)
bind("n", "H", function(w) w:go_back() end)
bind("n", "L", function(w) w:go_forward() end)
bind("n", "gh", function(w) w:open(window.home_page) end)

-- Clipboard
bind("n", "yy", function(w) w:set_clipboard(w.view.uri) end)
bind("n", "yt", function(w) w:set_clipboard(w.view.title) end)
bind("n", "yT", function(w) w:set_clipboard(w.view.title .. " " .. w.view.uri) end)
bind("n", "p", function(w) w:open_paste() end)
bind("n", "P", function(w) w:open_paste(true) end)

-- Tabs
bind("n", "t", function(w) w:new_tab(window.home_page) end)
bind("n", "T", function(w) w:new_tab(window.home_page, false) end)
bind("n", "gt", function(w) w:next_tab() end)
bind("n", "gT", function(w) w:previous_tab() end)
bind("n", "x", function(w) w:close_tab() end)
bind("n", "u", function(w) if undo then w:undo_close_tab() end end)
bind("n", "<Ctrl-PageUp>", function(w) w:move_tab_left() end)
bind("n", "<Ctrl-PageDown>", function(w) w:move_tab_right() end)

-- Hints
bind("n", "f", function(w) follow.start(w, "new-tab") end)
bind("n", "F", function(w) follow.start(w, "current") end)
bind("n", ";t", function(w) follow.start(w, "background-tab") end)
bind("n", ";y", function(w) follow.start(w, "yank") end)
bind("n", ";Y", function(w) follow.start(w, "yank-text") end)

-- Search
bind("n", "/", function(w) w:set_mode("search") end)
bind("n", "n", function(w) w:search_next() end)
bind("n", "N", function(w) w:search_prev() end)

-- Zoom
bind("n", "+", function(w) w:zoom_in() end)
bind("n", "-", function(w) w:zoom_out() end)
bind("n", "=", function(w) w:zoom_set(1.0) end)

-- Reader mode
bind("n", "<Control-Alt>r", function(w)
  w.view:eval_js [[
    (function(){
      var s=document.createElement('script');
      s.src='https://cdnjs.cloudflare.com/ajax/libs/readability/0.4.4/Readability.js';
      document.body.appendChild(s);
    })()
  ]]
end)

-- Bookmarks
bind("n", "m", function(w) bookmarks.add(w.view.uri, w.view.title) end)
bind("n", "B", ":bookmarks")
bind("n", "D", ":downloads")

-- Quickmarks (if available)
if quickmarks then
  bind("n", "M", function(w) quickmarks.add(w.view.uri, w.view.title) end)
  bind("n", "go", function(w)
    local key = w:get_input("Quickmark key:")
    if key then quickmarks.open(key, w) end
  end)
end

-- Session / quit
bind("n", "ZZ", function(w)
  w:save_session(); w:close()
end)
bind("n", "ZQ", function(w) w:close() end)
bind("n", ":q", function(w) w:close() end)
bind("n", ":wq", function(w)
  w:save_session(); w:close()
end)

-- Reload config
bind("n", "<F5>", function(w) lousy.reload() end)

-- ---------------------------------------------------------------------------
-- 8. Search engines
-- ---------------------------------------------------------------------------
search.engines = {
  google    = "https://www.google.com/search?q=%s",
  ddg       = "https://duckduckgo.com/?q=%s",
  yt        = "https://www.youtube.com/results?search_query=%s",
  github    = "https://github.com/search?q=%s",
  wikipedia = "https://en.wikipedia.org/wiki/Special:Search?search=%s",
  maps      = "https://www.google.com/maps/search/%s",
  amazon    = "https://www.amazon.com/s?k=%s",
  imdb      = "https://www.imdb.com/find?q=%s",
  reddit    = "https://www.reddit.com/search/?q=%s",
}
search.default_engine = "ddg"

-- ---------------------------------------------------------------------------
-- 9. Vertical tab tree
-- ---------------------------------------------------------------------------
tabgroup.add_signal("page-created", function(w, view)
  local host = view.uri.host or "new tab"
  tabgroup.add(view, host)
end)
tabgroup.add_signal("page-focused", function(w, view)
  local group = tabgroup.get(view)
  if group then tabgroup.collapse_all_except(group) end
end)

-- ---------------------------------------------------------------------------
-- 10. Hints
-- ---------------------------------------------------------------------------
follow.default_labels = "asdfghjklqwertyuiop"
follow.auto_follow_delay = 0
follow.always_open_new_tab = true

-- ---------------------------------------------------------------------------
-- 11. History & bookmarks
-- ---------------------------------------------------------------------------
sql_webhistory.enable()
bookmarks.add_signal("bookmark-added", function(b)
  window:notify("Bookmarked: " .. b.title, "info")
end)

-- ---------------------------------------------------------------------------
-- 12. User scripts (optional)
-- ---------------------------------------------------------------------------
if user_scripts then
  user_scripts.load_dir(lousy.util.find_data_dir("userscripts"))
  user_scripts.add_signal("script-installed", function(s)
    window:notify("User script installed: " .. s.name, "info")
  end)
end

-- ---------------------------------------------------------------------------
-- 13. Smooth scrolling injection
-- ---------------------------------------------------------------------------
window.add_signal("page-created", function(w, view)
  view:eval_js([[
    (function() {
      var css = document.createElement('style');
      css.textContent = 'html { scroll-behavior: smooth; }';
      document.head.appendChild(css);
    })();
  ]], { no_return = true })
end)

-- ---------------------------------------------------------------------------
-- 14. Password manager (pass) – uncomment if you use pass
-- ---------------------------------------------------------------------------
-- bind("n", "<Control-Shift-p>", function(w)
--   local host = w.view.uri.host or ""
--   if host == "" then return end
--   os.execute(string.format(
--     "pass -c %s 2>/dev/null && xdotool type \"$(pass %s | head -1)\" && xdotool key Tab && xdotool type \"$(pass %s | head -2 | tail -1)\"",
--     host, host, host
--   ))
-- end)

-- ---------------------------------------------------------------------------
-- 15. Startup
-- ---------------------------------------------------------------------------
window.add_signal("init", function(w)
  if not w:load_session() then
    w:new_tab(window.home_page)
  end
end)

-- vim: ft=lua
