# DockSwitch Icon Notes

Concept: liquid-glass tile with a toggle-and-route motif.

- Base: soft cyan/teal gradient rounded square.
- Mid layer: translucent "glass panel" with bright edge highlight.
- Glyph: horizontal switch track + white knob + directional paths to communicate "switching" between setups.
- Tone: friendly utility, not enterprise-heavy.

## Conversion to .icns

1. Export PNG variants from the SVG: `1024, 512, 256, 128, 64, 32, 16` and `@2x` sizes.
2. Place files in `DockSwitch.iconset` with Apple naming (for example `icon_16x16.png`, `icon_16x16@2x.png`, etc).
3. Build iconset:

```bash
iconutil -c icns DockSwitch.iconset
```

4. Put resulting `DockSwitch.icns` into app resources and reference in `Info.plist` using `CFBundleIconFile`.
