# Unity2Eden

Experimental converter from Unity prefabs/scenes to EdenSpark prefabs. Capabilities is very limited and will be extended later.

## Install

In Unity, open *Window → Package Manager → + → Add package from git URL* and use this URL:

```
https://github.com/GaijinEntertainment/EdenSpark-samples.git?path=tools/unity2eden
```

## Configure

Open *Edit → Project Settings → EdenSpark Converter* and set:

- **Export folder** — absolute path on disk where exported files are written.
- **Path remaps** (optional) — rewrites prefixes when computing the output path. Defaults: `Assets/ → assets/`, `Packages/ → packages/`.

Click **Create main.das in export folder** to drop a starter `main.das` at the export root.

## Usage

In the Project window context menu in **Eden** submenu, the following options are available:

- **Export Prefab** — export selected prefab.
- **Export Scene** — export selected scene.
- **Configure Export…** — open the settings panel (see above).
- **Open Export Folder** — reveal the target folder in the filesystem.

## Planned

- Scripts export
- Scriptable object export
- Custom components support
- Nested prefabs support
