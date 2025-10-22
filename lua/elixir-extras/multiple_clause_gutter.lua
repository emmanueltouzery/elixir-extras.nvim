function _G.elixir_mark_multiple_clause_fns()
  -- we don't want to consider two functions in two different
  -- modules in the same file to be clauses of the same function.
  -- so besides the function name we also consider the line number
  -- of the start of the parent block (module)
  function parent_block(node)
    local cur_node = node
    while cur_node:type() ~= "do_block" do
      if cur_node:parent() == nil then
        return cur_node
      else
        cur_node = cur_node:parent()
      end
    end
    return cur_node
  end

  vim.cmd[[sign define clause text=⡇ texthl=TSFunction]]
  vim.cmd[[sign define clauseStart text=⡏ texthl=TSFunction]]
  vim.cmd[[sign define clauseEnd text=⣇ texthl=TSFunction]]
  local parser = vim.treesitter.get_parser(0)
  if parser == nil then
    -- getting this sometimes when displaying elixir code in popups or something
    return
  end
  local syntax_tree = parser:parse()[1]
  local lang = parser:lang()
  local prev_key = nil
  local multi_clause_counts = {}
  local query = vim.treesitter.query.get(lang, "clauses")
  for pattern, match, metadata in query:iter_matches(syntax_tree:root(), 0) do
    for id, nodes in pairs(match) do
      local cap_id = query.captures[id]
      if cap_id == "name" then
        local node = nodes[1]
        local fn_name = vim.treesitter.get_node_text(node, 0)
        local parent_lnum = vim.treesitter.get_node_range(parent_block(node))+1
        local key = fn_name .. "/" .. parent_lnum

        if key == prev_key then
          if multi_clause_counts[key] then
            multi_clause_counts[key] = multi_clause_counts[key] + 1
          else
            multi_clause_counts[key] = 2
          end
        end
        prev_key = key
      end
    end
  end
  -- print(vim.inspect(multi_clause_counts))
  local fname = vim.fn.expand("%:p")
  local start_sign_id = 3094
  if vim.b.signs_count then
    for i=0,vim.b.signs_count,1 do
      vim.cmd("sign unplace " .. (start_sign_id + i))
    end
  end
  local signs_count = 0
  local cur_fname = nil
  local count_for_fn = 0
  local query = vim.treesitter.query.get(lang, "clauses")
  for pattern, match, metadata in query:iter_matches(syntax_tree:root(), 0) do
    for id, nodes in pairs(match) do
      local cap_id = query.captures[id]
      if cap_id == "name" then
        local node = nodes[1]
        local fn_name = vim.treesitter.get_node_text(node, 0)
        local parent_lnum = vim.treesitter.get_node_range(parent_block(node))+1
        local key = fn_name .. "/" .. parent_lnum

        if multi_clause_counts[key] then
          local line = vim.treesitter.get_node_range(node)+1
          if cur_fname ~= fn_name then
            -- first for this function
            vim.cmd("exe ':sign place " .. (start_sign_id + signs_count) .. " line=" .. line .. " name=clauseStart'")
            count_for_fn = 1
          elseif count_for_fn + 1 == multi_clause_counts[key] then
            -- last for this function
            vim.cmd("exe ':sign place " .. (start_sign_id + signs_count) .. " line=" .. line .. " name=clauseEnd'")
          else
            vim.cmd("exe ':sign place " .. (start_sign_id + signs_count) .. " line=" .. line .. " name=clause'")
            count_for_fn = count_for_fn + 1
          end
          cur_fname = fn_name
          signs_count = signs_count + 1
        end
      end
      vim.b.signs_count = signs_count
    end
  end
end

local function setup_multiple_clause_gutter()
  vim.cmd [[au BufWinEnter,BufWritePost *.ex lua elixir_mark_multiple_clause_fns()]]
  vim.cmd [[au BufWinEnter,BufWritePost *.exs lua elixir_mark_multiple_clause_fns()]]
end

return {
  setup_multiple_clause_gutter = setup_multiple_clause_gutter,
}
