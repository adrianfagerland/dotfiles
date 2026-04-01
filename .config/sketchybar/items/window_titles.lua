local constants = require("constants")
local settings = require("config.settings")

sbar.add("event", constants.events.ACCORDION_MODE_ON)
sbar.add("event", constants.events.ACCORDION_MODE_OFF)

local ITEM_PREFIX = constants.items.WINDOW_TITLES
local MATCHED_LAYOUT = "h_accordion"
local ACCORDION_PADDING = 30
local OUTER_GAP = 10
local INNER_GAP = 10
local MIN_COLLAPSED_WIDTH = 84
local BOTTOM_MARGIN = 16
local ICON_RESERVE = 38
local RIBBON_CONTENT_Y_OFFSET = 4
local DEFAULT_DISPLAY = {
  width = 3440,
  height = 1440,
}

local titleItems = {}

local watcher = sbar.add("item", {
  drawing = false,
  updates = true,
})

local function clearTitles()
  sbar.remove("/" .. ITEM_PREFIX .. "\\..*/")
  titleItems = {}
end

local function trim(str)
  if not str then return "" end
  return str:match("^%s*(.-)%s*$")
end

local function truncate(str, maxLen)
  if not str or str == "" then return "" end
  if #str <= maxLen then return str end
  return str:sub(1, maxLen) .. "…"
end

local function getRibbonFrame(display)
  local sideInset = OUTER_GAP
  local totalWidth = math.max(240, display.width - (sideInset * 2))
  local popupYOffset = display.height
    - settings.dimens.graphics.bar.height
    - settings.dimens.graphics.bar.offset
    - settings.dimens.graphics.background.height
    - BOTTOM_MARGIN

  return {
    totalWidth = totalWidth,
    popupYOffset = popupYOffset,
  }
end

local function buildWidths(count, totalWidth)
  if count <= 0 then return {} end

  local usableWidth = math.max(240, totalWidth - (INNER_GAP * math.max(count - 1, 0)))
  if count == 1 then return { usableWidth } end

  local segmentWidth = math.max(MIN_COLLAPSED_WIDTH, math.floor(usableWidth / count))
  local widths = {}
  for index = 1, count do
    widths[index] = segmentWidth
  end

  local remainingWidth = usableWidth - (segmentWidth * count)
  if remainingWidth > 0 then
    widths[count] = widths[count] + remainingWidth
  end

  return widths
end

local function getTitleMaxLength(width)
  return math.max(6, math.floor((width - ICON_RESERVE) / 8))
end

local function parseVisibleWindowPositions(output)
  local positions = {}

  for line in (output or ""):gmatch("[^\r\n]+") do
    local id, x = line:match("^(%d+)|(-?%d+)$")
    if id and x then
      positions[tonumber(id)] = tonumber(x)
    end
  end

  return positions
end

local function parseAccordionContext(output)
  local layout = ""
  local focusedId = nil
  local windows = {}
  local positionLines = {}
  local currentSection = nil

  for line in (output or ""):gmatch("[^\r\n]+") do
    if line == "windows-begin" then
      currentSection = "windows"
    elseif line == "windows-end" then
      currentSection = nil
    elseif line == "positions-begin" then
      currentSection = "positions"
    elseif line == "positions-end" then
      currentSection = nil
    elseif currentSection == "windows" then
      local id, appName, title = line:match("^(%d+)|([^|]*)|(.*)$")
      if id then
        table.insert(windows, { id = tonumber(id), app = appName, title = title })
      end
    elseif currentSection == "positions" then
      table.insert(positionLines, line)
    else
      local value = line:match("^layout|(.*)$")
      if value ~= nil then
        layout = trim(value)
      else
        value = line:match("^focused|(.*)$")
        if value ~= nil and value ~= "" then
          focusedId = tonumber(trim(value))
        end
      end
    end
  end

  return layout, focusedId, windows, parseVisibleWindowPositions(table.concat(positionLines, "\n"))
end

local function sortWindowsByScreenPosition(windows, positions)
  table.sort(windows, function(left, right)
    local leftX = positions[left.id]
    local rightX = positions[right.id]

    if leftX and rightX and leftX ~= rightX then
      return leftX < rightX
    end
    if leftX and not rightX then
      return true
    end
    if rightX and not leftX then
      return false
    end

    return left.id < right.id
  end)
end

