# elixir-extras.nvim

A set of neovim functions that I wrote to work with the elixir programming language.

telescope.nvim is a required dependency.

I'll now list individual functions...

## elixir_view_docs

![view docs screenshot](https://raw.githubusercontent.com/wiki/emmanueltouzery/elixir-extras.nvim/apidocs.png)

```lua
:lua require('elixir-extras').elixir_view_docs({})
:lua require('elixir-extras').elixir_view_docs({include_mix_libs=true})
```

Leverage the elixir binary behind the scenes to display apidocs in a telescope picker. These are the apidocs as known by your elixir repl, so the versions match exactly with the libraries you're actually using, and they'll include the documentation for your own application. If you pass in `include_mix_libs=true`, then all libraries will be taken into account, otherwise only elixir core libraries.

There will be two telescope pickers, in the first one you pick one or multiple modules (you can pick several ones using the `<tab>` key by default in telescope). Then in a second picker you can view the documentation for the functions for the selected module(s), and pressing enter will open the documentation for a single module in a buffer.

In addition, in the telescope picker, you can press `C-s`, control-s, to open the source code of the currently selected module or function in the editor.

## multiple_clause_gutter

![clauses gutter screenshot](https://raw.githubusercontent.com/wiki/emmanueltouzery/elixir-extras.nvim/gutter_clauses.png)

```lua
:lua require'elixir-extras'.setup_multiple_clause_gutter()
```

Uses tree-sitter to display markers in the gutter to mark multiple clauses of a single function. For each clause, you can see whether it's part of a multi-clause function, and whether it's the first or last clause or not.

## module_complete

```lua
:lua require'elixir-extras'.module_complete()
```

Uses LSP to complete the module name under the cursor. For instance, if you have `MyModule` under the cursor, this function will search for LSP symbols ending in `.MyModule`. Let's say it finds `MyParent.Nested.MyModule`: it will then replace the text under the cursor with that. If there are multiple matches, it will ask the user to pick one (this will look nicer if you install <https://github.com/stevearc/dressing.nvim>).
