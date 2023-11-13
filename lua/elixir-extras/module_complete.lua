local function elixir_module_complete()
  -- get the end of the module name under the cursor
  local mod = vim.fn.expand('<cWORD>')
  if string.match(mod, "%.") then
      -- if it's Mod1.Mod2 then we want to stop, it's already namespaced.
      -- however if it's Mod1.function() then we want to change it to Root.Mod1.function()
      local elements = vim.split(mod, "%.")
      local capitalized_elts = vim.tbl_filter(function(e) return string.upper(string.sub(e, 1, 1)) == string.sub(e, 1, 1) end, elements)
      if #capitalized_elts == 1 then
        -- we're good
        mod = vim.fn.expand('<cword>')
      else
        print("Already expanded the module")
        return
      end
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
