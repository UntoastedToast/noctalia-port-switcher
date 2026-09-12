# Port Switcher

A [Noctalia](https://noctalia.dev) plugin that switches a sound card's active
output **port** (e.g. "Headphones" vs "Line Out" on the same analog jack),
not the default *sink*. Most audio switchers only cycle between separate
devices; this one targets cards that expose several ports on a single sink.

- A bar widget shows the active port and its glyph; left-click opens the panel.
- The panel lists every selectable port on the default output as a tile;
  click a tile to switch. The panel stays empty when the current output has
  only one port (most setups).
- Everything goes through `pactl` (`list sinks`, `set-sink-port`), so it works
  with PipeWire-pulse or PulseAudio alike.

## Installing

In Noctalia: Settings → Plugins → add a personal plugin source pointing at
this repository, then enable "Port Switcher".

## Compositor keybind

```
noctalia msg plugin UntoastedToast/port-switcher:service all set_port analog-output-headphones
```

Replace the port name with whatever `pactl list sinks | grep -A5 'Ports:'`
reports for your card.
