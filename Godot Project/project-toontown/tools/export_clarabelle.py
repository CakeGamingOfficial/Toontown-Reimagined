"""Render Clarabelle's catalog listen loop into the green frame.

CatalogScreen puts her at (-0.56, 6.43, -3.81), heading 121.61, in front of a
camera with a 40 degree lens. The switchboard sits two feet behind her.
"""
from __future__ import annotations

import sys
import types
from pathlib import Path

from panda3d.core import (
    Filename,
    FrameBufferProperties,
    GraphicsOutput,
    GraphicsPipe,
    PerspectiveLens,
    PNMImage,
    Texture,
    WindowProperties,
    getModelPath,
    loadPrcFileData,
)

ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
DEST = Path(__file__).resolve().parents[1] / "assets" / "gui" / "catalog" / "clarabelle.png"
CELL = 128
COLS = 11
ROWS = 22


def main() -> int:
    sys.modules["panda3d.toontown"] = types.SimpleNamespace(
        DNAStorage=object, loadDNAFile=lambda *_a, **_k: None
    )
    loadPrcFileData("", "window-type offscreen")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    getModelPath().prependDirectory(ASSETS)
    from direct.actor.Actor import Actor
    from direct.showbase.ShowBase import ShowBase

    base = ShowBase(windowType="offscreen")
    actor = Actor(
        "phase_5.5/models/char/Clarabelle-zero.bam",
        {"listen": "phase_5.5/models/char/Clarabelle-listens.bam"},
    )
    board = base.loader.loadModel("phase_5.5/models/estate/switchboard.bam")
    if board is not None:
        board.reparentTo(actor)
        board.setPos(0, -2, 0)
    actor.reparentTo(base.render)
    actor.setPosHprScale(-0.56, 6.43, -3.81, 121.61, 0.0, 0.0, 1.0, 1.0, 1.0)
    control = actor.getAnimControl("listen")
    frames = control.getNumFrames()
    lens = PerspectiveLens()
    lens.setFov(40)
    lens.setNearFar(0.1, 100.0)
    fb = FrameBufferProperties()
    fb.setRgbaBits(8, 8, 8, 8)
    fb.setDepthBits(24)
    props = WindowProperties.size(CELL, CELL)
    buffer = base.graphicsEngine.makeOutput(
        base.pipe, "clarabelle", -100, fb, props, GraphicsPipe.BFRefuseWindow, base.win.getGsg(), base.win
    )
    if buffer is None:
        raise RuntimeError("clarabelle buffer failed")
    buffer.setClearColorActive(True)
    buffer.setClearColor((0.3, 0.3, 0.3, 1))
    camera = base.makeCamera(buffer, lens=lens)
    camera.reparentTo(base.render)
    camera.setPos(0, 0, 0)
    camera.setHpr(0, 0, 0)
    texture = Texture()
    buffer.addRenderTexture(texture, GraphicsOutput.RTMCopyRam)
    sheet = PNMImage(COLS * CELL, ROWS * CELL, 4)
    sheet.fill(0, 0, 0)
    sheet.alphaFill(0)
    one = PNMImage()
    for frame in range(frames):
        actor.pose("listen", frame)
        actor.find("**/+Character").node().forceUpdate()
        base.graphicsEngine.renderFrame()
        if not texture.store(one):
            raise RuntimeError("store failed")
        col = frame % COLS
        row = frame // COLS
        sheet.copySubImage(one, col * CELL, row * CELL, 0, 0, CELL, CELL)
        if frame % 40 == 0:
            print("frame", frame, flush=True)
    DEST.parent.mkdir(parents=True, exist_ok=True)
    if not sheet.write(Filename.from_os_specific(str(DEST))):
        raise RuntimeError("write failed")
    print("wrote", frames, DEST.name, sheet.getXSize(), sheet.getYSize(), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
