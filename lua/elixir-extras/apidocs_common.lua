local function get_extra_mix_folders(opts)
  local extra_mix_folders = {}

  if opts and opts.include_mix_libs then
    -- in theory I should load modules through -S mix but.. i couldn't make it work
    -- from neovim, it's slow and so on.
    local processed_libs = {}
    local base_path = './_build/dev/lib/'
    local sd = vim.loop.fs_scandir(base_path)
    while sd ~= nil do
      local name, type = vim.loop.fs_scandir_next(sd)
      if name == nil then break end
      processed_libs[name] = true
      table.insert(extra_mix_folders, base_path .. name .. '/ebin/')
    end

    base_path = './_build/test/lib/'
    sd = vim.loop.fs_scandir(base_path)
    while sd ~= nil do
      local name, type = vim.loop.fs_scandir_next(sd)
      if name == nil then break end
      if not processed_libs[name] then
        table.insert(extra_mix_folders, base_path .. name .. '/ebin/')
      end
    end
  end

  return extra_mix_folders
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

local function elixir_pa_flags(opts, flags)
  local res = {"elixir"}

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

return {
  get_extra_mix_folders = get_extra_mix_folders,
  elixir_append_modules_in_folder = elixir_append_modules_in_folder,
  elixir_pa_flags = elixir_pa_flags,
}
