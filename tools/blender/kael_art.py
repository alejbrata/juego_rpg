"""Original Kael 0.9 art. Metres, Z up, face -Y; no external assets.

Geometry and palette are intentionally separate from the preserved 0.8 rig.
The atlas is deterministic, editable as PNG, and packed into the .blend/GLB.
"""
import math
import bpy
from mathutils import Vector


def painted_materials(palette, out):
    size = 1024
    image = bpy.data.images.new("KaelPaintedAtlas", width=size, height=size, alpha=False)
    pixels = []
    colors = list(palette.items())
    for y in range(size):
        row, v = divmod(y, 256)
        v /= 255
        for x in range(size):
            col, u = divmod(x, 256)
            u /= 255
            index = row * 4 + col
            name, (hex_color, _, _) = colors[min(index, len(colors) - 1)]
            base = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
            grain = math.sin(x * 2.31 + y * 3.17) * math.sin(x * .73 - y * 1.33)
            # Broad painted light, darkened edges, low-amplitude surface grain.
            shade = .88 + .16 * v + .045 * math.sin(math.pi * u) + .012 * grain
            if name in ("Cloth", "BlueTrim"):
                shade += .012 * math.sin(x * math.pi / 2) * math.sin(y * math.pi / 2)
                edge = min(u, 1 - u)
                if .035 < edge < .047:
                    shade += .24 if int(v * 45) % 3 != 0 else -.08
                shade += .025 * math.cos(u * math.tau * 3)
            elif name in ("Leather", "DarkLeather"):
                shade += .025 * math.sin(u * 60 + math.sin(v * 25))
                if min(u, 1-u) < .025:
                    shade *= .75
                if .045 < min(u, 1-u) < .06 and int(v * 35) % 2 == 0:
                    shade += .28
            elif name.startswith("Hair"):
                shade += .09 * math.sin(u * 40 + v * 3) * math.sin(math.pi * v)
            elif name.startswith("Steel"):
                shade += .1 * abs(math.sin(u * math.pi)) + .02 * math.sin(y * 2)
            elif name == "Skin":
                shade = .94 + .06 * v + .012 * grain
            elif name in ("Pupil", "EyeWhite", "Iris", "Lip"):
                shade = .97 + .03 * v
            pixels.extend([min(1, max(0, c * shade)) for c in base] + [1])
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(out / "kael_atlas.png")
    image.file_format = "PNG"
    image.save()
    image.pack()
    image.filepath_raw = "//kael_atlas.png"
    materials = []
    for name, metal, roughness in [("KaelPaintedCloth", 0.0, .87), ("KaelBrushedMetal", .55, .47)]:
        material = bpy.data.materials.new(name)
        shader = material.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Metallic"].default_value = metal
        shader.inputs["Roughness"].default_value = roughness
        texture = material.node_tree.nodes.new("ShaderNodeTexImage")
        texture.image = image
        material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
        material.diffuse_color = (.2, .28, .4, 1)
        materials.append(material)
    return materials


