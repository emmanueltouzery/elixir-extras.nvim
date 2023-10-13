(call
  target: (identifier) @identifier (#any-of? @identifier "def" "defp")
  (arguments [
              (call target: (identifier) @name)
              (binary_operator left: (call target: (identifier) @name))
   ])
  ) @type

