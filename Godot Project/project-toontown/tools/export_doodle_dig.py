"""Add the pet dig-in, dig, dig-out, disappear, and reappear clips.

The first doodle export stopped at the tricks the pet performs on the ground.
MoviePetSOS still plays intoDig, dig, disappear, and reappear around the hole.
"""
from direct.showbase.ShowBase import ShowBase

import export_doodle as doodle

EXTRA = {
    "toDig": doodle.ANIM["toDig"],
    "dig": doodle.ANIM["dig"],
    "fromDig": doodle.ANIM["fromDig"],
    "disappear": doodle.ANIM["disappear"],
    "reappear": doodle.ANIM["reappear"],
}

ShowBase()
doodle.append_clips(base, EXTRA)
print("done")
