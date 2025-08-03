local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local conf = require('telescope.config').values

local get_headers = function()
  local ts = vim.treesitter
  local query = ts.query.parse('markdown', '((atx_heading) @header)')

  local bufnr = vim.api.nvim_get_current_buf()
  local parser = ts.get_parser(bufnr, 'markdown')
  if not parser then
    vim.notify("No treesitter parser found for markdown", vim.log.levels.WARN)
    return
  end
  local tree = parser:parse()[1]
  local root = tree:root()

  local headers = {}
  -- cache of header hierarchy
  local header_hierarchy = {}
  for i = 1, 6 do
    header_hierarchy[i] = ""
  end
  for index, node in query:iter_captures(root, bufnr, 0, -1) do
    if query.captures[index] == 'header' then
      local start_row, _, _ = node:start()
      local header_line = vim.treesitter.get_node_text(node, bufnr)
      local _, _, hashes = string.find(header_line, '^(#+)')
      local level = #hashes
      -- loop through one level deeper till level 6 to remove previous hierarchy
      for i = level + 1, 6 do
        header_hierarchy[i] = ""
      end
      header_hierarchy[level] = header_line:sub(#hashes + 1) -- store the current header text
      -- concatenate cached header hierarchy if the header is not empty
      local hierarchy_text = table.concat(header_hierarchy, " >", 1, level)
      table.insert(headers, {
        line = start_row + 1,
        text = hierarchy_text,
      })
    end
  end

  return headers
end

local M = {}

function M.markdown_header_picker(opts)
  opts = opts or {}
  pickers.new(opts, {
    prompt_title = "Markdown Headers",
    finder = finders.new_table {
      results = get_headers(),
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.text,
          ordinal = entry.text,
        }
      end,
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(_, map)
      map('i', '<CR>', function(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          vim.api.nvim_win_set_cursor(0, { selection.value.line, 0 })
        end
      end)
      return true
    end,
  }):find()
end

return M
