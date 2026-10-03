"""Original clay reference diorama. Blender 4.3; no external assets.

Sculpted closed surfaces, connected grass caps, botanical clusters and stone.
Coordinates here: Blender Z up; the camera sees the negative-Y face.
The study is a visual sample, not a substitute for the game's terrain mask.
"""
import json
import math
import random
from pathlib import Path
import bpy
from mathutils import Vector, noise
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
random.seed(20261003)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def mat(name, color, rough=.86, metal=0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    node = result.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Roughness'].default_value = rough
    node.inputs['Metallic'].default_value = metal
    return result


earth = mat('Earth | hand worked ochre clay', (.42, .13, .033))
grass = mat('Grass | malachite clay', (.025, .17, .010))
leaf_mats = [mat('Leaf jade', (.015, .20, .074)), mat('Leaf sap', (.16, .34, .022)),
             mat('Leaf fern', (.057, .28, .03)), mat('Leaf lime', (.32, .44, .028))]
rock_mats = [mat('Stone grey', (.17, .17, .14)), mat('Stone umber', (.23, .17, .12)),
             mat('Stone warm grey', (.28, .25, .19))]
brick = mat('Brick | pale clay', (.54, .46, .32))
wood = mat('Wood warm', (.22, .072, .018))
wood_edge = mat('Wood edge', (.42, .17, .047))
steel = mat('Steel brushed', (.27, .29, .28), .52, .45)
cream = mat('Flower cream', (.90, .80, .41))
yellow = mat('Flower gold', (.96, .52, .021))
white = mat('Cloud ivory', (.86, .85, .74))
water = mat('Water turquoise clay', (.018, .27, .39), .42)
hill_mats = [mat('Hill far', (.14, .32, .27)), mat('Hill middle', (.13, .30, .079)),
             mat('Hill near', (.09, .25, .047))]
roof = mat('Roof rose', (.37, .12, .064))
window = mat('Window dark', (.055, .071, .067))
castle = mat('Castle warm stone', (.59, .48, .28))
nodes = []


def noise3(v, scale):
    return noise.noise_vector(Vector(v) * scale, noise_basis='PERLIN_ORIGINAL').x


def finish(obj, name, material, collection=True):
    obj.name = name
    if material:
        obj.data.materials.clear()
        obj.data.materials.append(material)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    if collection:
        nodes.append(obj)
    return obj


def ellipsoid(name, at, size, material, detail=24, deform=0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=detail, ring_count=max(12, detail//2), location=at)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if deform:
        for v in obj.data.vertices:
            v.co += v.normal * (noise3(v.co + obj.location, 5) * deform)
    return finish(obj, name, material)


def cube(name, at, size, material, bevel=.12):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = obj.modifiers.new('Hand softened corners', 'BEVEL')
    mod.width = bevel
    mod.segments = 4
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, name, material)


def join(objects, name):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
        if obj in nodes:
            nodes.remove(obj)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    nodes.append(obj)
    return obj


def sculpt(obj, voxel=.075, amount=.07, folds=True):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.remesh_voxel_size = voxel
    bpy.ops.object.voxel_remesh()
    mod = obj.modifiers.new('Unify thumb pressed volume', 'SMOOTH')
    mod.factor = 1.1
    mod.iterations = 4
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.update()
    for v in obj.data.vertices:
        p = v.co.copy()
        broad = noise3(p, 2.7)
        grain = noise3(p, 12)
        fold = math.sin(p.z*24 + p.x*11 + noise3(p, 4)*6)
        d = amount * (broad + .16*grain)
        if folds:
            d += amount * .28 * (abs(fold)**5 - .3) * max(0, -v.normal.y)
        v.co += v.normal * d
    for p in obj.data.polygons:
        p.use_smooth = True
    colors = obj.data.color_attributes.new(name='Clay tint', type='FLOAT_COLOR', domain='POINT')
    for i, v in enumerate(obj.data.vertices):
        n = noise3(v.co, 3.7)*.11 + noise3(v.co, 17)*.045
        shade = max(.55, min(1, .85+n))
        colors.data[i].color = (shade, shade*.985, shade*.96, 1)
    obj.data.color_attributes.active_color = colors
    obj.data.update()
    return obj


def grass_cap(x0, x1, z, y0=-.62, y1=1.25):
    group = [cube('cap base', ((x0+x1)/2, (y0+y1)/2, z+.035),
                  (x1-x0, y1-y0, .26), grass, .12)]
    x = x0+.15
    while x < x1:
        width = random.uniform(.32, .59)
        group.append(ellipsoid('pressed scallop', (x, y0+.025+random.uniform(-.06,.07), z-.03),
                               (width, random.uniform(.25,.39), random.uniform(.17,.27)), grass))
        x += width*1.30
    for _ in range(int((x1-x0)*5)):
        group.append(ellipsoid('thumb press', (random.uniform(x0+.1,x1-.1),
                               random.uniform(y0+.12,y1-.1), z+.15),
                               (random.uniform(.16,.39),random.uniform(.16,.38),random.uniform(.06,.12)), grass, 16))
    result = join(group, 'Living grass cap')
    sculpt(result, .065, .025, False)
    return result


def stone(at, size, material=None):
    obj = ellipsoid('Embedded hand shaped pebble', at, size, material or random.choice(rock_mats), 20)
    for v in obj.data.vertices:
        v.co += v.normal * noise3(v.co+Vector(at), 11) * min(size) * .23
    obj.rotation_euler = (random.uniform(-.4,.4), random.uniform(-.5,.5), random.uniform(-1,1))
    return obj


def leaf(at, length, width, lean, angle, material):
    # Tapered curved leaf, with a gently raised central fold.
    verts, faces = [], []
    rings, sides = 11, 10
    for j in range(rings+1):
        t = j/rings
        r = max(.015, math.sin(math.pi*t)**.45)
        cx = lean * t*t
        for k in range(sides):
            a = k*math.tau/sides
            x = cx + math.cos(a)*width*r
            y = math.sin(a)*width*.62*r - .045*math.sin(math.pi*t)
            verts.append((x*math.cos(angle)-y*math.sin(angle)+at[0],
                          x*math.sin(angle)+y*math.cos(angle)+at[1],at[2]+length*t))
    for j in range(rings):
        for k in range(sides):
            a = j*sides+k; b=j*sides+(k+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple(rings*sides+k for k in range(sides)))
    mesh=bpy.data.meshes.new('Sculpted leaf mesh');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new('Clay botanical leaf',mesh);bpy.context.collection.objects.link(obj)
    return finish(obj,obj.name,material)


def plant(x, y, z, scale=1):
    for i in range(random.randint(5,8)):
        angle=i*2.4+random.random()*.5
        leaf((x+math.cos(angle)*.08,y+math.sin(angle)*.08,z), random.uniform(.24,.58)*scale,
             random.uniform(.09,.17)*scale,random.uniform(.10,.32)*scale,angle,random.choice(leaf_mats))


def flowers(x, y, z, scale=1):
    for _ in range(3):
        at=(x+random.uniform(-.2,.2)*scale,y+random.uniform(-.16,.16)*scale,z+.09*scale)
        for petal in range(5):
            a=petal*math.tau/5
            ellipsoid('Small flower petal',(at[0]+math.cos(a)*.055*scale,at[1]+math.sin(a)*.055*scale,at[2]),
                      (.055*scale,.033*scale,.026*scale),cream,12)
        ellipsoid('Flower heart',(at[0],at[1],at[2]+.026*scale),(.027*scale,)*3,yellow,12)


def cylinder(name, at, radius, depth, material, radius_top=None):
    if radius_top is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=depth, location=at)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=radius, radius2=radius_top, depth=depth,location=at)
    return finish(bpy.context.object,name,material)


