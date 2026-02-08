local pipe = "/tmp/godot.pipe"
if not vim.g.godot_pipe_started then
  pcall(vim.fn.serverstart, pipe)  -- creates /tmp/godot.pipe if not already listening
  vim.g.godot_pipe_started = true
end
