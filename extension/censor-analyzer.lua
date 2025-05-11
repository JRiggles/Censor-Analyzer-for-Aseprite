--[[
MIT LICENSE
Copyright © 2025 John Riggles [sudo_whoami]

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

-- stop complaining about unknown Aseprite API methods
---@diagnostic disable: undefined-global
-- ignore dialogs which are defined with local names for readablity, but may be unused
---@diagnostic disable: unused-local

local preferences = {} -- create a global table to store extension preferences

local function getActiveSprite()
  local sprite = app.sprite
  if not sprite then
    return app.alert("No active sprite found.")
  end
  return sprite
end

local function getSpritePalette(sprite)
  local palette = sprite.palettes[1]
  if not palette then
    return app.alert("This sprite has no palette.")
  end

  local nColors = #palette
  if nColors < 2 then
    return app.alert("The palette must contain at least 2 colors.")
  elseif nColors > 256 then
    return app.alert("The palette must contain no more than 256 colors.")
  end
  return palette
end

local function buildColorList(palette)
  local hexColors = {}
  local nColors = #palette
  for i = 0, nColors - 1 do
    local color = palette:getColor(i)
    local hex = string.format("%02x%02x%02x", color.red, color.green, color.blue)
    table.insert(hexColors, hex)
  end
  return table.concat(hexColors, ",")
end

local function locateExecutable()
  if app.os.macos then
    return "/executable/macOS/censor"
  elseif app.os.linux then
    -- return = "executable/linux/censor"
    return app.alert("This extension is macOS only for now! Please check back later.") -- TODO
  elseif app.os.windows then
    -- return "executable/win/censor.exe"
    return app.alert("This extension is macOS only for now! Please check back later.") -- TODO
  else
    return app.alert("Unsupported OS. This operating system is not recognized.")
  end
end

local function removeExistingAnalysisFile(outputFile)
  if app.fs.isFile(outputFile) then
    os.execute("rm -f " .. outputFile)
  end
end

local function performCensorAnalysis(colorList)
  local userDocsPath = app.fs.userDocsPath
  local outputFile = app.fs.joinPath(userDocsPath, "analysis.png")
  removeExistingAnalysisFile(outputFile)

  -- The censor executable is bundled with the extension, so we need to find it
  local extensionPath = app.fs.joinPath(
    app.fs.userConfigPath,
    "extensions/censor-analyzer-for-aseprite"
  )
  local executablePath = locateExecutable()

  -- executablePath = "\"" .. app.fs.joinPath(extensionPath, executablePath) .. "\""
  -- executablePath = "/Users/jriggles/.cargo/bin/censor"
  executablePath = app.fs.joinPath(userDocsPath, ".cargo/bin/censor")

  if not app.fs.isFile(executablePath) then
    return app.alert{
      title="Censor executable not found",
      text="Please install the Censor CLI from https://github.com/quickmarble/censor"
    }
  end

  local command = executablePath ..  " analyse -c " .. colorList .. " -o \"" .. outputFile .. "\""
  -- print(command)  -- for debugging
  os.execute(command)

  if app.fs.isFile(outputFile) then
    app.command.openFile { filename = app.fs.normalizePath(outputFile) }
  else
    app.alert{
      title="Censor palette analysis failed",
      text="Could not generate an analysis plot for this palette."
    }
  end
end

local function main()
  local sprite = getActiveSprite()
  if not sprite then return end

  local palette = getSpritePalette(sprite)
  if not palette then return end

  local colorList = buildColorList(palette)
  performCensorAnalysis(colorList)
end

-- Aseprite plugin API stuff...
---@diagnostic disable-next-line: lowercase-global
function init(plugin) -- initialize extension
  preferences = plugin.preferences -- update preferences global with plugin.preferences values

  plugin:newCommand {
    id = "censorAnalyze",
    title = "Analyze Palette with Censor",
    group = "palette_generation",
    onclick = main -- run main function
  }
end

---@diagnostic disable-next-line: lowercase-global
function exit(plugin)
  plugin.preferences = preferences -- save preferences
  return nil
end
