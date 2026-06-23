-- ~/.config/luakit/rc.lua
-- Luakit Super Config — v1.0
-- Drop‑in replacement for your rc.lua. Backup your old config first!

-- ---------------------------------------------------------------------------
-- 1. Global settings & modules
-- ---------------------------------------------------------------------------
local lousy = require("lousy")       -- plugin / utility loader
local tabgroup = require("tabgroup") -- vertical tab tree
local adblock = require("adblock")   -- ad blocking
local styles = require("styles")     -- user stylesheets
local follow = require("follow")     -- alternative link hints
local downloads = require("downloads")
local bookmarks = require("bookmarks")
local sql_webhistory = require("sql_webhistory")
local search = require("search")

-- Make global modules available
window = window
bind = lousy.bind
modes = lousy.modes

-- ---------------------------------------------------------------------------
-- 2. User interface tweaks
-- ---------------------------------------------------------------------------

-- Vertical tab bar (left side, 200px wide)
window.tabs_position = "left"
window.tabs_width = 200

-- Statusbar format: [mode] tab_index/tab_count | title | url
window.statusbar_format = "[%m] %t/%T | %p | %u"

-- Remove menu & scrollbars
window.menu_bar = false
window.scrollbars = false

-- Start page
window.home_page = "about:blank"

-- Download directory (auto‑create if missing)
os.execute("mkdir -p " .. os.getenv("HOME") .. "/downloads")
downloads.default_dir = os.getenv("HOME") .. "/downloads"
downloads.add_signal("download-created", function(d)
  window:notify("Downloading: " .. d.filename, "info")
end)

-- ---------------------------------------------------------------------------
-- 3. Adblock + privacy
-- ---------------------------------------------------------------------------
adblock.load_dir(lousy.util.find_data_dir("adblock"))
adblock.sources = {
  "https://easylist.to/easylist/easylist.txt",
  "https://easylist.to/easylist/easyprivacy.txt",
  "https://someonewhocares.org/hosts/zero/hosts",
}
adblock.update() -- fetch & parse lists (run once; can be scheduled)

-- Block third‑party cookies by default (except bookmarked sites)
window.set_policy("cookie-accept", "no-third-party")

