-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt
opt.tabstop = 4 -- wie viele Spalten ein Tab “kostet”
opt.shiftwidth = 4 -- Einrückung für >>, <<, autoindent
opt.softtabstop = 4 -- wie viele Spaces beim Backspace/Insert gezählt werden
opt.expandtab = true -- Tabs als Spaces
