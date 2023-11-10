local function elixir_module_complete()
  -- get the end of the module name under the cursor
  local mod = vim.fn.expand('<cWORD>')
  if string.match(mod, "%.") then
    -- refusing if there are already levels (dots)
    -- otherwise applying twice would be messy
    return
  end
  local params = { query = mod }
  vim.lsp.buf_request(0, "workspace/symbol", params, function(err, server_result, _, _)
    if err then
      vim.api.nvim_err_writeln("Error when finding workspace symbols: " .. err.message)
      return
    end
    local relevant_modules = vim.tbl_filter(function(s)
      return s.kind == 2 and string.match(s.name, "%." .. mod .. "$")
    end, server_result)
    if #relevant_modules == 1 then
      vim.cmd("norm! caw" .. relevant_modules[1].name)
    elseif #relevant_modules > 1 then
      local candidate_names = vim.tbl_map(function(n) return n.name end, relevant_modules)
      vim.ui.select(candidate_names, {prompt="Pick the module to use"}, function(module)
        if module ~= nil then
          vim.cmd("norm! caw" .. module)
        end
      end)
    end
  end)
end

return {
  elixir_module_complete = elixir_module_complete
}
