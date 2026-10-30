"""Crop the BankGui cards and render the jellybean bank the dialog shows."""
from __future__ import annotations

import sys
from pathlib import Path

from panda3d.core import (
    Filename,
    FrameBufferProperties,
    GraphicsOutput,
    GraphicsPipe,
    NodePath,
    OrthographicLens,
    PNMImage,
    Texture,
    WindowProperties,
    getModelPath,
    loadPrcFileData,
)

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import export_dialog  # noqa: E402

DEST = TOOLS.parent / "assets" / "gui" / "bank"
ASSETS = export_dialog.ASSETS


def render_bank() -> None:
    from direct.showbase.ShowBase import ShowBase

    base = ShowBase(windowType="offscreen")
    model = base.loader.loadModel(Filename(ASSETS, "phase_5.5/models/estate/jellybeanBank.bam"))
    if model is None:
        raise RuntimeError("missing jellybean bank")
    model.reparentTo(base.render)
    model.setDepthWrite(True)
    model.setDepthTest(True)
    beans = model.find("**/jellybeans")
    if not beans.isEmpty():
        beans.setDepthWrite(False)
        beans.setDepthTest(False)
    # The dialog draws the model unlit, the way a GUI geom is.
    model.setLightOff(1)
    # Model X is -2.226..2.226 and Z is 0.009..8.449. The camera looks along +Y.
    width = 4.45126
    height = 8.440654
    center_z = 4.229163
    pixels_h = 768
    pixels_w = max(8, int(round(pixels_h * width / height)))
    lens = OrthographicLens()
    lens.setFilmSize(width, height)
    lens.setNearFar(0.1, 100.0)
    base.cam.node().setLens(lens)
    base.cam.setPos(0.0, -30.0, center_z)
    base.cam.setHpr(0.0, 0.0, 0.0)
    props = WindowProperties.size(pixels_w, pixels_h)
    fb = FrameBufferProperties()
    fb.setRgbaBits(8, 8, 8, 8)
    fb.setDepthBits(24)
    buffer = base.graphicsEngine.makeOutput(
        base.pipe, "bank", -100, fb, props, GraphicsPipe.BFRefuseWindow, base.win.getGsg(), base.win
    )
    if buffer is None:
        raise RuntimeError("bank buffer failed")
    buffer.setClearColorActive(True)
    buffer.setClearColor((0, 0, 0, 0))
    display = NodePath("bank-cam")
    display.reparentTo(base.render)
    camera = base.makeCamera(buffer, lens=lens)
    camera.reparentTo(display)
    camera.setPos(0.0, -30.0, center_z)
    camera.setHpr(0.0, 0.0, 0.0)
    texture = Texture()
    buffer.addRenderTexture(texture, GraphicsOutput.RTMCopyRam)
    base.graphicsEngine.renderFrame()
    base.graphicsEngine.renderFrame()
    image = PNMImage()
    if not texture.store(image):
        raise RuntimeError("bank store failed")
    DEST.mkdir(parents=True, exist_ok=True)
    path = DEST / "bank.png"
    if not image.write(Filename.from_os_specific(str(path))):
        raise RuntimeError("write failed " + str(path))
    print("bank", image.getXSize(), image.getYSize(), flush=True)


def main() -> int:
    loadPrcFileData("", "window-type offscreen")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(ASSETS)
    arrows = export_dialog.load("phase_3/models/gui/create_a_toon_gui.bam")
    DEST.mkdir(parents=True, exist_ok=True)
    for name, file_name in (
        ("CrtATn_R_Arrow_UP", "arrow_up.png"),
        ("CrtATn_R_Arrow_DN", "arrow_down.png"),
        ("CrtATn_R_Arrow_RLVR", "arrow_hover.png"),
    ):
        node = arrows.find("**/" + name)
        if node.isEmpty():
            raise RuntimeError("missing " + name)
        export_dialog.crop_card(node, DEST / file_name)
    render_bank()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
