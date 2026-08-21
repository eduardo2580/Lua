local phpunit_adapter = {}
phpunit_adapter.name = "phpunit"

function phpunit_adapter.root(file)
  local patterns = { "phpunit.xml", "phpunit.xml.dist", ".git" }
  for _, pat in ipairs(patterns) do
    local found = vim.fn.finddir(pat, file .. ";")
    if found and found ~= "" then return vim.fn.fnamemodify(found, ":h") end
    local foundfile = vim.fn.findfile(pat, file .. ";")
    if foundfile and foundfile ~= "" then return vim.fn.fnamemodify(foundfile, ":h") end
  end
  return vim.fn.getcwd()
end

function phpunit_adapter.filter_dir(name, _rel_path, _root)
  return name ~= "vendor" and name ~= "node_modules" and name ~= ".git"
end

function phpunit_adapter.is_test_file(file_path)
  if not file_path then return false end
  return file_path:match("Test%.php$") ~= nil
end

local phpunit_query = [[
  (class_declaration
    name: (name) @namespace.name) @namespace.definition

  (method_declaration
    name: (name) @test.name
    (#match? @test.name "^test")) @test.definition
]]

function phpunit_adapter.discover_positions(file_path)
  return require("neotest.lib").treesitter.parse_positions(file_path, phpunit_query, {
    nested_tests = true,
  })
end

function phpunit_adapter.build_spec(args)
  local file        = args.file
  local pos         = args.position
  local method_name = nil

  if pos then
    local line = vim.fn.getline(pos[1])
    method_name = line:match("function%s+(test%w+)")
    if not method_name then
      local prev = vim.fn.getline(pos[1] - 1)
      if prev and prev:match("@test") then
        local fn_line = vim.fn.getline(pos[1])
        method_name = fn_line:match("function%s+(%w+)")
      end
    end
  end

  local base_name = vim.fn.fnamemodify(file, ":t:r")
  local spec_name = method_name or base_name
  local tmpfile = (os.tmpname()):gsub("\\", "/")
  local cmd = { "phpunit", "--no-interaction", "--log-teamcity", tmpfile }
  if spec_name ~= base_name then
    table.insert(cmd, "--filter")
    table.insert(cmd, spec_name)
  end
  table.insert(cmd, file)

  return {
    {
      name    = spec_name,
      file    = file,
      command = cmd,
      env     = { LOG_FILE = tmpfile },
      cwd     = phpunit_adapter.root(file),
    },
  }
end

local function tc_unescape(s)
  if not s then return s end
  return (s:gsub("|n", "\n"):gsub("|r", "\r"):gsub("|%[", "["):gsub("|%]", "]"):gsub("|'", "'"):gsub("||", "|"))
end

local function tc_parse_line(line)
  local event, rest = line:match("^##teamcity%[(%a+)%s+(.*)%]$")
  if not event then return nil end
  local attrs = {}
  for key, val in rest:gmatch("(%w+)='(.-)'%s*") do
    attrs[key] = tc_unescape(val)
  end
  return event, attrs
end

function phpunit_adapter.results(spec, _result, _helpers)
  local logfile = spec.env and spec.env.LOG_FILE
  if not logfile then return {} end

  local f, err = io.open(logfile, "r")
  if not f then
    return { [spec.name] = { status = "failed", output = "Cannot open log: " .. (err or "") } }
  end

  local results = {}
  for line in f:lines() do
    local event, attrs = tc_parse_line(line)
    if event and attrs.name then
      if event == "testFailed" then
        local msg = attrs.message or "Unknown failure"
        if attrs.details and attrs.details ~= "" then
          msg = msg .. "\n" .. attrs.details
        end
        results[attrs.name] = { status = "failed", short = "FAIL", output = msg, errors = { { message = msg } } }
      elseif event == "testIgnored" then
        results[attrs.name] = { status = "skipped", short = "SKIP" }
      elseif event == "testFinished" and not results[attrs.name] then
        results[attrs.name] = { status = "passed", short = "PASS" }
      end
    end
  end
  f:close()
  pcall(os.remove, logfile)

  if vim.tbl_isempty(results) then
    results[spec.name] = { status = "failed", output = "No test events found in PHPUnit teamcity log; the run may have errored before any test started." }
  end

  return results
end

return phpunit_adapter
