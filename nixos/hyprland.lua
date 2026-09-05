-- Desktop configuration. hy3 is loaded by Home Manager before this file.
local hy3 = hl.plugin.hy3

hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_STYLE_OVERRIDE", "adwaita-dark")

-- Monitor modes and positions.
-- MSI MP341CQ is 3440x1440 despite advertising a 4K preferred mode.
hl.monitor({
  output = "eDP-1",
  mode = "1920x1080@60",
  position = "0x0",
  scale = 1,
})
hl.monitor({
  output = "HDMI-A-1",
  mode = "3440x1440@49.99",
  position = "1920x0",
  scale = 1,
})
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1,
})

hl.config({
  input = {
    follow_mouse = 1,
    kb_layout = "drix",
    kb_options = "caps:swapescape,ctrl:swap_lalt_lctl",
    kb_variant = "",
    natural_scroll = true,
    sensitivity = 0,
    touchpad = {
      natural_scroll = true,
    },
  },
  general = {
    border_size = 1,
    ["col.active_border"] = "rgb(38bdf8)",
    ["col.inactive_border"] = "rgb(6c7086)",
    gaps_in = 2,
    gaps_out = 4,
    layout = "hy3",
  },
  decoration = {
    rounding = 0,
    shadow = {
      enabled = true,
      range = 7,
      render_power = 3,
    },
  },
  dwindle = {
    default_split_ratio = 1.0,
    force_split = 2,
    permanent_direction_override = true,
    preserve_split = true,
    smart_resizing = false,
    smart_split = false,
    split_width_multiplier = 1.0,
    use_active_for_splits = true,
  },
  group = {
    auto_group = true,
    ["col.border_active"] = "rgb(38bdf8)",
    ["col.border_inactive"] = "rgb(6c7086)",
    ["col.border_locked_active"] = "rgb(38bdf8)",
    ["col.border_locked_inactive"] = "rgb(6c7086)",
    focus_removed_window = true,
    groupbar = {
      enabled = true,
      font_family = "MesloLGS Nerd Font",
      font_size = 12,
      gradients = false,
      height = 22,
      indicator_height = 2,
      render_titles = true,
      scrolling = true,
      text_padding = 8,
    },
    insert_after_current = true,
  },
  misc = {
    animate_manual_resizes = false,
    background_color = "0xff000000",
    disable_hyprland_logo = true,
    disable_scale_notification = true,
    disable_splash_rendering = true,
  },
  ecosystem = {
    no_update_news = true,
  },
  animations = {
    enabled = true,
  },

})

-- Plugins load after the first config pass; Hyprland then reloads this file.
if hy3 then
  hl.config({
    plugin = {
      hy3 = {
        no_gaps_when_only = 0,
        node_collapse_policy = 2,
        group_inset = 0,
        tab_first_window = false,
        tabs = {
          height = 22,
          padding = 0,
          from_top = true,
          radius = 0,
          border_width = 1,
          render_text = true,
          text_center = false,
          text_font = "MesloLGS Nerd Font",
          text_height = 12,
          text_padding = 8,
          colors = {
            active = "rgb(38bdf8)",
            active_border = "rgb(38bdf8)",
            active_text = "rgb(ffffff)",
            focused = "rgb(062033)",
            focused_border = "rgb(38bdf8)",
            focused_text = "rgb(e8f7ff)",
            inactive = "rgb(000000)",
            inactive_border = "rgb(6c7086)",
            inactive_text = "rgb(e8f7ff)",
            urgent = "rgb(38bdf8)",
            urgent_border = "rgb(38bdf8)",
            urgent_text = "rgb(ffffff)",
            locked = "rgb(38bdf8)",
            locked_border = "rgb(38bdf8)",
            locked_text = "rgb(ffffff)",
          },
          blur = false,
          opacity = 1.0,
        },
        autotile = {
          enable = false,
        },
      },
    },
  })
end

hl.device({
  name = "logitech-usb-receiver-mouse",
  sensitivity = -0.4,
})

hl.curve("snappy", { type = "bezier", points = { {0.15, 0.85}, {0.20, 1.00} } })
hl.animation({
  leaf = "windows",
  enabled = true,
  speed = 12,
  bezier = "snappy",
  style = "popin 80%",
})
hl.animation({
  leaf = "windowsMove",
  enabled = true,
  speed = 14,
  bezier = "snappy",
})
hl.animation({
  leaf = "windowsOut",
  enabled = true,
  speed = 8,
  bezier = "snappy",
  style = "popin 80%",
})
hl.animation({
  leaf = "border",
  enabled = true,
  speed = 12,
  bezier = "snappy",
})
hl.animation({
  leaf = "fade",
  enabled = true,
  speed = 8,
  bezier = "snappy",
})
hl.animation({
  leaf = "workspaces",
  enabled = false,
})

hl.window_rule({ match = { class = "pavucontrol" }, float = true })
hl.window_rule({ match = { class = "codex-desktop" }, tile = true })