# Three sculpted masses: low ground, pierced pillar and right bank.
ground = cube('Ochre ground', (0,.25,-1.72),(14,2.5,3.49),earth,.28)
sculpt(ground,.085,.10)
pillar = cube('Clay pillar', (-1.40,.25,1.74),(2.15,2.5,3.7),earth,.24)
cutter=cube('Tool cut',(-1.4,-.72,.71),(2.8,2.12,1.5),None,.24)
bpy.context.view_layer.objects.active=pillar
mod=pillar.modifiers.new('Rounded worked tunnel','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
bpy.ops.object.modifier_apply(modifier=mod.name)
nodes.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
sculpt(pillar,.065,.065)
plug=cube('DigPlug',(-.59,-.11,.72),(.46,1.9,1.47),earth,.17)
sculpt(plug,.05,.04)
bpy.context.view_layer.objects.active=plug
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS')
bank=cube('Raised right bank',(4.5,.25,.48),(5.0,2.5,1.45),earth,.24)
sculpt(bank,.075,.09)
grass_cap(-7,-2.55,.03)
grass_cap(-.22,1.00,.03)
grass_cap(-2.40,-.40,3.57)
grass_cap(2.05,7,1.19)

# Hand-shaped step blocks. Their construction can be shown one by one in Godot.
for i in range(5):
    obj=cube('Step_%02d'%i,(.60+i*.31,-.57,.14+i*.25),(.61,.87,.35),brick,.09)
    sculpt(obj,.055,.02)
    obj.name='Step_%02d'%i

for x,y,z,size in [(-5.8,.27,.19,1.15),(-3.15,.52,.18,.75),(-2.07,.30,3.75,.67),
                   (-.79,.63,3.75,.80),(.13,.29,.20,.80),(3.33,.30,1.37,1.12),(5.9,.70,1.38,.83)]:
    plant(x,y,z,size)
    flowers(x+.30,y-.24,z,.85*size)

# Short, varied leaves at the back of the walking surface; the front path stays clear.
for x0,x1,z in [(-6.7,-2.8,.20),(2.3,6.8,1.36),(-2.2,-.6,3.75)]:
    for _ in range(int((x1-x0)*5)):
        x=random.uniform(x0,x1)
        leaf((x,random.uniform(.05,.8),z),random.uniform(.055,.21),random.uniform(.018,.035),
             random.uniform(.02,.075),random.uniform(0,6.28),random.choice(leaf_mats))

for _ in range(28):
    x=random.uniform(-6.8,6.8);z=random.uniform(-1.75,-.25)
    s=random.uniform(.07,.22)
    stone((x,-.99,z),(s, s*.48, s*.78))
for x,z in [(-2.04,2.63),(-.85,2.28),(-1.75,3.20),(4.6,.50),(6.2,.72),(3.63,.30)]:
    stone((x,-.99,z),(.12,.08,.105))
# Tool crumbs are individual objects; the preview animates this small detached group.
for i in range(12):
    s=random.uniform(.035,.075)
    obj=stone((random.uniform(-2.20,-.60),random.uniform(-.73,-.30),random.uniform(.02,.12)),(s,s*.7,s),earth)
    obj.name='Crumb_%02d'%i

# Larger stones ground the composition, with nearby plants at the front edge.
for x,y,z,s in [(-6.9,-.85,-.5,.43),(6.5,-.81,.06,.4),(-4.8,-.98,-1.4,.36),(4.0,-.98,-1.3,.4)]:
    stone((x,y,z),(s,s*.65,s*.85))

# A narrow rocky plate provides a material contrast without a second focal object.
plate=cube('Steel sample plate',(5.9,-1.023,.67),(.9,.10,.76),steel,.05)
for x in [5.56,6.24]:
    for z in [.41,.94]:
        ellipsoid('Steel rivet',(x,-1.094,z),(.045,.025,.045),steel,16)

# Small diorama landscape, lit by the same physical lights as the foreground.
hill_shapes=[]
for tier,(y,base,scale) in enumerate([(13,-1.3,5.5),(8,-1.4,4.0),(5,-1.7,2.5)]):
    for i in range(-2,3):
        x=i*6+math.sin(i*3+tier)*1.5
        ellipsoid('Distant rolling hill',(x,y,base),(scale*1.2,3.5,scale*.54),hill_mats[tier],48,.10)
        hill_shapes.append((x,y,base,scale*1.2,3.5,scale*.54))
ellipsoid('Lake',(0,5,-1.5),(13,4,.12),water,48)


def tree(x,y,z,size):
    z=max((cz+rz*math.sqrt(max(0,1-((x-cx)/rx)**2-((y-cy)/ry)**2))
           for cx,cy,cz,rx,ry,rz in hill_shapes
           if ((x-cx)/rx)**2+((y-cy)/ry)**2<1), default=z)-.15
    trunk=cylinder('Tree trunk',(x,y,z+size*.85),.14*size,1.7*size,wood)
    trunk.rotation_euler.y=random.uniform(-.12,.12)
    group=[]
    for i in range(9):
        a=i*2.4
        group.append(ellipsoid('Tree crown',(x+math.cos(a)*.46*size,y+math.sin(a)*.34*size,z+(1.62+i*.08)*size),
                               (.54*size,.50*size,.68*size),leaf_mats[2],20,.05*size))
    obj=join(group,'Organic tree crown');sculpt(obj,.14*size,.05*size,False)


for x,y,z,s in [(-7,7,.3,1.25),(6.8,7,.1,1.35),(-4.5,9,1,.80),(4.5,10,1,.85),
                (-8,12,1.4,.80),(8.7,11,1.5,.80),(0.8,12,1.4,.65)]:
    tree(x,y,z,s)

for i,(x,y,z) in enumerate([(-5,17,4.25),(4.7,18,4.3),(.1,19,4.4)]):
    for j in range(7):
        a=j*2.4
        ellipsoid('Cloud',(x+(j-3)*.32,y,z+math.sin(a)*.15),
                  (.53,.35,.28+random.random()*.15),white,24,.04)
    ellipsoid('Cloud rising crown',(x-.12,y,z+.38),(.47,.35,.56),white,24,.025)

# A distant tower with a roof, door, windows and irregular stone courses.
tx,ty,tz=1.4,13,1.2
tz=max((cz+rz*math.sqrt(max(0,1-((tx-cx)/rx)**2-((ty-cy)/ry)**2))
        for cx,cy,cz,rx,ry,rz in hill_shapes
        if ((tx-cx)/rx)**2+((ty-cy)/ry)**2<1), default=tz)-.12
cylinder('Castle tower',(tx,ty,tz+1.1),.56,2.2,castle)
cylinder('Castle roof',(tx,ty,tz+2.58),.80,.95,roof,.02)
ellipsoid('Roof finial',(tx,ty,tz+3.09),(.06,.06,.08),roof,16)
for z in [tz+.9,tz+1.75]:
    for x in [tx-.23,tx+.23]:
        ellipsoid('Tower window',(x,ty-.52,z),(.09,.05,.14),window,16)
ellipsoid('Tower door',(tx,ty-.55,tz+.30),(.15,.05,.32),wood,16)

# Join static meshes by material to keep draw calls down, keeping steps/crumbs separate.
groups={}
for obj in list(nodes):
    if obj.name.startswith(('Step_','Crumb_','DigPlug')):
        continue
    key=obj.data.materials[0].name
    groups.setdefault(key,[]).append(obj)
for name,objects in groups.items():
    join(objects,'Diorama '+name)

# Compensate the orthographic camera tilt in the distant scenery.
# This keeps the tower and clouds inside the reference frame.
for obj in nodes:
    inv=obj.matrix_world.inverted()
    for v in obj.data.vertices:
        p=obj.matrix_world@v.co
        p.z-=max(0,p.y-2)*((3.3-1.15)/22)
        v.co=inv@p
    obj.data.update()

# Bake short-range ambient occlusion into the sculpted surface vertex colors.
# Ray tests use the actual diorama geometry, so creases and the tunnel retain depth.
vertices,polygons=[],[]
for obj in nodes:
    if obj.type!='MESH': continue
    offset=len(vertices)
    vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
    polygons.extend(tuple(offset+i for i in poly.vertices) for poly in obj.data.polygons)
bvh=BVHTree.FromPolygons(vertices,polygons)
for obj in nodes:
    colors=obj.data.color_attributes.get('Clay tint')
    if colors is None: continue
    for i,v in enumerate(obj.data.vertices):
        p=obj.matrix_world@v.co
        n=(obj.matrix_world.to_3x3()@v.normal).normalized()
        tangent=n.cross(Vector((0,0,1)) if abs(n.z)<.95 else Vector((1,0,0))).normalized()
        bitangent=n.cross(tangent)
        blocked=0.0
        for sample in range(12):
            z=(sample+.5)/12
            a=sample*2.399963
            r=math.sqrt(1-z*z)
            direction=n*z+tangent*(math.cos(a)*r)+bitangent*(math.sin(a)*r)
            hit=bvh.ray_cast(p+n*.025,direction,1.1)
            if hit[0] is not None:
                blocked+=max(0,1-hit[3]/1.1)
        ao=1-.78*math.sqrt(blocked/12)
        color=colors.data[i].color
        colors.data[i].color=(color[0]*ao,color[1]*ao,color[2]*ao,1)

ROOT.joinpath('models').mkdir(exist_ok=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in nodes:
    obj.select_set(True)
bpy.context.view_layer.objects.active=nodes[0]
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source/clay_reference.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'models/clay_reference.glb'),export_format='GLB',
    use_selection=True,export_yup=True,export_apply=True,export_animations=False,
    export_attributes=False,export_materials='EXPORT')
triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in nodes)
report={'seed':20261003,'mesh_objects':len(nodes),'triangles':triangles,
        'generator':'Blender 4.3.2','scope':'authored static reference terrain; steps and crumbs remain separate',
        'coordinates':'metres; Godot +Y up, +Z towards viewer'}
ROOT.joinpath('stage_manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('REFERENCE_STAGE',json.dumps(report))
