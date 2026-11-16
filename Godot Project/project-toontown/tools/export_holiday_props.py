"""Export the winter and Halloween prop nodes the DNA storage files swap in."""
from __future__ import annotations

import json
import re
import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData

from export_toontown_central import GltfWriter


ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
OUT = ROOT / "assets" / "holidays"
MODEL_RE = re.compile(r'(?:hood_model|place_model)\s+"([^"]+)"')
STORE_RE = re.compile(r'store_node\s*\[\s*"holiday_prop"\s+"([^"]+)"(?:\s+"([^"]*)")?')


def parse_storage(text: str) -> list[tuple[str, str, str]]:
    current = ""
    found: list[tuple[str, str, str]] = []
    for raw in text.splitlines():
        line = raw.split("//", 1)[0]
        model = MODEL_RE.search(line)
        if model:
            current = model.group(1)
            if not current.endswith(".bam"):
                current += ".bam"
        store = STORE_RE.search(line)
        if store and current:
            code = store.group(1)
            # A missing search name is the code. An empty one stores the model.
            node = code if store.group(2) is None else store.group(2)
            found.append((current, code, node))
    return found


def find_piece(model: NodePath, code: str, node_name: str) -> NodePath:
    if node_name:
        found = model.find("**/" + node_name)
        if found.isEmpty():
            found = model.find("**/" + code)
        return found
    # Dreamland's halloween bam packs both trees in one file. Left is ul.
    if code.endswith("_ul"):
        side = model.find("**/tree_ddl_halloweenL")
        if not side.isEmpty():
            return side
    if code.endswith("_ur"):
        side = model.find("**/tree_ddl_halloweenR")
        if not side.isEmpty():
            return side
    return model


def load_model(loader: Loader, relative: str, cache: dict[str, NodePath | None]) -> NodePath | None:
    if relative in cache:
        return cache[relative]
    path = ASSETS.joinpath(*relative.split("/"))
    node = loader.loadSync(Filename.from_os_specific(str(path)))
    if node is None:
        print("missing", path, flush=True)
        cache[relative] = None
        return None
    model = NodePath(node)
    cache[relative] = model
    return model


def export_node(found: NodePath, code: str, dest: Path) -> int:
    wrapper = NodePath(code)
    clone = found.copyTo(wrapper)
    clone.setPosHprScale(0, 0, 0, 0, 0, 0, 1, 1, 1)
    clone.show()
    for piece in clone.findAllMatches("**/*collision*"):
        piece.detachNode()
    writer = GltfWriter()
    writer.add_node(wrapper, None)
    if writer.mesh_count == 0:
        clone.show()
        for child in clone.findAllMatches("**"):
            child.show()
        for piece in clone.findAllMatches("**/*collision*"):
            piece.detachNode()
        writer = GltfWriter()
        writer.add_node(wrapper, None)
    payload = writer.pack(code)
    dest.write_bytes(payload)
    wrapper.removeNode()
    return writer.mesh_count


def main() -> int:
    loadPrcFileData("", "model-cache-dir")
    getModelPath().prependDirectory(Filename.from_os_specific(str(ASSETS)))
    loader = Loader.getGlobalPtr()
    cache: dict[str, NodePath | None] = {}
    catalog: dict[str, dict[str, str]] = {"winter": {}, "halloween": {}}
    missing: list[str] = []
    written = 0
    for kind, pattern in (("winter", "winter_storage*.dna"), ("halloween", "halloween_props_storage*.dna")):
        folder = OUT / kind
        folder.mkdir(parents=True, exist_ok=True)
        files = sorted(ASSETS.glob(f"phase_*/dna/{pattern}"))
        print(kind, len(files), "dna", flush=True)
        for dna in files:
            rows = parse_storage(dna.read_text(encoding="utf-8", errors="replace"))
            print(" ", dna.name, len(rows), flush=True)
            for relative, code, node_name in rows:
                if code in catalog[kind]:
                    continue
                model = load_model(loader, relative, cache)
                if model is None:
                    missing.append(f"{kind} {code} {relative}")
                    continue
                found = find_piece(model, code, node_name)
                if found.isEmpty():
                    print("  no node", code, node_name, "in", relative, flush=True)
                    missing.append(f"{kind} {code} node {node_name}")
                    continue
                dest = folder / f"{code}.glb"
                meshes = export_node(found, code, dest)
                catalog[kind][code] = f"res://assets/holidays/{kind}/{code}.glb"
                written += 1
                print(f"  {code} meshes={meshes}", flush=True)
                if meshes == 0:
                    missing.append(f"{kind} {code} empty")
    (OUT / "props.json").write_text(json.dumps(catalog, indent=1), encoding="utf-8")
    print("wrote", written, "missing", len(missing), flush=True)
    for row in missing:
        print("MISSING", row, flush=True)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
