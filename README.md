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

Leverage the elixir binary behind the scenes to display apidocs in a telescope picker. These are the apidocs as known by your elixir repl, so the versions match exactly with the libraries you're actually using. If you passe in `include_mix_libs=true`, then all libraries will be taken into account, otherwise only elixir core libraries.

## multiple_clause_gutter

![clauses gutter screenshot](https://raw.githubusercontent.com/wiki/emmanueltouzery/elixir-extras.nvim/gutter_clauses.png)

```lua
:lua require'elixir-extras'.setup_multiple_clause_gutter()
```

Uses tree-sitter to display markers in the gutter to mark multiple clauses of a single function. For each clause, you can see whether it's part of a multi-clause function, and whether it's the first or last clause or not.
