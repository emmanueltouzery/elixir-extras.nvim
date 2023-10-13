local apidocs = require('elixir-extras.apidocs')
local multiple_clause_gutter = require('elixir-extras.multiple_clause_gutter')

return {
  elixir_view_docs = apidocs.elixir_view_docs,
  setup_multiple_clause_gutter = multiple_clause_gutter.setup_multiple_clause_gutter,
}