local function makeSpacer(name, width)
  titleItems[name] = sbar.add("item", name, {
    position = "center",
    width = math.max(1, width),
    icon = { drawing = false },
    label = { drawing = false },
    background = { drawing = false },
  })
end

local function makeAnchor(name, width, popupYOffset)
  titleItems[name] = sbar.add("item", name, {
    position = "center",
    width = math.max(1, width),
    icon = { drawing = false },
    label = { drawing = false },
    background = { drawing = false },
    popup = {
      drawing = true,
      align = "center",
      y_offset = popupYOffset,
      background = {
        drawing = false,
      },
    },
  })
end

local function makeIconConfig(appName, isFocused)
  local icon = settings.icons.apps[appName] or settings.icons.apps["Default"]
  local iconConfig = {
    string = icon,
    color = isFocused and settings.colors.bg1 or settings.colors.white,
    padding_left = 8,
    padding_right = 6,
    y_offset = RIBBON_CONTENT_Y_OFFSET,
  }

  if icon:sub(1, 1) == ":" and icon:sub(-1) == ":" then
    iconConfig.font = settings.fonts.icons()
  end

  return iconConfig
end

local function makePopupItem(name, anchorName, win, width, isFocused)
  local title = trim(win.title)
  if title == "" then title = win.app end

  titleItems[name] = sbar.add("item", name, {
    position = "popup." .. anchorName,
    width = math.max(1, width),
    icon = makeIconConfig(win.app, isFocused),
    label = {
      string = truncate(title, getTitleMaxLength(width)),
      color = isFocused and settings.colors.bg1 or settings.colors.white,
      padding_left = 0,
      padding_right = 8,
      y_offset = RIBBON_CONTENT_Y_OFFSET,
      font = {
        family = settings.fonts.text,
        style = isFocused and settings.fonts.styles.bold or settings.fonts.styles.regular,
        size = 12.0,
      },
    },
    background = {
      drawing = true,
      color = isFocused and settings.colors.orange or settings.colors.bg1,
      corner_radius = 6,
      height = 22,
      y_offset = RIBBON_CONTENT_Y_OFFSET,
    },
    click_script = "/opt/homebrew/bin/aerospace focus --window-id " .. win.id,
  })
end

local function renderRibbon(windows, focusedId, display)
  clearTitles()

  if #windows == 0 then return end

  local frame = getRibbonFrame(display)
  local widths = buildWidths(#windows, frame.totalWidth)

  for index, win in ipairs(windows) do
    local anchorName = ITEM_PREFIX .. ".anchor." .. win.id
    makeAnchor(anchorName, widths[index], frame.popupYOffset)
    makePopupItem(ITEM_PREFIX .. ".popup." .. win.id, anchorName, win, widths[index], win.id == focusedId)

    if index < #windows then
      makeSpacer(ITEM_PREFIX .. ".gap." .. index, INNER_GAP)
    end
  end
end

local function loadRibbon()
  sbar.exec(constants.aerospace.GET_H_ACCORDION_CONTEXT, function(contextOutput)
    local layout, focusedId, windows, positions = parseAccordionContext(contextOutput)

    if layout ~= MATCHED_LAYOUT then
      clearTitles()
      return
    end

    if #windows == 0 then
      clearTitles()
      return
    end

    sortWindowsByScreenPosition(windows, positions)
    renderRibbon(windows, focusedId, DEFAULT_DISPLAY)
  end)
end

local function scheduleRibbonRefresh(delaySeconds)
  sbar.exec(string.format("/bin/sh -c 'sleep %.2f'", delaySeconds), function()
    loadRibbon()
  end)
end

local function refreshRibbonAfterLayoutChange()
  loadRibbon()
  scheduleRibbonRefresh(0.20)
end

watcher:subscribe(constants.events.ACCORDION_MODE_ON, refreshRibbonAfterLayoutChange)
watcher:subscribe(constants.events.ACCORDION_MODE_OFF, clearTitles)
watcher:subscribe(constants.events.FRONT_APP_SWITCHED, loadRibbon)
watcher:subscribe(constants.events.UPDATE_WINDOWS, loadRibbon)
watcher:subscribe(constants.events.SPACE_WINDOWS_CHANGE, loadRibbon)
watcher:subscribe(constants.events.AEROSPACE_WORKSPACE_CHANGED, refreshRibbonAfterLayoutChange)

loadRibbon()
