# Texture Cooker

This tool is responsible for deterministically converting source PNG textures into GPU-ready KTX2 atlases.

---

## Responsibilities

- Each subdirectory in `assets/src/textures/` defines exactly one texture atlas.
- All PNG files within a subdirectory are packed into a single KTX2 atlas.
- Cooked output is written to `assets/cooked/textures/`.

---

## Behavior

### On Subdirectory Creation
- Build a new KTX2 atlas from all PNGs in that directory.
- Add or update the corresponding entry in the JSON manifest.

### On Subdirectory Removal
- Remove the associated KTX2 atlas from the cooked directory.
- Remove the entry from the JSON manifest.

### On PNG Add / Modify / Move
- Rebuild the entire atlas for the affected subdirectory.
- Replace the previous KTX2 atlas atomically.
- Update the JSON manifest revision.

---

## Notes

- The cooker always rebuilds atlases deterministically from source.
- No partial or incremental atlas edits are performed.
- The JSON manifest is the single source of truth for cooked texture state.

---

## Directory Layout

```text
assets/src/textures/        # Source PNGs (subdirs define atlases)
assets/cooked/textures/     # Cooked KTX2 atlases + manifest.json

