local plugin = require("func_jumpr")

describe("setup", function()
  it("works with default", function()
    assert(plugin.show_function() == "Hello!", "my first function with param = Hello!")
  end)

  it("works with custom var", function()
    plugin.setup({ opt = "custom" })
    assert(plugin.get_functions() == "custom", "my first function with param = custom")
  end)
end)
