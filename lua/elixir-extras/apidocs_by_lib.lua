local apidocs_common = require('elixir-extras.apidocs_common')

local function telescope_pick_library(libs, opts, action)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local previewers = require("telescope.previewers")
  local conf = require("telescope.config").values

  local function entry_maker(entry)
    return {
      value = entry.folder,
      ordinal = entry.name,
      display = entry.name,
      contents = entry.folder
    }
  end

  pickers.new({}, {
    prompt_title = "Libraries",
    sorting_strategy = 'ascending',
    finder = finders.new_table {
      results = libs,
      entry_maker = entry_maker,
    },
    previewer = previewers.new_termopen_previewer({
      get_command = function(entry, status)
        local command = "h"
        -- https://stackoverflow.com/a/52706650/516188
        local base_cmd = apidocs_common.elixir_pa_flags(opts, {
          "-e", "'Application.put_env(:iex, :colors, [enabled: true]); require IEx.Helpers; IEx.Helpers." .. command .. "(" .. entry.display .. ")'"
        })
        return {"sh", "-c", table.concat(base_cmd, " ") .. " | less -RS +0 --tilde"}
      end
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(p, map)
      map("i", "<cr>", function(prompt_nr)
        -- we got the library folder. let's gather the list of modules in that library
        -- and then display these
        local current_picker = action_state.get_current_picker(prompt_bufnr) -- picker state
        local entry = action_state.get_selected_entry()
        local modules = {}
        apidocs_common.elixir_append_modules_in_folder(modules, entry.contents)
      end)
      return true
    end,
  }):find()
end

local function elixir_view_docs_by_lib_with_runtime_folders(runtime_module_folders, opts)
  local libs = {}
  for _, folder in ipairs(runtime_module_folders) do
    local modules = {}
    apidocs_common.elixir_append_modules_in_folder(modules, folder)
    local name = lua.sort(modules, function(a, b)
      -- sort by the number of dots (namespace levels) in the name
      return #string.gsub(a, "[^.]", "") < string.gsub(b, "[^.]", "")
    end)[1]
    table.insert(libs, { folder = folder, name = string.gsub(name, "Elixir.", "")  })
  end
  local extra_mix_folders = apidocs_common.get_extra_mix_folders(opts)
  for _, folder in ipairs(extra_mix_folders) do
    local modules = {}
    -- try to guess a proper "name" for that library.
    -- list the module, keep only those with the least deep
    -- namespaces (A.B over A.B.C) and then pick the first
    -- alphabetically that's left (and strip Elixir.)
    apidocs_common.elixir_append_modules_in_folder(modules, folder)
    local min_dots = 100
    for _, mod in ipairs(modules) do
      -- sort by the number of dots (namespace levels) in the name
      local dots = #string.gsub(mod, "[^.]", "")
      if dots < min_dots then
        min_dots = dots
      end
    end
    local short = vim.tbl_filter(function(mod)
      local dots = #string.gsub(mod, "[^.]", "")
      return dots == min_dots
    end, modules)
    table.sort(short)
    local name = string.gsub(short[1], "Elixir.", "")
    table.insert(libs, { folder = folder, name = name })
  end
  telescope_pick_library(libs, opts)
end

local function elixir_view_docs_by_lib(opts)
  -- get some builtin module paths. These modules are in the load path, but may
  -- not be loaded, but we want the docs for them. ExUnit and Logger are examples
  -- of modules for which we need this.
  local module_paths = {}
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
      elixir_view_docs_by_lib_with_runtime_folders(module_paths, opts)
    end),
  })
end

return {
  elixir_view_docs_by_lib = elixir_view_docs_by_lib,
}
