"""Crop the closet Done and Cancel buttons from create_a_toon_gui."""
from __future__ import annotations

import sys
from pathlib import Path

from panda3d.core import Filename, GeomNode, GeomVertexReader, getModelPath, loadPrcFileData

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import export_dialog  # noqa: E402

DEST = TOOLS.parent / "assets" / "toons" / "gui"


def bounds(node) -> None:
	geom_node = node.node()
	if not geom_node.isOfType(GeomNode.getClassType()):
		node = node.find("**/+GeomNode")
		geom_node = node.node()
	xs = []
	zs = []
	for geom_index in range(geom_node.getNumGeoms()):
		vdata = geom_node.getGeom(geom_index).getVertexData()
		reader = GeomVertexReader(vdata, "vertex")
		for row in range(vdata.getNumRows()):
			reader.setRow(row)
			x, _y, z = reader.getData3()
			xs.append(x)
			zs.append(z)
	if not xs:
		print("no verts", node.getName())
		return
	print(
		node.getName(),
		"x", round(min(xs), 4), round(max(xs), 4),
		"z", round(min(zs), 4), round(max(zs), 4),
		"size", round(max(xs) - min(xs), 4), round(max(zs) - min(zs), 4),
	)


def main() -> int:
	loadPrcFileData("", "window-type none")
	loadPrcFileData("", "audio-library-name null")
	getModelPath().prependDirectory(export_dialog.ASSETS)
	gui = export_dialog.load("phase_3/models/gui/create_a_toon_gui.bam")
	trash = export_dialog.load("phase_3/models/gui/trashcan_gui.bam")
	for name, file_name in (
		("CrtAtoon_Btn1_UP", "CrtAtoon_Btn1_UP.png"),
		("CrtAtoon_Btn1_DOWN", "CrtAtoon_Btn1_DN.png"),
		("CrtAtoon_Btn1_RLLVR", "CrtAtoon_Btn1_Rllvr.png"),
		("CrtAtoon_Btn2_UP", "CrtAtoon_Btn2_UP.png"),
		("CrtAtoon_Btn2_DOWN", "CrtAtoon_Btn2_DN.png"),
		("CrtAtoon_Btn2_RLLVR", "CrtAtoon_Btn2_Rllvr.png"),
	):
		node = gui.find("**/" + name)
		if node.isEmpty():
			print("missing", name)
			continue
		bounds(node)
		export_dialog.crop_card(node, DEST / file_name)
	for name in ("TrashCan_CLSD", "TrashCan_OPEN", "TrashCan_RLVR"):
		node = trash.find("**/" + name)
		if node.isEmpty():
			print("missing", name)
			continue
		bounds(node)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
