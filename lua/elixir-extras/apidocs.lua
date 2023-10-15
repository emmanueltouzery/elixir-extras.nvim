local function get_extra_mix_folders(opts)
  extra_mix_folders = {}

  if opts and opts.include_mix_libs then
    -- in theory I should load modules through -S mix but.. i couldn't make it work
    -- from neovim, it's slow and so on.
    local processed_libs = {}
    local base_path = './_build/dev/lib/'
    local sd = vim.loop.fs_scandir(base_path)
    while sd ~= nil and true do
      local name, type = vim.loop.fs_scandir_next(sd)
      if name == nil then break end
      processed_libs[name] = true
      table.insert(extra_mix_folders, base_path .. name .. '/ebin/')
    end

    local base_path = './_build/test/lib/'
    local sd = vim.loop.fs_scandir(base_path)
    while sd ~= nil and true do
      local name, type = vim.loop.fs_scandir_next(sd)
      if name == nil then break end
      if not processed_libs[name] then
        table.insert(extra_mix_folders, base_path .. name .. '/ebin/')
      end
    end
  end

  return extra_mix_folders
end

local function elixir_pa_flags(opts, flags)
  res = {"elixir"}

  local extra_mix_folders = get_extra_mix_folders(opts)
  for _, f in ipairs(extra_mix_folders) do
    table.insert(res, "-pa")
    table.insert(res, f)
  end
  for _, f in ipairs(flags) do
    table.insert(res, f)
  end
  return res
end

-- https://stackoverflow.com/a/52521017/516188
local elixir_view_module_docs

local function elixir_view_export_docs(export, opts)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(0, buf)
  local command = "h"
  if string.match(export, "^@") then
    export = string.sub(export, 2)
    command = "b"
  end
  vim.fn.termopen(table.concat(elixir_pa_flags(opts, {
    " -e 'require IEx.Helpers; IEx.Helpers." .. command .. "(" .. export .. ")'"}), " "))
end