def head(b):
    # Jaw, cheeks, eye sockets, forehead and skull are shared rings, not a sphere.
    rows = []
    profiles = [
        (1.535, .075, .105, .09), (1.57, .13, .155, .12),
        (1.63, .19, .195, .16), (1.70, .226, .21, .185),
        (1.77, .235, .22, .205), (1.84, .228, .208, .215),
        (1.91, .22, .205, .22), (1.98, .2, .18, .21),
        (2.035, .14, .12, .155), (2.06, .055, .045, .06)]
    segments = 24
    for z, width, front, back in profiles:
        row = []
        for i in range(segments):
            a = i * math.tau / segments
            x, s = math.cos(a) * width, math.sin(a)
            y = s * (front if s < 0 else back)
            if s < -.55:
                # Flatter facial plane, cheek fullness and eye-socket recess.
                y = -front * (.93 + .07 * (-s))
                if 1.81 < z < 1.87:
                    y += .012 * math.exp(-((abs(x) - .10) / .06) ** 2)
            row.append(b.vertex((x, y, z), {"head": 1}))
        rows.append(row)
    for j, (a, c) in enumerate(zip(rows, rows[1:])):
        for i in range(segments):
            k = (i + 1) % segments
            b.face((a[i], a[k], c[k], c[i]), "Skin", True,
                   [(i/segments, j/9), ((i+1)/segments, j/9), ((i+1)/segments, (j+1)/9), (i/segments, (j+1)/9)])
    b.face(tuple(reversed(rows[0])), "Skin")
    b.face(rows[-1], "Skin")
    b.parts += 1
    # Small ears with an inset warm plane.
    for sign in [-1, 1]:
        b.ellipsoid((sign * .234, .005, 1.768), (.037, .048, .069), "Skin", segments=12, rings=6)
        b.patch([(sign*.252, -.034, 1.801), (sign*.263, -.037, 1.757), (sign*.242, -.039, 1.733)], "Lip", "head", True)
        # Almond eye, shallow inset with upper lid; avoids pop-out eyeballs.
        cx = sign * .097
        eye = [(cx-sign*.060, -.214, 1.826), (cx-sign*.025, -.224, 1.848),
               (cx+sign*.030, -.221, 1.852), (cx+sign*.067, -.209, 1.832),
               (cx+sign*.029, -.219, 1.811), (cx-sign*.026, -.224, 1.812)]
        b.patch(eye, "EyeWhite", "head", True)
        b.ellipsoid((cx, -.227, 1.831), (.021, .0035, .024), "Iris", segments=14, rings=6)
        b.ellipsoid((cx, -.231, 1.832), (.010, .002, .019), "Pupil", segments=12, rings=5)
        b.ellipsoid((cx-.005, -.234, 1.841), (.005, .001, .006), "EyeWhite", segments=8, rings=4)
        b.ribbon(eye[0], eye[1], .007, "DarkLeather", "head")
        b.ribbon(eye[1], eye[2], .009, "DarkLeather", "head")
        b.ribbon(eye[2], eye[3], .007, "DarkLeather", "head")
        # Brows angle toward the bridge, a restrained determined expression.
        b.ribbon((sign*.038, -.221, 1.875), (sign*.102, -.221, 1.891), .017, "Hair", "head")
        b.ribbon((sign*.102, -.221, 1.891), (sign*.168, -.204, 1.881), .012, "Hair", "head")
    # Nose bridge, tip and nostril wings share geometry and skin color.
    nose = [(-.025,-.218,1.857), (.025,-.218,1.857), (-.028,-.24,1.785),
            (.028,-.24,1.785), (-.024,-.272,1.762), (.024,-.272,1.762),
            (0,-.282,1.78), (0,-.231,1.747)]
    ids = [b.vertex(v, {"head":1}) for v in nose]
    for face in [(0,1,6), (0,6,4,2), (1,3,5,6), (4,6,5,7), (2,4,7), (3,7,5)]:
        b.face([ids[i] for i in face], "Skin", True)
    b.parts += 1
    # Closed lips, lower lip and small shadow under the lower lip.
    b.ribbon((-.046,-.211,1.694), (0,-.218,1.690), .0055, "Lip", "head")
    b.ribbon((0,-.218,1.690), (.044,-.211,1.697), .0055, "Lip", "head")
    b.ribbon((-.025,-.213,1.679), (.026,-.213,1.679), .005, "Skin", "head")