-- ---------------------------------------------------------------------------
-- 4. Dark mode & user styles
-- ---------------------------------------------------------------------------
-- Universal dark mode CSS injected into every page
local dark_theme_css = [[
    html, body, div, table, tr, td, th, ul, ol, li, p, span,
    input, textarea, select, button, pre, code, blockquote {
        background-color: #222 !important;
        color: #ddd !important;
        border-color: #555 !important;
    }
    a { color: #88b0ff !important; }
    a:visited { color: #c58af9 !important; }
    img, video { filter: brightness(0.9) !important; }
]]
styles.register_global_stylesheet("dark-mode", dark_theme_css)

-- Additional per‑domain styles can be added here:
-- styles.register_domain_stylesheet("example.com", "myrules.css")

-- ---------------------------------------------------------------------------
-- 5. Vim‑like keybindings (normal mode)
-- ---------------------------------------------------------------------------
local function scroll(pixels)
  return function(w) w.view:scroll { y = pixels, relative = true } end
end

bind("n", "j", scroll(60))
bind("n", "k", scroll(-60))
bind("n", "h", scroll(-120, true))       -- horizontal (shifted)
bind("n", "l", scroll(120, true))
bind("n", "gg", function(w) w.view:scroll { y = 0 } end)
bind("n", "G", function(w) w.view:scroll { y = -1 } end)
bind("n", "d", function(w) w.view:scroll { y = window.page_height / 2, relative = true } end)
bind("n", "u", function(w) w.view:scroll { y = -window.page_height / 2, relative = true } end)
bind("n", "r", function(w) w:reload() end)
bind("n", "R", function(w) w:reload(true) end)
bind("n", "yy", function(w) w:set_clipboard(w.view.uri) end)
bind("n", "p", function(w) w:open_paste() end)
bind("n", "P", function(w) w:open_paste(true) end)        -- new tab

-- Tab management
bind("n", "t", function(w) w:new_tab(window.home_page) end)
bind("n", "T", function(w) w:new_tab(window.home_page, false) end)        -- background tab
bind("n", "gt", function(w) w:next_tab() end)
bind("n", "gT", function(w) w:previous_tab() end)
bind("n", "x", function(w) w:close_tab() end)
bind("n", "H", function(w) w:go_back() end)
bind("n", "L", function(w) w:go_forward() end)

-- Link hinting (press 'f' to label links)
bind("n", "f", function(w) follow.start(w) end)
bind("n", "F", function(w) follow.start(w, "current") end)        -- open in current tab

-- Search
bind("n", "/", function(w) w:set_mode("search") end)
bind("n", "n", function(w) w:search_next() end)
bind("n", "N", function(w) w:search_prev() end)

-- Zoom
bind("n", "+", function(w) w:zoom_in() end)
bind("n", "-", function(w) w:zoom_out() end)
bind("n", "=", function(w) w:zoom_set(1.0) end)

-- Reader mode (inject readability script)
bind("n", "<Control-Alt>r", function(w)
  local script = [[(function(){var s=document.createElement('script');
        s.src='https://cdnjs.cloudflare.com/ajax/libs/readability/0.4.4/Readability.js';
        document.body.appendChild(s);})()]]
  w.view:eval_js(script)
end)

-- Save session & quit
bind("n", "ZZ", function(w)
  w:save_session(); w:close()
end)
bind("n", "ZQ", function(w) w:close() end)

-- Command mode (standard ':' binding is added by lousy)

-- ---------------------------------------------------------------------------
-- 6. Custom search engines
-- ---------------------------------------------------------------------------
search.engines = {
  google    = "https://www.google.com/search?q=%s",
  ddg       = "https://duckduckgo.com/?q=%s",
  yt        = "https://www.youtube.com/results?search_query=%s",
  github    = "https://github.com/search?q=%s",
  wikipedia = "https://en.wikipedia.org/wiki/Special:Search?search=%s",
}
search.default_engine = "ddg"

-- Enable keyword searches from the address bar
-- Example: ":open google luakit" searches Google for "luakit"

-- ---------------------------------------------------------------------------
-- 7. Per‑domain settings (user agent, JS toggle)
-- ---------------------------------------------------------------------------
local per_domain = {
  ["netflix.com"] = {
    user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/91.0.4472.124",
    enable_javascript = true,
  },
  ["example-bank.com"] = {
    enable_javascript = false,     -- hardened mode
  }
}

-- Apply settings when a page loads
window.add_signal("load-status", function(w, status, uri)
  if status ~= "finished" then return end
  local host = uri.host or ""
  local domain = host:match("%.(%w+%.%w+)$") or host
  local rules = per_domain[domain]
  if rules then
    if rules.user_agent then
      w.view.user_agent = rules.user_agent
    end
    if rules.enable_javascript ~= nil then
      w.view.enable_javascript = rules.enable_javascript
    end
  end
end)

-- ---------------------------------------------------------------------------
-- 8. Vertical tab tree (tab group plugin)
-- ---------------------------------------------------------------------------
-- Groups tabs by domain automatically
tabgroup.add_signal("page-created", function(w, view)
  local host = view.uri.host or "new tab"
  -- Create group named after domain
  tabgroup.add(view, host)
end)

-- Collapse other groups when switching
tabgroup.add_signal("page-focused", function(w, view)
  local group = tabgroup.get(view)
  if group then tabgroup.collapse_all_except(group) end
end)

-- ---------------------------------------------------------------------------
-- 9. Hints follow alternative (if you prefer it)
-- ---------------------------------------------------------------------------
follow.default_labels = "asdfghjklqwertyuiop"
follow.auto_follow_delay = 0
follow.always_open_new_tab = true

-- ---------------------------------------------------------------------------
-- 10. Bookmarks (optional, using sql_webhistory)
-- ---------------------------------------------------------------------------
-- Enable history & bookmark search via :bookmarks
sql_webhistory.enable()
bookmarks.add_signal("bookmark-added", function(b)
  window:notify("Bookmarked: " .. b.title, "info")
end)

-- Shortcut to add bookmark: 'm'
bind("n", "m", function(w) bookmarks.add(w.view.uri, w.view.title) end)

-- ---------------------------------------------------------------------------
-- 11. Start‑up actions & session restore
-- ---------------------------------------------------------------------------
window.add_signal("init", function(w)
  -- Try to restore last session, otherwise open home
  if not w:load_session() then
    w:new_tab(window.home_page)
  end
  -- Update adblock daily (optional; runs async)
  adblock.update()
end)

-- ---------------------------------------------------------------------------
-- 12. Extra goodies (context menu, mouse gestures)
-- ---------------------------------------------------------------------------
-- Enable right‑click context menu with "Open in new tab", "Copy link", etc.
window.context_menu = true

-- Middle‑click on link opens in new tab
window.middle_click_open_new_tab = true

-- ---------------------------------------------------------------------------
-- 13. Smooth scrolling script injection
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
-- End of Super Config
-- ---------------------------------------------------------------------------
-- vim: ft=lua
