local ok, jdtls = pcall(require, "jdtls")
if not ok then
  vim.notify("Java support: nvim-jdtls is not available. Run :Lazy sync.", vim.log.levels.WARN)
  return
end

if vim.fn.executable("java") == 0 then
  vim.notify("Java support: JDK 21+ is required and java is not on PATH.", vim.log.levels.WARN)
  return
end

local java_version = vim.fn.system({ "java", "-version" })
local java_major = tonumber(java_version:match('version "1%.(%d+)') or java_version:match('version "(%d+)'))
if not java_major or java_major < 21 then
  vim.notify("Java support: JDK 21+ is required by current jdtls.", vim.log.levels.WARN)
  return
end

if vim.fn.executable("jdtls") == 0 then
  vim.notify("Java support: jdtls is not installed. Run :Mason and install jdtls.", vim.log.levels.WARN)
  return
end

local root_dir = vim.fs.root(0, {
  "mvnw", "pom.xml", "gradlew", "build.gradle", "settings.gradle", ".git",
})
if not root_dir then
  vim.notify("Java support: open a Maven, Gradle, or Git project to start jdtls.", vim.log.levels.INFO)
  return
end

local project_id = vim.fn.sha256(root_dir):sub(1, 16)
local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_id
vim.fn.mkdir(workspace_dir, "p")

local capabilities = vim.lsp.protocol.make_client_capabilities()
local cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if cmp_ok then
  capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
end

local runtimes = {}
local java_home = vim.env.JAVA_HOME
if java_home and java_home ~= "" then
  runtimes[#runtimes + 1] = { name = "JavaSE-21", path = java_home }
end

local config = {
  name = "jdtls",
  cmd = { "jdtls", "-data", workspace_dir },
  root_dir = root_dir,
  capabilities = capabilities,
  settings = {
    java = {
      configuration = { runtimes = runtimes },
      contentProvider = { preferred = "fernflower" },
      eclipse = { downloadSources = true },
      maven = { downloadSources = true },
      references = { includeDecompiledSources = true },
      signatureHelp = { enabled = true },
      implementationsCodeLens = { enabled = true },
      referencesCodeLens = { enabled = true },
    },
  },
  init_options = {
    bundles = {},
    extendedClientCapabilities = jdtls.extendedClientCapabilities,
  },
}

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { buffer = true, silent = true, desc = desc })
end

map("n", "<leader>jo", jdtls.organize_imports, "Java: organize imports")
map("n", "<leader>jc", function() jdtls.compile("incremental") end, "Java: compile")
map("n", "<leader>ju", jdtls.update_project_config, "Java: update project")
map("n", "<leader>jv", jdtls.set_runtime, "Java: set runtime")
map("n", "<leader>jr", function() jdtls.extract_variable() end, "Java: extract variable")
map("v", "<leader>jr", function() jdtls.extract_variable({ visual = true }) end, "Java: extract variable")
map("n", "<leader>jm", function() jdtls.extract_method() end, "Java: extract method")
map("v", "<leader>jm", function() jdtls.extract_method({ visual = true }) end, "Java: extract method")
map("n", "<leader>jt", jdtls.test_nearest_method, "Java: test method")
map("n", "<leader>jf", jdtls.test_class, "Java: test class")

jdtls.start_or_attach(config, {
  dap = { hotcodereplace = "auto" },
})