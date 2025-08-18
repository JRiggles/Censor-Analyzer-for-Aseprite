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

local preferences = {} -- create a table to store extension preferences

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

-- NOTE: app.os.arm64 isn't working on Mac - Need to confirm on other OS's; bug in Aseprite API?
local function selectExecutable()
  if app.os.macos then
    return "/bin/macOS/censor"

  elseif app.os.linux then
    if app.os.arm64 then
      return "/executable/linux/arm/censor"
    elseif app.os.x64 then
      return "/bin/linux/x64/censor"
    else
      return app.alert("32-bit Linux is not supported.")
    end

  elseif app.os.windows then
    if app.os.x64 then
      return "\\bin\\win\\censor.exe"
    else
      return app.alert("32-bit Windows is not supported.")
    end

  else
    return app.alert("Unsupported operating system.")
  end
end

local function removeExistingAnalysisFile(outputFile)
  if app.fs.isFile(outputFile) then
    if app.os.windows then
      os.execute('del /f /q "' .. outputFile .. '"')
    else -- for macOS and Linux
      os.execute("rm -f " .. outputFile)
    end
  end
end

local function performCensorAnalysis(colorList)
  local outputFile = app.fs.joinPath(PluginPath, "analysis.png")
  removeExistingAnalysisFile(outputFile)

  -- the censor executable is bundled with the extension, so we need to choose the correct build
  -- for the current operating system
  local executablePath = '"' .. PluginPath .. selectExecutable() .. '"'
  -- build command to run the palette analysis
  local command = string.format('%s analyse -c %s -o "%s"', executablePath, colorList, outputFile)

  if app.os.windows then
    -- on Windows, we need to use cmd /c to run the command in a new command prompt
    os.execute('start cmd /c "' .. command .. '"')
  else -- for macOS and Linux
    os.execute(command)  -- note: may need to use os.execute("sh -c '" .. command .. "'")
  end

  local retryCount = 0
  local maxRetries = 10 -- maximum number of retries to check for the output file

  -- create a timer to check for the output file every 0.5 seconds
  -- (mostly for Windows, which can take a while to generate the file for some reason)
  FileTimer = Timer{
    interval=0.5,
    ontick=function()
      if app.fs.isFile(outputFile) then
        FileTimer:stop() -- stop the timer if the file is created
        app.refresh() -- refresh Aseprite to ensure the file is recognized
        -- open the generated analysis file in Aseprite
        app.command.openFile { filename = app.fs.normalizePath(outputFile) }
      elseif retryCount >= maxRetries then
        FileTimer:stop() -- stop the timer after max retries
        app.alert {
          title = "Censor palette analysis failed",
          text = "Could not generate an analysis plot for this palette."
        }
      else
        retryCount = retryCount + 1
      end
    end }
  FileTimer:start()
end

local function main()
  local sprite = getActiveSprite()
  if not sprite then
    return
  end

  local palette = getSpritePalette(sprite)
  if not palette then
    return
  end

  local colorList = buildColorList(palette)
  performCensorAnalysis(colorList)
end

-- Aseprite plugin API stuff...
---@diagnostic disable-next-line: lowercase-global
function init(plugin) -- initialize extension
  preferences = plugin.preferences -- update preferences global with plugin.preferences values

  PluginPath = plugin.path -- store this plugin's path in a global variable

  plugin:newMenuSeparator {group = "palette_generation"}
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
