local M = {}

local health = vim.health or {}
local h_start = health.start or health.report_start
local h_ok = health.ok or health.report_ok
local h_warn = health.warn or health.report_warn
local h_error = health.error or health.report_error
local h_info = health.info or health.report_info
local SUPPORTED_FILETYPES = {
    "javascript",
    "typescript",
    "javascriptreact",
    "typescriptreact",
    "vue",
}

local function lang_for_ft(ft)
    local ok, lang = pcall(vim.treesitter.language.get_lang, ft)
    if ok and lang then
        return lang
    end
    return ft
end

local function parser_installed(lang)
    local files =
        vim.api.nvim_get_runtime_file("parser/" .. lang .. ".so", false)
    if #files == 0 then
        files = vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false)
    end
    return #files > 0
end

function M.check()
    h_start("skipper.nvim")

    if vim.fn.has("nvim-0.5.0") == 1 then
        h_ok("Neovim >= 0.5.0")
    else
        h_error("Neovim >= 0.5.0 is required")
    end

    if vim.treesitter == nil then
        h_error("Neovim Treesitter runtime not available")
        return
    end
    h_ok("Neovim Treesitter runtime available")

    if pcall(require, "nvim-treesitter") then
        h_ok("nvim-treesitter plugin installed")
    else
        h_warn("nvim-treesitter plugin not found", {
            "Recommended for installing parsers.",
            "https://github.com/nvim-treesitter/nvim-treesitter",
        })
    end

    h_info(
        "Skipper works in any file with a Treesitter parser (default extractor). "
            .. "Filetypes with dedicated extractors:"
    )

    local ready, missing = {}, {}
    local seen_missing = {}

    for _, ft in ipairs(SUPPORTED_FILETYPES) do
        local lang = lang_for_ft(ft)
        if parser_installed(lang) then
            table.insert(ready, ("%s (%s)"):format(ft, lang))
        else
            table.insert(missing, ("%s (%s)"):format(ft, lang))
            seen_missing[lang] = true
        end
    end

    if #ready > 0 then
        h_ok("Ready: " .. table.concat(ready, ", "))
    end

    if #missing > 0 then
        local install = {}
        for lang, _ in pairs(seen_missing) do
            table.insert(install, lang)
        end
        h_info(
            "Not installed (only needed if you edit these files): "
                .. table.concat(missing, ", "),
            { "Install as needed: :TSInstall " .. table.concat(install, " ") }
        )
    end
end

return M