def lock(b, path, widths, material="Hair"):
    # Swept pointed clump with a longitudinal ridge. Broad sheets, not cylinders.
    rows = []
    for centre, width in zip(path, widths):
        x, y, z = centre
        rows.append([b.vertex((x-width, y+.005, z), {"head":1}),
                     b.vertex((x, y-.024, z+.012), {"head":1}),
                     b.vertex((x+width, y+.005, z), {"head":1}),
                     b.vertex((x, y+.035, z-.025), {"head":1})])
    for j, (a,c) in enumerate(zip(rows, rows[1:])):
        for i in range(4):
            k = (i+1)%4
            b.face((a[i],a[k],c[k],c[i]), material, True,
                   [(i/4,j/(len(rows)-1)),((i+1)/4,j/(len(rows)-1)),((i+1)/4,(j+1)/(len(rows)-1)),(i/4,(j+1)/(len(rows)-1))])
    b.face(tuple(reversed(rows[0])),material)
    b.face(rows[-1],material)
    b.parts += 1


def hair(b):
    # Skull cap integrated beneath layered locks. Tapered crown and side sweep.
    b.ellipsoid((0,.04,1.988),(.237,.22,.115),"Hair",segments=24,rings=9)
    for i in range(7):
        x = -.205 + i * .061
        lock(b, [(x*.55,.055,2.069), (x-.035,-.07,2.105+.027*math.sin(i*2)),
                 (x+.012,-.178,2.015), (x+.075,-.216,1.903+.022*math.sin(i*1.7))],
             [.048,.065,.05,.0015], "HairLight" if i in [1,4] else "Hair")
    # Crown/back silhouette follows the skull and tapers toward the nape.
    for sign in [-1,1]:
        for i in range(3):
            y = .06 + i*.064
            lock(b, [(sign*.10,y,2.075), (sign*.205,y+.015,2.04),
                     (sign*.25,y,1.93), (sign*.237,y-.015,1.80+i*.025)],
                 [.055,.065,.048,.002])
        lock(b, [(sign*.19,-.02,2.03),(sign*.24,-.07,1.94),(sign*.232,-.06,1.795)], [.05,.047,.0015])


