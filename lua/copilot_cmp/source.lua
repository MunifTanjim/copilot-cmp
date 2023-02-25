local source = {}

function source:get_keyword_pattern()
  return "\\w\\+.*"
end

source.get_trigger_characters = function()
  return { "\t", "\n", ".", ":", "(", "'", '"', "[", ",", "#", "*", "@", "|", "=", "-", "{", "/", "\\", " ", "+", "?"}
end

local fix_indent = function (completion_item)
  local text = completion_item.textEdit.newText
  text = string.gsub(text, "^%s*", "")
  completion_item.textEdit.newText = text
  return completion_item
end

-- executes before selection
source.resolve = function (self, completion_item, callback)
  completion_item = fix_indent(completion_item)
  for _, fn in ipairs(self.executions) do
    completion_item = fn(completion_item)
  end
  callback(completion_item)
end

source.is_available = function(self)
  -- client is stopped.
  if self.client.is_stopped() then
    return false
  end
  -- client is not attached to current buffer.
  if not vim.lsp.buf_get_clients(vim.api.nvim_get_current_buf())[self.client.id] then
    return false
  end
  if not self.client.name == "copilot" then
    return false
  end
  return true
end

local defaults =  {
  method = "getCompletionsCycling",
  force_autofmt = false,
  fix_indent = true,
  -- should not be necessary due to cmp changes
  -- clear_after_cursor = true,
  formatters = {
    label = require("copilot_cmp.format").format_label_text,
    insert_text = require("copilot_cmp.format").format_insert_text,
    preview = require("copilot_cmp.format").deindent,
  },
}

source.new = function(client, opts)
  opts = vim.tbl_deep_extend('force', defaults, opts or {})
  local completion_fn = opts.method or "getCompletionsCycling"

  local completion_functions = require("copilot_cmp.completion_functions")
  local self = setmetatable({ timer = vim.loop.new_timer() }, { __index = source })

  local setup_execution_functions = function ()
    local executions = {
      opts.fix_indent and fix_indent or nil,
      -- fix_indent,
      -- should not be necessary due to cmp changes
      -- opts.clear_after_cursor and clear_after_cursor or nil,
    }
    return executions
  end

  self.executions = setup_execution_functions()

  self.client = client
  self.request_ids = {}

  self.formatters = vim.tbl_deep_extend("force", {}, opts.formatters or {})
  if not self.formatters.label then
    self.formatters.label = require("copilot_cmp.format").format_label_text
  end
  if not self.formatters.insert_text then
    self.formatters.insert_text = require("copilot_cmp.format").format_insert_text
  end
  if not self.formatters.preview then
    self.formatters.preview = require("copilot_cmp.format").deindent
  end

  self.complete = completion_functions.init(completion_fn)

  return self
end

return source
