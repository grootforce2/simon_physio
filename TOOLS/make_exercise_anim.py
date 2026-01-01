import math
from PIL import Image, ImageDraw
import imageio.v2 as imageio

W, H = 512, 512

# Skeleton edges (stick figure)
EDGES = [
    ("head", "neck"),
    ("neck", "shoulder_l"), ("neck", "shoulder_r"),
    ("shoulder_l", "elbow_l"), ("elbow_l", "wrist_l"),
    ("shoulder_r", "elbow_r"), ("elbow_r", "wrist_r"),
    ("neck", "hip"),
    ("hip", "knee_l"), ("knee_l", "ankle_l"),
    ("hip", "knee_r"), ("knee_r", "ankle_r"),
]

def lerp(a, b, t): 
    return a + (b - a) * t

def interp_pose(p0, p1, t):
    out = {}
    for k in p0:
        out[k] = (lerp(p0[k][0], p1[k][0], t), lerp(p0[k][1], p1[k][1], t))
    return out

def draw_pose(pose, path_png=None):
    img = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    d = ImageDraw.Draw(img)

    # Lines
    for a, b in EDGES:
        if a in pose and b in pose:
            d.line([pose[a], pose[b]], fill=(0,0,0,255), width=8)

    # Joints
    for k, (x, y) in pose.items():
        r = 8 if k != "head" else 18
        d.ellipse([x-r, y-r, x+r, y+r], outline=(0,0,0,255), width=6)

    if path_png:
        img.save(path_png)
    return img

# Example: Shoulder Pendulum (simple swing)
base = {
    "head": (256, 90), "neck": (256, 130),
    "shoulder_l": (210, 150), "elbow_l": (190, 220), "wrist_l": (175, 300),
    "shoulder_r": (300, 150), "elbow_r": (330, 230), "wrist_r": (350, 320),
    "hip": (256, 250),
    "knee_l": (235, 340), "ankle_l": (225, 430),
    "knee_r": (280, 340), "ankle_r": (290, 430),
}

def pendulum_pose(angle_deg):
    a = math.radians(angle_deg)
    # rotate left arm around shoulder_l
    sx, sy = base["shoulder_l"]
    ex, ey = base["elbow_l"]
    wx, wy = base["wrist_l"]

    def rot(px, py):
        dx, dy = px - sx, py - sy
        rx = dx*math.cos(a) - dy*math.sin(a)
        ry = dx*math.sin(a) + dy*math.cos(a)
        return (sx + rx, sy + ry)

    p = dict(base)
    p["elbow_l"] = rot(ex, ey)
    p["wrist_l"] = rot(wx, wy)
    return p

frames = []
angles = list(range(-25, 26, 5)) + list(range(25, -26, -5))
for ang in angles:
    img = draw_pose(pendulum_pose(ang))
    frames.append(img)

out_gif = "shoulder_pendulum.gif"
imageio.mimsave(out_gif, frames, duration=0.06)
print("Wrote", out_gif)