def build_body(builder):
    b = builder()
    # Tailored jacket with waist, ribcage and trapezius transitions.
    b.loft([((0,0,z),rx,ry,w) for z,rx,ry,w in [
        (.91,.263,.155,{"pelvis":1}), (1.03,.25,.16,{"pelvis":.6,"spine":.4}),
        (1.14,.285,.18,{"spine":1}), (1.29,.345,.20,{"spine":1}),
        (1.40,.36,.185,{"spine":1}), (1.475,.285,.155,{"spine":.7,"neck":.3}),
        (1.505,.13,.115,{"neck":1})]],"Cloth",20)
    # Separated coat panels with flared hems over trousers.
    for sign in [-1,1]:
        b.loft([((sign*.18,.012,.83),.155,.193,{"pelvis":1}),
                ((sign*.135,0,.95),.15,.177,{"pelvis":1}),
                ((sign*.13,0,1.015),.145,.17,{"pelvis":1})],"BlueTrim",12)
        b.ribbon((sign*.08,-.192,.855),(sign*.26,-.16,.90),.012,"Gold","pelvis")
    b.loft([((0,0,.984),.277,.187,{"pelvis":1}),((0,0,1.043),.264,.18,{"pelvis":1})],"DarkLeather",20)
    b.patch([(-.045,-.191,.99),(.045,-.191,.99),(.045,-.187,1.038),(-.045,-.187,1.038)],"Gold","pelvis")
    b.patch([(-.026,-.194,1.003),(.026,-.194,1.003),(.026,-.191,1.026),(-.026,-.191,1.026)],"DarkLeather","pelvis")
    # Curved armoured vest with raised bevel and a visible underlayer.
    b.loft([((0,-.015,z),rx,ry,{"spine":1}) for z,rx,ry in [
        (1.09,.245,.175),(1.16,.283,.19),(1.31,.346,.202),(1.40,.327,.185)]],"BlueTrim",20)
    for sign in [-1,1]:
        b.ribbon((sign*.03,-.217,1.12),(sign*.24,-.194,1.17),.012,"Gold","spine")
        b.ribbon((sign*.24,-.194,1.17),(sign*.294,-.155,1.37),.012,"Steel","spine")
        b.ribbon((sign*.294,-.155,1.37),(sign*.03,-.205,1.413),.014,"SteelEdge","spine")
    # Off-centre leather baldric sits in front of the plate and has a metal clasp.
    strap = [(-.28,-.172,1.45),(-.17,-.211,1.36),(-.02,-.228,1.25),(.10,-.211,1.15),(.20,-.194,1.055)]
    for start,end in zip(strap,strap[1:]):
        b.ribbon(start,end,.055,"Leather","spine")
    b.ribbon((-.12,-.236,1.324),(-.065,-.237,1.28),.069,"Gold","spine")
    b.ribbon((-.113,-.24,1.315),(-.073,-.24,1.285),.042,"DarkLeather","spine")
    b.loft([((0,0,1.48),.108,.09,{"neck":1}),((0,0,1.65),.095,.085,{"head":1})],"Skin",16)
    b.loft([((0,.005,1.475),.15,.124,{"neck":1}),((0,.005,1.55),.128,.105,{"neck":1})],"Cloth",18)
    b.loft([((0,.005,1.535),.132,.109,{"neck":1}),((0,.005,1.55),.128,.105,{"neck":1})],"Gold",18)
    for sign,suffix in [(-1,"L"),(1,"R")]:
        thigh,calf,foot="thigh."+suffix,"calf."+suffix,"foot."+suffix
        b.loft([((sign*x,y,z),rx,ry,w) for x,y,z,rx,ry,w in [
            (.17,.005,.94,.146,.143,{thigh:.8,"pelvis":.2}),(.18,.015,.82,.142,.138,{thigh:1}),
            (.195,.005,.68,.118,.12,{thigh:1}),(.20,-.015,.54,.102,.101,{thigh:.6,calf:.4}),
            (.20,-.01,.48,.102,.10,{thigh:.3,calf:.7}),(.20,.005,.38,.108,.105,{calf:1}),
            (.20,0,.22,.083,.085,{calf:1})]],"Cloth",14)
        # Shaped boot instep, sole and cuff instead of a round foot blob.
        b.loft([((sign*.2,-.085,.035),.123,.205,{foot:1}),((sign*.2,-.09,.077),.128,.213,{foot:1}),
                ((sign*.2,-.10,.14),.122,.199,{foot:1}),((sign*.2,-.025,.205),.096,.115,{foot:.6,calf:.4}),
                ((sign*.2,.005,.29),.099,.10,{calf:1}),((sign*.2,.005,.38),.115,.112,{calf:1})],"Leather",16)
        b.loft([((sign*.2,-.084,.028),.127,.208,{foot:1}),((sign*.2,-.085,.065),.13,.212,{foot:1})],"DarkLeather",16)
        b.loft([((sign*.2,.005,.355),.12,.116,{calf:1}),((sign*.2,.005,.39),.117,.114,{calf:1})],"DarkLeather",14)
        b.ribbon((sign*.29,-.08,.27),(sign*.11,-.08,.27),.025,"DarkLeather",calf)
        b.ellipsoid((sign*.2,-.107,.535),(.086,.023,.105),"Steel",thigh,12,6)
        upper,forearm,hand="upper_arm."+suffix,"forearm."+suffix,"hand."+suffix
        b.loft([((sign*x,y,z),rx,ry,w) for x,y,z,rx,ry,w in [
            (.30,0,1.435,.13,.132,{upper:.65,"spine":.35}),(.38,0,1.38,.14,.13,{upper:1}),
            (.46,-.01,1.29,.123,.118,{upper:1}),(.53,-.025,1.205,.096,.095,{upper:.8,forearm:.2}),
            (.555,-.035,1.145,.088,.089,{upper:.4,forearm:.6}),(.585,-.07,1.065,.094,.089,{forearm:1}),
            (.625,-.115,.95,.072,.07,{forearm:.8,hand:.2})]],"Cloth",14)
        # Fitted bracer and cuff, with articulation retained at the elbow.
        b.loft([((sign*.58,-.065,1.08),.10,.096,{forearm:1}),
                ((sign*.61,-.10,.995),.092,.09,{forearm:1}),
                ((sign*.635,-.135,.925),.082,.078,{forearm:.7,hand:.3})],"DarkLeather",14)
        b.loft([((sign*.59,-.075,1.065),.104,.098,{forearm:1}),((sign*.595,-.08,1.04),.101,.097,{forearm:1})],"Gold",14)
        # Tapered palm, knuckle line and thumb: still a simplified hand, no finger rig.
        b.loft([((sign*.63,-.12,.955),.071,.064,{hand:1}),((sign*.644,-.16,.90),.086,.066,{hand:1}),
                ((sign*.65,-.18,.845),.079,.064,{hand:1}),((sign*.65,-.18,.817),.056,.055,{hand:1})],"Leather",12)
        b.loft([((sign*.59,-.155,.915),.034,.035,{hand:1}),((sign*.568,-.197,.875),.036,.034,{hand:1}),
                ((sign*.595,-.22,.851),.021,.024,{hand:1})],"Leather",10)
        for finger in range(3):
            x=sign*(.60+finger*.033)
            b.ribbon((x,-.227,.867),(x,-.229,.838),.004,"DarkLeather",hand)
        # Low-profile overlapping pauldrons, deliberately asymmetric.
        b.ellipsoid((sign*.37,.015,1.435),(.188,.18,.119),"Steel" if sign<0 else "DarkLeather",upper,16,7)
        b.ellipsoid((sign*.395,-.006,1.476),(.16,.16,.062),"SteelEdge" if sign<0 else "Leather",upper,16,6)
        b.ribbon((sign*.32,-.163,1.47),(sign*.46,-.142,1.43),.012,"Gold",upper)
    # Utility pouch reads as a sewn bag with a flap, rather than an ellipsoid.
    b.loft([((-.31,.10,.83),.083,.075,{"pelvis":1}),((-.315,.10,.98),.10,.085,{"pelvis":1})],"Leather",10)
    b.patch([(-.405,.008,.98),(-.225,.008,.98),(-.24,.005,.90),(-.315,-.003,.88),(-.39,.005,.90)],"DarkLeather","pelvis")
    b.ellipsoid((-.315,-.006,.92),(.014,.004,.014),"Gold","pelvis",8,4)
    head(b)
    hair(b)
    return b


