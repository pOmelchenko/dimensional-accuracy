#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Independent contact-ray checks for accepted XY-S r1 (not physical validation)."""
import itertools
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from tools.verify_stl import read_binary_stl

triangles = read_binary_stl(Path(sys.argv[1]) if len(sys.argv) > 1 else root / "dimensional_accuracy_gauge.stl")
def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def hit(origin,direction,triangle):
    a,b,c=triangle
    e1,e2=sub(b,a),sub(c,a)
    p=cross(direction,e2)
    det=dot(e1,p)
    if abs(det)<1e-9: return None
    tv=sub(origin,a)
    u=dot(tv,p)/det
    q=cross(tv,e1)
    v=dot(direction,q)/det
    t=dot(e2,q)/det
    if u>=-1e-8 and v>=-1e-8 and u+v<=1+1e-8 and t>=-1e-8: return t
    return None

def first(origin,direction):
    hits=[t for tri in triangles if (t:=hit(origin,direction,tri)) is not None]
    assert hits, (origin,direction,"missing contact")
    return min(hits)

def near(actual,expected,name):
    assert abs(actual-expected)<0.001, (name,actual,expected)

report=[]
poses=[
    ("X long",(100,16,2.25),(-1,0,0),100),
    ("X short",(-45,-1,2.25),(1,0,0),30),
    ("Y long",(1,-100,2.25),(0,1,0),100),
    ("Y short",(-16,45,2.25),(0,-1,0),30),
    ("X outer step",(100,-1,2.25),(-1,0,0),30),
    ("X middle step",(70,-11,2.25),(-1,0,0),30),
    ("Y outer step",(-16,-100,2.25),(0,1,0),30),
    ("Y middle step",(-26,-70,2.25),(0,1,0),30),
]
for name,origin,direction,expected in poses:
    values=[]
    lateral_axis=1 if direction[0] else 0
    for lateral,vertical in itertools.product((-0.5,-0.25,0,0.25,0.5),repeat=2):
        p=list(origin)
        p[lateral_axis]+=lateral
        p[2]+=vertical
        value=first(p,direction)
        near(value,expected,name)
        values.append(value)
    report.append(f"PASS {name}: 25 rod-tip rays, {min(values):.6f}..{max(values):.6f} mm, nominal {expected}.")

# Opposing external contacts: independent nominal dimensions from the sketch.
for axis in (0,1):
    for pos,width in ((25,35),(55,25),(85,15)):
        if axis==0:
            a,b,d=(pos,-30,2.25),(pos,20,2.25),(0,1,0)
            span=50
        else:
            a,b,d=(-40,-pos,2.25),(5,-pos,2.25),(1,0,0)
            span=45
        measured=span-first(a,d)-first(b,tuple(-v for v in d))
        near(measured,width,"outside width")
        report.append(f"PASS {'YX'[axis]} external width at {pos}: {measured:.6f} mm.")

for name,a,b,d in (
    ("X first section",(5,-15,2.25),(45,-15,2.25),(1,0,0)),
    ("Y first section",(-30,-45,2.25),(-30,-5,2.25),(0,1,0)),
):
    measured=40-first(a,d)-first(b,tuple(-v for v in d))
    near(measured,30,name)
    report.append(f"PASS {name}, opposing outside contacts: {measured:.6f} mm.")

# Internal contacts start inside the void, away from the corner reliefs.
for x in (20,40,60):
    p=(x,2.5,2.25)
    near(first(p,(0,1,0))+first(p,(0,-1,0)),10,"X window width")
for y in (0,2.5,5):
    p=(40,y,2.25)
    near(first(p,(1,0,0))+first(p,(-1,0,0)),45,"X window length")
for y in (-20,-40,-60):
    p=(-12.5,y,2.25)
    near(first(p,(1,0,0))+first(p,(-1,0,0)),10,"Y window width")
for x in (-15,-12.5,-10):
    p=(x,-40,2.25)
    near(first(p,(0,1,0))+first(p,(0,-1,0)),45,"Y window length")
report.append("PASS both internal windows: 45 x 10 mm at three positions per dimension.")

# The additional combinations highlighted by the user: walls and composite spans.
for pos,left in ((25,-35),(55,-25)):
    outer_left=-40+first((-40,-pos,2.25),(1,0,0))
    inner_left=-12.5-first((-12.5,-pos,2.25),(-1,0,0))
    near(inner_left-outer_left,-17.5-left,"Y window outer wall")
    outer_bottom=-30+first((pos,-30,2.25),(0,1,0))
    inner_bottom=2.5-first((pos,2.5,2.25),(0,-1,0))
    near(inner_bottom-outer_bottom,-17.5-left,"X window outer wall")
outer_top=20-first((25,20,2.25),(0,-1,0))
inner_top=2.5+first((25,2.5,2.25),(0,1,0))
near(outer_top-inner_top,7.5,"X straight-edge wall")
# Directly obtain face coordinates for the narrow Y wall.
outer_right=5-first((5,-25,2.25),(-1,0,0))
inner_right=-12.5+first((-12.5,-25,2.25),(1,0,0))
near(outer_right-inner_right,7.5,"Y straight-edge wall")
near(95-first((-20,-1,2.25),(1,0,0))-first((75,-1,2.25),(-1,0,0)),85,
     "X composite outside span")
near(95-first((-20,-75,2.25),(0,1,0))-first((-20,20,2.25),(0,-1,0)),85,
     "Y composite outside span")
near(155-first((-50,7.5,2.25),(1,0,0))-first((105,7.5,2.25),(-1,0,0)),145,
     "X overall outside span")
near(155-first((-7.5,-105,2.25),(0,1,0))-first((-7.5,50,2.25),(0,-1,0)),145,
     "Y overall outside span")
report.append("PASS X/Y wall thicknesses 17.5/7.5 mm, composite spans 85 mm, overall spans 145 mm.")

near(25-first((-20,30,2.25),(1,0,0))-first((5,30,2.25),(-1,0,0)),15,
     "X crossing width")
near(25-first((-30,-5,2.25),(0,1,0))-first((-30,20,2.25),(0,-1,0)),15,
     "Y crossing width")
report.append("PASS both 15 mm crossing widths used by the closure check.")

# The new bevel must expand the cut at both surfaces while keeping its core.
for name,xy,direction in (
    ("step",(71,1),(0,1,0)),
    ("long crossing",(1,14),(0,-1,0)),
    ("short crossing",(-1,-1),(-1,0,0)),
    ("window corner",(17.5,7.5),(0,1,0)),
):
    for z in (0.1,0.3,2.25,4.2,4.4):
        expected=1+max(0,0.375-min(z,4.5-z))
        near(first((*xy,z),direction),expected,f"{name} chamfer at z={z}")
report.append("PASS top/bottom relief bevels: 0.375 mm at 45 degrees; nominal mid-height targets retained.")
report.append("Geometric contacts only; no printed accuracy or real instrument fit validation.")
text="\n".join(report)+"\n"
print(text,end="")