hl.on("hyprland.start", function()
  hl.exec_cmd("waybar")
  hl.exec_cmd("mako")
  hl.exec_cmd("systemctl --user restart hypridle.service")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-- Application, layout, workspace and media shortcuts.
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("ghostty"))
hl.bind("SUPER + SHIFT + RETURN", hl.dsp.exec_cmd("alacritty"))
hl.bind("SUPER + O", hl.dsp.exec_cmd("ghostty -e yazi"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + B", hl.dsp.exec_cmd("helium-open"))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("blueman-manager"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("rofi -show drun"))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("rofi -show combi -combi-modes drun,run"))
hl.bind("SUPER + TAB", hl.dsp.exec_cmd("rofi -show window"))
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("rofi-rbw --action copy --target password"))
hl.bind("SUPER + CTRL + P", hl.dsp.exec_cmd("rofi-rbw --action type --target password"))
hl.bind("SUPER + SHIFT + X", hl.dsp.exec_cmd("systemctl sleep"))
if hy3 then
  hl.bind("SUPER + H", hy3.move_focus("l"))
  hl.bind("SUPER + J", hy3.move_focus("d"))
  hl.bind("SUPER + K", hy3.move_focus("u"))
  hl.bind("SUPER + L", hy3.move_focus("r"))
  hl.bind("SUPER + LEFT", hy3.move_focus("l"))
  hl.bind("SUPER + DOWN", hy3.move_focus("d"))
  hl.bind("SUPER + UP", hy3.move_focus("u"))
  hl.bind("SUPER + RIGHT", hy3.move_focus("r"))
  hl.bind("SUPER + SHIFT + H", hy3.move_window("l"))
  hl.bind("SUPER + SHIFT + J", hy3.move_window("d"))
  hl.bind("SUPER + SHIFT + K", hy3.move_window("u"))
  hl.bind("SUPER + SHIFT + L", hy3.move_window("r"))
  hl.bind("SUPER + SHIFT + LEFT", hy3.move_window("l"))
  hl.bind("SUPER + SHIFT + DOWN", hy3.move_window("d"))
  hl.bind("SUPER + SHIFT + UP", hy3.move_window("u"))
  hl.bind("SUPER + SHIFT + RIGHT", hy3.move_window("r"))
end
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + SHIFT + SPACE", hl.dsp.window.float())
if hy3 then
  hl.bind("SUPER + A", hy3.change_focus("raise"))
  hl.bind("SUPER + W", hy3.change_group("tab"))
end
hl.bind("SUPER + E", hl.dsp.exec_cmd("hypr-hy3-toggle-split"))
if hy3 then
  hl.bind("SUPER + SHIFT + E", hy3.change_group("untab"))
  hl.bind("SUPER + BRACKETLEFT", hy3.focus_tab( { direction = "l", wrap = true }))
  hl.bind("SUPER + BRACKETRIGHT", hy3.focus_tab( { direction = "r", wrap = true }))
end
hl.bind("SUPER + R", hl.dsp.submap("resize"))
hl.bind("Print", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]))
hl.bind("SUPER + Print", hl.dsp.exec_cmd("grim - | wl-copy"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("push-to-talk-toggle-wayland"))
hl.bind("SUPER + P", hl.dsp.exec_cmd("hypr-projector menu"))
hl.bind("XF86Display", hl.dsp.exec_cmd("hypr-projector menu"))
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = "1" }))
hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({ workspace = "1", follow = true }))
hl.bind("SUPER + 2", hl.dsp.focus({ workspace = "2" }))
hl.bind("SUPER + SHIFT + 2", hl.dsp.window.move({ workspace = "2", follow = true }))
hl.bind("SUPER + 3", hl.dsp.focus({ workspace = "3" }))
hl.bind("SUPER + SHIFT + 3", hl.dsp.window.move({ workspace = "3", follow = true }))
hl.bind("SUPER + 4", hl.dsp.focus({ workspace = "4" }))
hl.bind("SUPER + SHIFT + 4", hl.dsp.window.move({ workspace = "4", follow = true }))
hl.bind("SUPER + 5", hl.dsp.focus({ workspace = "5" }))
hl.bind("SUPER + SHIFT + 5", hl.dsp.window.move({ workspace = "5", follow = true }))
hl.bind("SUPER + 6", hl.dsp.focus({ workspace = "6" }))
hl.bind("SUPER + SHIFT + 6", hl.dsp.window.move({ workspace = "6", follow = true }))
hl.bind("SUPER + 7", hl.dsp.focus({ workspace = "7" }))
hl.bind("SUPER + SHIFT + 7", hl.dsp.window.move({ workspace = "7", follow = true }))
hl.bind("SUPER + 8", hl.dsp.focus({ workspace = "8" }))
hl.bind("SUPER + SHIFT + 8", hl.dsp.window.move({ workspace = "8", follow = true }))
hl.bind("SUPER + 9", hl.dsp.focus({ workspace = "9" }))
hl.bind("SUPER + SHIFT + 9", hl.dsp.window.move({ workspace = "9", follow = true }))
hl.bind("SUPER + 0", hl.dsp.focus({ workspace = "10" }))
hl.bind("SUPER + SHIFT + 0", hl.dsp.window.move({ workspace = "10", follow = true }))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pamixer -i 10"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer -d 10"), { repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +10%"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pamixer -t"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pamixer --default-source -t"), { locked = true })
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.define_submap("resize", function()
  hl.bind("H", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
  hl.bind("J", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
  hl.bind("K", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
  hl.bind("L", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
  hl.bind("LEFT", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
  hl.bind("DOWN", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
  hl.bind("UP", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
  hl.bind("RIGHT", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
  hl.bind("RETURN", hl.dsp.submap("reset"))
  hl.bind("ESCAPE", hl.dsp.submap("reset"))
  hl.bind("SUPER + R", hl.dsp.submap("reset"))
end)