def build_sword(builder):
    b=builder()
    hand={"hand.R":1}
    b.loft([((.645,-.18,.775),.033,.033,hand),((.645,-.18,1.04),.035,.035,hand)],"DarkLeather",12)
    for z in [.80,.835,.87,.905,.94,.975,1.01]:
        b.loft([((.645,-.18,z),.037,.037,hand),((.645,-.18,z+.009),.037,.037,hand)],"Leather",10)
    b.ellipsoid((.645,-.18,.77),(.052,.044,.061),"Steel","hand.R",12,6)
    # Curved split guard and swept quillons, original restrained fantasy shape.
    b.loft([((.445,-.18,1.065),.014,.019,hand),((.50,-.18,1.035),.026,.028,hand),
            ((.645,-.18,1.07),.04,.033,hand),((.79,-.18,1.035),.026,.028,hand),
            ((.845,-.18,1.065),.014,.019,hand)],"Gold",8,False)
    b.ellipsoid((.645,-.212,1.075),(.034,.014,.043),"BlueTrim","hand.R",12,6)
    b.loft([((.645,-.18,1.08),.067,.025,hand),((.645,-.18,1.18),.079,.027,hand),
            ((.645,-.18,1.42),.070,.025,hand),((.645,-.18,1.78),.048,.018,hand),
            ((.645,-.18,1.96),.001,.001,hand)],"SteelEdge",4,False)
    # Dark narrow fuller highlights the blade ridge without a new material.
    b.ribbon((.645,-.208,1.20),(.645,-.201,1.73),.012,"Steel","hand.R")
    return b
