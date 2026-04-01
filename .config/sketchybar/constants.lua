local events <const> = {
  AEROSPACE_WORKSPACE_CHANGED = "aerospace_workspace_changed",
  AEROSPACE_SWITCH = "aerospace_switch",
  SWAP_MENU_AND_SPACES = "swap_menu_and_spaces",
  FRONT_APP_SWITCHED = "front_app_switched",
  UPDATE_WINDOWS = "update_windows",
  SPACE_WINDOWS_CHANGE = "space_windows_change",
  SEND_MESSAGE = "send_message",
  HIDE_MESSAGE = "hide_message",
  ACCORDION_MODE_ON = "accordion_mode_on",
  ACCORDION_MODE_OFF = "accordion_mode_off",
}

local items <const> = {
  SPACES = "workspaces",
  MENU = "menu",
  MENU_TOGGLE = "menu_toggle",
  FRONT_APPS = "front_apps",
  WINDOW_TITLES = "window_title",
  MESSAGE = "message",
  VOLUME = "widgets.volume",
  WIFI = "widgets.wifi",
  BATTERY = "widgets.battery",
  CALENDAR = "widgets.calendar",
  CPU = "widgets.cpu",
  MEMORY = "widgets.memory",
  WEATHER = "widgets.weather",
}

local aerospace <const> = {
  LIST_ALL_WORKSPACES = "/opt/homebrew/bin/aerospace list-workspaces --all",
  LIST_NON_EMPTY_WORKSPACES = "/opt/homebrew/bin/aerospace list-workspaces --monitor all --empty no",
  GET_CURRENT_WORKSPACE = "/opt/homebrew/bin/aerospace list-workspaces --focused",
  GET_CURRENT_WORKSPACE_LAYOUT = "/opt/homebrew/bin/aerospace list-workspaces --focused --format %{workspace-root-container-layout}",
  LIST_WINDOWS = "/opt/homebrew/bin/aerospace list-windows --workspace focused --format \"id=%{window-id}, name=%{app-name}\"",
  LIST_WORKSPACE_WINDOWS = "/opt/homebrew/bin/aerospace list-windows --workspace %s --format %%{app-name}",
  GET_CURRENT_WINDOW = "/opt/homebrew/bin/aerospace list-windows --focused --format %{app-name}",
  LIST_WINDOWS_WITH_TITLES = '/opt/homebrew/bin/aerospace list-windows --workspace focused --format "%{window-id}|%{app-name}|%{window-title}"',
  GET_FOCUSED_WINDOW_ID = "/opt/homebrew/bin/aerospace list-windows --focused --format %{window-id}",
  LIST_VISIBLE_WINDOW_X_POSITIONS = "/Users/adrian/.config/sketchybar/scripts/list_visible_window_x_positions.sh",
  GET_H_ACCORDION_CONTEXT = "/bin/sh /Users/adrian/.config/sketchybar/scripts/get_h_accordion_context.sh",
  QUERY_DISPLAYS = "/opt/homebrew/bin/sketchybar --query displays",
}

return {
  items = items,
  events = events,
  aerospace = aerospace,
}