local function telescope_view_module_docs(exports, opts, action)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local previewers = require("telescope.previewers")
  local conf = require("telescope.config").values

  local function entry_maker(entry)
    return {
      value = entry,
      ordinal = entry,
      display = entry,
      contents = entry
    }
  end

  pickers.new({}, {
    prompt_title = "Module exports",
    sorting_strategy = 'ascending',
    finder = finders.new_table {
      results = exports,
      entry_maker = entry_maker,
    },
    previewer = previewers.new_termopen_previewer({
      get_command = function(entry, status)
        export = entry.contents
        local command = "h"
        if string.match(export, "^@") then
          export = string.sub(export, 2)
          command = "b"
        end
        -- https://stackoverflow.com/a/52706650/516188
        local base_cmd = elixir_pa_flags(opts, {
          "-e", "'Application.put_env(:iex, :colors, [enabled: true]); require IEx.Helpers; IEx.Helpers." .. command .. "(" .. export .. ")'"
        })
        return {"sh", "-c", table.concat(base_cmd, " ") .. " | less -RS +0 --tilde"}
      end
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(p, map)
      map("i", "<cr>", function(prompt_nr)
        if action == "view_telescope_module" then
          local action_state = require "telescope.actions.state"
          local current_picker = action_state.get_current_picker(prompt_bufnr) -- picker state
          local entry = action_state.get_selected_entry()
          local actions = require("telescope.actions")
          actions.close(prompt_nr)
          elixir_view_module_docs(entry.contents, opts)
        else
          local action_state = require "telescope.actions.state"
          local current_picker = action_state.get_current_picker(prompt_bufnr) -- picker state
          local entry = action_state.get_selected_entry()
          local actions = require("telescope.actions")
          actions.close(prompt_nr)
          elixir_view_export_docs(entry.contents, opts)
        end
      end)
      return true
    end,
  }):find()
end

local function elixir_view_behaviour_module_docs(mod, exports, opts)
  vim.fn.jobstart(elixir_pa_flags(opts, { "-e", "require IEx.Helpers; IEx.Helpers.b(" .. mod .. ")" }), {
    cwd='.',
    stdout_buffered = true,
    on_stdout = vim.schedule_wrap(function(j, output)
      local cur_callback_name = nil
      local cur_callback_param_count = 0
      local is_opening_bracket = false
      for _, line in ipairs(output) do
        if cur_callback_name == nil then
          if string.match(line, "^@callback ") then
            local end_idx = string.find(line, "%(")
            cur_callback_name = string.sub(line, 11, end_idx-1)
            if string.sub(line, end_idx+1, end_idx+1) == ')' then
              cur_callback_param_count = 0
              goto insert_callback
            elseif end_idx == #line then
              cur_callback_param_count = 0
              goto skip_to_next
            else
              cur_callback_param_count = 1
            end
            for idx = end_idx, #line do
              local char = string.sub(line, idx, idx)
              if char == ',' then
                cur_callback_param_count = cur_callback_param_count + 1
              elseif not is_opening_bracket and char == ')' then
                goto insert_callback
              end 
              is_opening_bracket = char == '('
            end
          end
        else
          if string.match(line, ",$") then
            cur_callback_param_count = cur_callback_param_count + 1
            goto skip_to_next
          else
            -- that was the last parameter
            cur_callback_param_count = cur_callback_param_count + 1
          end
        end
        ::insert_callback::
        if cur_callback_name ~= nil then
          table.insert(exports, "@" .. mod .. "." .. cur_callback_name .. "/" .. cur_callback_param_count)
          cur_callback_name = nil
        end
        ::skip_to_next::
      end
    end),
    on_exit = vim.schedule_wrap(function(j, output)
      telescope_view_module_docs(exports, opts)
    end)
  })
end

function elixir_view_module_docs(mod, opts)
  exports = {mod}
  -- https://stackoverflow.com/questions/52670918
  vim.fn.jobstart(elixir_pa_flags(opts, { "-e", "require IEx.Helpers; IEx.Helpers.exports(" .. mod .. ")" }), {
    cwd='.',
    stdout_buffered = true,
    on_stdout = vim.schedule_wrap(function(j, output)
      for _, line in ipairs(output) do
        for export in string.gmatch(line, "([^%s]+)") do
          table.insert(exports, mod .. "." .. export)
        end
      end
    end),
    on_exit = vim.schedule_wrap(function(j, output)
      elixir_view_behaviour_module_docs(mod, exports, opts)
    end)
  })
end

local function elixir_append_modules_in_folder(modules, folder)
  if vim.fn.isdirectory(folder) == 1 then
    -- the downside of the -pa loading of ecto modules is that it's on-demand loading, so
    -- the modules are not discovered => list them by hand
    -- https://elixirforum.com/t/by-what-mechanism-does-iex-load-beam-files/37102
    --
    -- alternative solution: load the module through elixir itself
    -- elixir -e "IO.inspect(Application.load(:logger); Application.spec(:logger) |> Keyword.get(:modules))"
    local sd = vim.loop.fs_scandir(folder)
    while true do
      local name, type = vim.loop.fs_scandir_next(sd)
      if name == nil then break end
      if name:match("%.beam$") then
        local module = name:gsub("%.beam$", ""):gsub("^Elixir%.", "")
        table.insert(modules, module)
      end
    end
  end
end

local function elixir_view_docs_with_runtime_folders(runtime_module_folders, opts)
  modules = {}
  for _, folder in ipairs(runtime_module_folders) do
    elixir_append_modules_in_folder(modules, folder)
  end
  local extra_mix_folders = get_extra_mix_folders(opts)
  for _, folder in ipairs(extra_mix_folders) do
    elixir_append_modules_in_folder(modules, folder)
  end
  -- https://stackoverflow.com/questions/58461572/get-a-list-of-all-elixir-modules-in-iex#comment103267199_58462672
  -- vim.fn.jobstart(elixir_pa_flags({ "-e", ":erlang.loaded() |> Enum.sort() |> inspect(limit: :infinity) |> IO.puts" }), {
  -- https://github.com/elixir-lang/elixir/blob/60f86886c0f66c71790e61d754eada4e9fa0ace5/lib/iex/lib/iex/autocomplete.ex#L507
  vim.fn.jobstart(elixir_pa_flags(opts, { "-e", ":application.get_key(:elixir, :modules) |> inspect(limit: :infinity) |> IO.puts" }), {
    cwd='.',
    stdout_buffered = true,
    on_stdout = vim.schedule_wrap(function(j, output)
      for mod in string.gmatch(output[1], "([^,%s%[%]]+)") do
        if mod:match("^[A-Z]") then
          table.insert(modules, mod)
        end
      end
    end),
    on_exit = vim.schedule_wrap(function(j, output)
      table.sort(modules)
      telescope_view_module_docs(modules, opts, "view_telescope_module")
    end)
  })
end

local function elixir_view_docs(opts)
  -- get some builtin module paths. These modules are in the load path, but may
  -- not be loaded, but we want the docs for them. ExUnit and Logger are examples
  -- of modules for which we need this.
  module_paths={}
  vim.fn.jobstart({
    "elixir", "-e", [[
      :code.get_path()
      |> Enum.filter(fn p -> String.contains?(inspect(p), "elixir") && !String.contains?(inspect(p), ["/mix/", "/iex/", "elixir/ebin", "eex/ebin"]) end)
      |> IO.inspect()
    ]]
  }, {
    cwd='.',
    stdout_buffered = true,
    on_stdout = vim.schedule_wrap(function(j, output)
      for mod in string.gmatch(table.concat(output), "'([^,%s%[%]]+)'") do
        table.insert(module_paths, mod)
      end
    end),
    on_exit = vim.schedule_wrap(function(j, output)
      table.sort(module_paths)
      elixir_view_docs_with_runtime_folders(module_paths, opts)
    end),
  })
end

return {
  elixir_view_docs = elixir_view_docs,
}
