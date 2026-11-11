"""Admit a narrowly scoped successor to an already measured human model.

Pure file inspection only. No Blender, Godot, subprocess or source mutation is
performed by the API. The optional CLI writes the shared packaging admission.
"""
from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import struct

GAME = "outputs/AshenOathTheRoadBetweenCrowns"
KIND = "lower_face_repair_v1"
DEFAULT_ADMISSION = "art_source/art_recovery_v2/evidence/lower_face_repair_20261111/admission.json"


def _require(condition, message):
    if not condition:
        raise ValueError("Face repair provenance: " + message)


def _digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _path(repository, value):
    _require(isinstance(value, str) and value, "missing artifact path")
    normalized = value.replace("\\", "/")
    if normalized.startswith("res://"):
        normalized = GAME + "/" + normalized[6:]
    _require(not normalized.startswith("/") and not re.match(r"^[A-Za-z]:", normalized), "absolute artifact path")
    parts = PurePosixPath(normalized).parts
    _require(".." not in parts and "." not in parts and normalized == "/".join(parts), "noncanonical artifact path")
    root = Path(repository).resolve()
    result = root.joinpath(*parts).resolve()
    _require(result.is_relative_to(root), "artifact escapes repository")
    return result


def _artifact(repository, row, label):
    _require(isinstance(row, dict), label + " identity missing")
    path = _path(repository, row.get("path"))
    _require(path.is_file(), label + " file missing: " + str(path))
    sha = row.get("sha256")
    _require(isinstance(sha, str) and re.fullmatch(r"[0-9a-f]{64}", sha) is not None, label + " digest malformed")
    _require(_digest(path) == sha, label + " bytes differ")
    if "bytes" in row:
        _require(type(row["bytes"]) is int and row["bytes"] == path.stat().st_size, label + " size differs")
    return path


class Document:
    def __init__(self, path):
        self.path = Path(path)
        self.raw = self.path.read_bytes()
        self.binary_offset = None
        if self.raw[:4] == b"glTF":
            _require(len(self.raw) >= 28, "short GLB")
            magic, version, length = struct.unpack_from("<4sII", self.raw)
            count, kind = struct.unpack_from("<II", self.raw, 12)
            _require(version == 2 and length == len(self.raw) and kind == 0x4E4F534A, "invalid GLB header")
            at = 20 + count
            _require(at + 8 <= len(self.raw), "GLB binary chunk missing")
            binary_count, binary_kind = struct.unpack_from("<II", self.raw, at)
            _require(binary_kind == 0x004E4942 and at + 8 + binary_count == len(self.raw), "nonstandard GLB chunks")
            self.json_bytes = self.raw[20:at]
            self.json = json.loads(self.json_bytes)
            self.binary_offset = at + 8
            self.buffers = [self.raw[self.binary_offset:]]
            _require(len(self.json.get("buffers", [])) == 1 and "uri" not in self.json["buffers"][0], "external GLB buffer")
        else:
            self.json_bytes = self.raw
            self.json = json.loads(self.raw)
            self.buffers = []
            for row in self.json.get("buffers", []):
                uri = row.get("uri", "")
                _require(isinstance(uri, str) and uri and not uri.startswith(("data:", "http:", "https:")), "donor buffer must be a local file")
                destination = (self.path.parent / uri.replace("\\", "/")).resolve()
                _require(destination.is_relative_to(self.path.parent.resolve()), "donor buffer escapes its folder")
                self.buffers.append(destination.read_bytes())

    def accessor(self, index, expected=None):
        _require(type(index) is int and 0 <= index < len(self.json.get("accessors", [])), "invalid accessor")
        a = self.json["accessors"][index]
        _require("sparse" not in a and "bufferView" in a, "sparse or missing accessor storage")
        if expected:
            _require((a.get("componentType"), a.get("type")) == expected and not a.get("normalized", False), "wrong accessor type")
        view = self.json["bufferViews"][a["bufferView"]]
        fmt = {5120:"b", 5121:"B", 5122:"h", 5123:"H", 5125:"I", 5126:"f"}.get(a.get("componentType"))
        width = {"SCALAR":1, "VEC2":2, "VEC3":3, "VEC4":4, "MAT4":16}.get(a.get("type"))
        _require(fmt is not None and width is not None and type(a.get("count")) is int and a["count"] >= 0, "unsupported accessor")
        size = struct.calcsize("<" + fmt * width)
        stride = view.get("byteStride", size)
        start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
        _require(type(stride) is int and stride >= size and stride % struct.calcsize("<" + fmt) == 0, "invalid accessor stride")
        blob = self.buffers[view.get("buffer", 0)]
        end = start + (a["count"] - 1) * stride + size if a["count"] else start
        _require(start >= view.get("byteOffset", 0) and end <= view.get("byteOffset", 0) + view["byteLength"] and end <= len(blob), "accessor exceeds storage")
        values = [struct.unpack_from("<" + fmt * width, blob, start + i * stride) for i in range(a["count"])]
        if fmt == "f":
            _require(all(math.isfinite(v) for row in values for v in row), "nonfinite accessor")
        return values

    def cells(self, index, vertices):
        self.accessor(index, (5126, "VEC3"))
        a = self.json["accessors"][index]
        view = self.json["bufferViews"][a["bufferView"]]
        _require(view.get("buffer", 0) == 0 and self.binary_offset is not None, "edited cell is not in owned GLB binary")
        start = self.binary_offset + view.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = view.get("byteStride", 12)
        for vertex in vertices:
            _require(type(vertex) is int and 0 <= vertex < a["count"], "edited vertex out of bounds")
            yield start + vertex * stride

    def ranges(self,index):
        self.accessor(index)
        a = self.json["accessors"][index]
        view = self.json["bufferViews"][a["bufferView"]]
        width = {"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4,"MAT4":16}[a["type"]]
        size = {5120:1,5121:1,5122:2,5123:2,5125:4,5126:4}[a["componentType"]]*width
        start = self.binary_offset+view.get("byteOffset",0)+a.get("byteOffset",0)
        for i in range(a["count"]):
            yield start+i*view.get("byteStride",size),size


def _literal(node):
    if isinstance(node, ast.Constant): return node.value
    if isinstance(node, (ast.List, ast.Tuple)): return [_literal(x) for x in node.elts]
    if isinstance(node, ast.Dict): return {_literal(k):_literal(v) for k,v in zip(node.keys, node.values)}
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub): return -_literal(node.operand)
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "dict" and not node.args:
        return {k.arg:_literal(k.value) for k in node.keywords if k.arg is not None}
    raise ValueError("Face repair provenance: design source is not literal data")


def _design(repository, asset, identity):
    path = _artifact(repository, identity, "legacy design source")
    for statement in ast.parse(path.read_text(encoding="utf-8")).body:
        if isinstance(statement, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "DESIGNS" for t in statement.targets):
            designs = _literal(statement.value)
            _require(asset in designs, "legacy design missing actor")
            return designs[asset]
    raise ValueError("Face repair provenance: legacy DESIGNS assignment missing")


def _inverse(matrix):
    rows = [[float(matrix[c*4+r]) for c in range(4)] + [float(r == c) for c in range(4)] for r in range(4)]
    for col in range(4):
        pivot = max(range(col, 4), key=lambda r:abs(rows[r][col]))
        _require(abs(rows[pivot][col]) > 1e-12, "singular donor bind")
        rows[col], rows[pivot] = rows[pivot], rows[col]
        divisor = rows[col][col]
        rows[col] = [v/divisor for v in rows[col]]
        for r in range(4):
            if r != col:
                amount = rows[r][col]
                rows[r] = [a-amount*b for a,b in zip(rows[r], rows[col])]
    return [row[4:] for row in rows]


def legacy_clamp_delta(point, head_base, neck_base, design):
    """Return exact historical pre/post clamp points, in glTF Y-up axes."""
    x, y, z = point[0], -point[2], point[1]
    reference_z = z - (head_base - 1.5496)
    jaw, nose, length = design["face"]
    front = max(0.0, min(1.0, (.025-y)/.07))
    lower = math.exp(-((reference_z-1.603)/.045)**2)
    middle = math.exp(-(x/.021)**2-((reference_z-1.647)/.038)**2)
    edited_x = x * (1+(jaw-1)*lower)
    edited_y = y - (nose-1)*.025*middle*front
    edited_z = z + (length-1)*(reference_z-1.69)*lower
    edited_y += .0025*design["age"]*math.exp(-((abs(x)-.046)/.024)**2-((reference_z-1.624)/.029)**2)*front
    if reference_z < 1.51:
        edited_z -= .020*max(0.0,min(1.0,(1.53-reference_z)/.045))
    before = (edited_x, edited_z, -edited_y)
    radius = math.hypot(edited_x/.047, (edited_y-.025)/.049)
    if neck_base-.08 < edited_z < head_base+.025 and abs(edited_x) < .20 and radius > 1.0:
        after = (edited_x/radius, edited_z, -(.025+(edited_y-.025)/radius))
    else:
        after = before
    return before, after


def _close(a, b, tolerance=2e-6):
    return len(a) == len(b) and all(math.isfinite(float(x)) and math.isfinite(float(y)) and abs(float(x)-float(y)) <= tolerance for x,y in zip(a,b))


def _lower_face_rows(repository, certificate, old, new, rows):
    donor_identity = certificate.get("donor")
    donor_path = _artifact(repository, donor_identity, "retained donor")
    design = _design(repository, certificate["asset"], certificate.get("design_source"))
    _require(design == certificate.get("legacy_design"), "recorded legacy design differs")
    _artifact(repository,certificate.get("repair_tool"),"archived repair recipe")
    expected_file = "Anwen_A_Set_Atlas.gltf" if design["gender"] == "female" else "Kael_A_Set_Atlas.gltf"
    # Archived copies preserve the exact donor bytes even when Git's newline
    # conversion changes the formatting of the original licensed JSON file.
    canonical_donor = _path(repository, "res://assets_external/characters_universal/runtime/" + expected_file)
    archived_donor = _path(repository, "art_source/art_recovery_v2/models/lower_face_repair_20261111/donors/"
                           + Path(expected_file).stem + "/" + expected_file)
    _require(donor_path in (canonical_donor, archived_donor), "unexpected retained donor")
    donor = Document(donor_path)
    linked = donor_identity.get("dependencies")
    _require(isinstance(linked,list), "donor dependency identities missing")
    actual_dependencies = {_artifact(repository,item,"retained donor dependency") for item in linked}
    expected_dependencies = {donor_path} | {(donor_path.parent/item["uri"]).resolve() for item in donor.json["buffers"]}
    _require(actual_dependencies == expected_dependencies and len(linked) == len(expected_dependencies), "donor dependency closure differs")
    _require(donor_identity.get("mesh") == 0 and donor_identity.get("primitive") == 0 and donor_identity.get("uv_tolerance") == 1e-6, "donor scope differs")
    source_primitive = donor.json["meshes"][0]["primitives"][0]
    donor_positions = donor.accessor(source_primitive["attributes"]["POSITION"], (5126,"VEC3"))
    donor_uvs = donor.accessor(source_primitive["attributes"]["TEXCOORD_0"], (5126,"VEC2"))
    skin = donor.json["skins"][0]
    names = [donor.json["nodes"][n].get("name") for n in skin["joints"]]
    inverse = donor.accessor(skin["inverseBindMatrices"], (5126,"MAT4"))
    head = _inverse(inverse[names.index("Head")])[1][3]
    neck = _inverse(inverse[names.index("neck_01")])[1][3]
    _require(abs(donor_identity.get("head_base_y",math.inf)-head) < 2e-6 and abs(donor_identity.get("neck_base_y",math.inf)-neck) < 2e-6, "donor rig frame differs")
    for row in rows:
        primitive = old.json["meshes"][row["mesh"]]["primitives"][row["primitive"]]
        material = old.json["materials"][primitive["material"]].get("name", "").lower()
        _require("anatomy" in material, "lower face edits leave retained anatomy material")
        old_positions = old.accessor(primitive["attributes"]["POSITION"], (5126,"VEC3"))
        new_positions = new.accessor(primitive["attributes"]["POSITION"], (5126,"VEC3"))
        current_uvs = old.accessor(primitive["attributes"]["TEXCOORD_0"], (5126,"VEC2"))
        witnesses = row.get("donor_vertices")
        _require(isinstance(witnesses,list) and len(witnesses) == len(row["vertices"]), "lower face donor indices missing")
        records = row.get("donor_records")
        _require(isinstance(records,list) and len(records) == len(witnesses), "lower face donor records missing")
        for at,(vertex, donor_vertex) in enumerate(zip(row["vertices"], witnesses)):
            _require(type(donor_vertex) is int and 0 <= donor_vertex < len(donor_positions), "donor index out of bounds")
            uv = donor_uvs[donor_vertex]
            _require(.25 < uv[0] < 1 and 0 < uv[1] < .5, "donor lies outside original skin UV tile")
            _require(_close(current_uvs[vertex],uv,1e-6), "donor UV differs")
            point = donor_positions[donor_vertex]
            _require(head-.035 < point[1] < head+.025, "donor outside proven lower-face height mask")
            before, after = legacy_clamp_delta(point,head,neck,design)
            _require(before != after, "legacy clamp did not affect donor")
            possible = []
            for candidate, candidate_uv in enumerate(donor_uvs):
                if not _close(candidate_uv,current_uvs[vertex],1e-6): continue
                candidate_point = donor_positions[candidate]
                if abs(candidate_point[0]) > .24 or not head-.12 < candidate_point[1] < head+.12: continue
                candidate_before, _ = legacy_clamp_delta(candidate_point,head,neck,design)
                if old_positions[vertex][0]*candidate_point[0] < -.0001 or abs(old_positions[vertex][1]-candidate_before[1]) > .025: continue
                if not any(math.dist(candidate_point,p) < 1e-6 for p in possible): possible.append(candidate_point)
            _require(len(possible) == 1 and _close(possible[0],point,1e-6), "donor UV correspondence is ambiguous")
            expected = [p + a-b for p,a,b in zip(old_positions[vertex],before,after)]
            _require(_close(new_positions[vertex],expected), "lower face is not the retained inverse-clamp delta")
            witness = records[at]
            _require(witness.get("mesh") == 0 and witness.get("primitive") == 0 and witness.get("vertex") == donor_vertex, "donor record identity differs")
            for key,value in (("uv",uv),("position",point),("before",(before[0],-before[2],before[1])),("after",(after[0],-after[2],after[1]))):
                _require(_close(witness.get(key,[]),value), "lower face witness differs: " + key)
            radius = math.hypot(before[0]/.047,(-before[2]-.025)/.049)
            _require(abs(float(witness.get("radius",math.inf))-radius) < 2e-6, "clamp radius witness differs")


def _raw_scope(repository, certificate, old, new):
    _require(old.binary_offset == new.binary_offset and len(old.raw) == len(new.raw) and old.raw[:20] == new.raw[:20] and old.raw[old.binary_offset-8:old.binary_offset] == new.raw[new.binary_offset-8:new.binary_offset], "GLB header or binary layout changed")
    rows = certificate.get("allowed_edits")
    _require(isinstance(rows,list) and rows, "edit scope is empty")
    allowed = bytearray(len(old.raw))
    occupied = set()
    positions = {}
    normals = []
    lower_faces = []
    declarations = set()
    for row in rows:
        _require(isinstance(row,dict) and type(row.get("mesh")) is int and type(row.get("primitive")) is int, "malformed edit scope")
        mi, pi = row["mesh"],row["primitive"]
        _require(0 <= mi < len(old.json["meshes"]) and 0 <= pi < len(old.json["meshes"][mi]["primitives"]), "scope primitive out of bounds")
        primitive = old.json["meshes"][mi]["primitives"][pi]
        _require(primitive.get("mode",4) == 4, "edited primitive is not triangles")
        vertices = row.get("vertices")
        _require(isinstance(vertices,list) and vertices and len(set(vertices)) == len(vertices), "invalid or duplicate scope vertices")
        kind = row.get("kind")
        semantic = "NORMAL" if kind == "normal_ring" else "POSITION"
        _require(kind in ("lower_face","beard","normal_ring") and row.get("attributes") == [semantic], "scope semantic is broader than repair")
        _require(semantic in primitive["attributes"], "edited semantic missing")
        declarations.add((mi,pi,semantic))
        for vertex, start in zip(vertices, old.cells(primitive["attributes"][semantic],vertices)):
            key = (mi,pi,semantic,vertex)
            _require(key not in occupied, "overlapping edit declaration")
            occupied.add(key)
            allowed[start:start+12] = b"\1"*12
        new.accessor(primitive["attributes"][semantic], (5126,"VEC3"))
        if kind == "normal_ring": normals.append(row)
        else: positions.setdefault((mi,pi),set()).update(vertices)
        if kind == "lower_face": lower_faces.append(row)
        if kind == "beard":
            _beard_scope(old,new,row,certificate)
    _position_bounds_scope(certificate,old,new,declarations)
    # Accessors may alias the same bytes. An allowed POSITION cell never grants
    # permission to alter UVs, weights, joints, skin binds or another consumer.
    protected = set()
    referenced = set()
    for mi,mesh in enumerate(old.json["meshes"]):
        for pi,primitive in enumerate(mesh["primitives"]):
            for semantic,index in primitive["attributes"].items():
                referenced.add(index)
                if (mi,pi,semantic) not in declarations: protected.add(index)
            if "indices" in primitive: protected.add(primitive["indices"])
            for target in primitive.get("targets",[]): protected.update(target.values())
    for skin in old.json.get("skins",[]):
        if "inverseBindMatrices" in skin: protected.add(skin["inverseBindMatrices"])
    for animation in old.json.get("animations",[]):
        for sampler in animation.get("samplers",[]): protected.update((sampler["input"],sampler["output"]))
    protected.update(set(range(len(old.json.get("accessors",[]))))-referenced)
    for index in protected:
        for start,size in old.ranges(index):
            _require(not any(allowed[start:start+size]), "allowed repair cells alias a protected accessor")
    for image in old.json.get("images",[]):
        if "bufferView" in image:
            view = old.json["bufferViews"][image["bufferView"]]
            start = old.binary_offset+view.get("byteOffset",0)
            _require(not any(allowed[start:start+view["byteLength"]]), "allowed repair cells alias embedded material data")
    _require(lower_faces, "no lower-face repair declared")
    _lower_face_rows(repository,certificate,old,new,lower_faces)
    for row in normals:
        key = (row["mesh"],row["primitive"])
        primitive = old.json["meshes"][key[0]]["primitives"][key[1]]
        indices = [v[0] for v in old.accessor(primitive["indices"])] if "indices" in primitive else list(range(len(old.accessor(primitive["attributes"]["POSITION"]))))
        _require(len(indices)%3 == 0, "triangle index count invalid")
        changed = positions.get(key,set())
        ring = set()
        for at in range(0,len(indices),3):
            triangle = indices[at:at+3]
            if changed.intersection(triangle): ring.update(triangle)
        _require(set(row["vertices"]) <= ring, "normal edit is outside immediate affected triangle ring")
        values = new.accessor(primitive["attributes"]["NORMAL"], (5126,"VEC3"))
        vertices = new.accessor(primitive["attributes"]["POSITION"], (5126,"VEC3"))
        sums = {i:[0.0,0.0,0.0] for i in row["vertices"]}
        for at in range(0,len(indices),3):
            tri = indices[at:at+3]
            a,b,c = [vertices[i] for i in tri]
            normal = _cross(_subtract(b,a),_subtract(c,a))
            for i in tri:
                if i in sums: sums[i] = _add(sums[i],normal)
        _require(all(_close(values[i],_unit(sums[i]),4e-5) for i in sums), "normal differs from repaired immediate-ring geometry")
    changed_count = 0
    for relative,(a,b) in enumerate(zip(old.raw[old.binary_offset:],new.raw[new.binary_offset:])):
        index = old.binary_offset+relative
        if a != b:
            _require(allowed[index] != 0, "protected GLB byte changed at " + str(index))
            changed_count += 1
    _require(changed_count > 0, "repair changes no model bytes")


def _position_bounds_scope(certificate,old,new,declarations):
    """Only tight outward POSITION bounds may differ in fixed-length JSON."""
    identity = certificate.get("position_bounds")
    _require(isinstance(identity,dict),"POSITION bounds identity missing")
    _require(identity.get("old_binary_start") == old.binary_offset and identity.get("new_binary_start") == new.binary_offset and identity.get("binary_layout_preserving") is True and identity.get("json_chunk_length_preserved") is True,"POSITION bound update changes binary layout")
    _require(identity.get("old_json_sha256") == hashlib.sha256(old.json_bytes).hexdigest() and identity.get("new_json_sha256") == hashlib.sha256(new.json_bytes).hexdigest(),"POSITION bounds JSON identity differs")
    _require(certificate.get("json_semantics_preserved_except_position_bounds") is True,"POSITION-only JSON policy missing")
    allowed_accessors = {old.json["meshes"][mi]["primitives"][pi]["attributes"][semantic] for mi,pi,semantic in declarations if semantic == "POSITION"}
    _require(len(old.json.get("accessors",[])) == len(new.json.get("accessors",[])),"accessor inventory changed")
    restored = copy.deepcopy(new.json)
    actual_changes = {}
    for index in allowed_accessors:
        before,after = old.json["accessors"][index],new.json["accessors"][index]
        _require(all(isinstance(before.get(field),list) and len(before[field]) == 3 and isinstance(after.get(field),list) and len(after[field]) == 3 for field in ("min","max")),"POSITION bounds fields missing or malformed")
        points = new.accessor(index,(5126,"VEC3"))
        _require(points,"repaired POSITION accessor is empty")
        extrema = {"min":[min(point[axis] for point in points) for axis in range(3)],"max":[max(point[axis] for point in points) for axis in range(3)]}
        for field in ("min","max"):
            for bound,value in zip(after[field],extrema[field]):
                _require(type(bound) in (int,float) and math.isfinite(bound),"POSITION bound is not finite numeric data")
                _require(struct.pack("<f",bound) == struct.pack("<f",value),"POSITION bound is not its repaired float32 extreme")
                _require(bound <= value if field == "min" else bound >= value,"POSITION bound rounds inward")
            restored["accessors"][index][field] = copy.deepcopy(before[field])
        if any(before[field] != after[field] for field in ("min","max")):
            actual_changes[index] = ({field:before[field] for field in ("min","max")},{field:after[field] for field in ("min","max")},extrema)
    _require(restored == old.json,"JSON changed outside declared POSITION accessor min/max")
    rows = identity.get("json_bounds_edits")
    _require(isinstance(rows,list) and len(rows) == len(actual_changes),"POSITION bound witness inventory differs")
    seen = set()
    for row in rows:
        index = row.get("accessor")
        _require(type(index) is int and index in actual_changes and index not in seen,"POSITION bound witness accessor invalid or duplicated")
        seen.add(index)
        before,after,extrema = actual_changes[index]
        _require(row.get("before") == before and row.get("after") == after,"POSITION bound witness values differ")
        if "actual_float32_extrema" in row:
            _require(row["actual_float32_extrema"] == extrema,"POSITION bound float32 extrema witness differs")


def _add(a,b): return [x+y for x,y in zip(a,b)]
def _subtract(a,b): return [x-y for x,y in zip(a,b)]
def _scale(a,n): return [x*n for x in a]
def _dot(a,b): return math.fsum(x*y for x,y in zip(a,b))
def _cross(a,b): return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def _unit(a):
    length = math.sqrt(_dot(a,a))
    _require(length > 1e-12, "degenerate authored vector")
    return _scale(a,1/length)


def closest_triangle_point(point,a,b,c):
    """Ericson triangle regions, matching the archived producer's tuple math."""
    point,a,b,c = (tuple(float(value) for value in vector) for vector in (point,a,b,c))
    def difference(first,second): return tuple(x-y for x,y in zip(first,second))
    def dot(first,second): return math.fsum(x*y for x,y in zip(first,second))
    def result(weights):
        return tuple(math.fsum(weights[index]*vertex[axis] for index,vertex in enumerate((a,b,c))) for axis in range(3)),tuple(weights)
    ab,ac,ap = difference(b,a),difference(c,a),difference(point,a)
    d1,d2 = dot(ab,ap),dot(ac,ap)
    if d1 <= 0.0 and d2 <= 0.0: return result((1.0,0.0,0.0))
    bp = difference(point,b)
    d3,d4 = dot(ab,bp),dot(ac,bp)
    if d3 >= 0.0 and d4 <= d3: return result((0.0,1.0,0.0))
    vc = math.fsum((d1*d4,-d3*d2))
    if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0 and d1 != d3:
        v = d1/(d1-d3)
        return result((1.0-v,v,0.0))
    cp = difference(point,c)
    d5,d6 = dot(ab,cp),dot(ac,cp)
    if d6 >= 0.0 and d5 <= d6: return result((0.0,0.0,1.0))
    vb = math.fsum((d5*d2,-d1*d6))
    if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0 and d2 != d6:
        w = d2/(d2-d6)
        return result((1.0-w,0.0,w))
    va = math.fsum((d3*d6,-d5*d4))
    first,second = d4-d3,d5-d6
    if va <= 0.0 and first >= 0.0 and second >= 0.0 and first+second > 0.0:
        w = first/(first+second)
        return result((0.0,1.0-w,w))
    denominator = math.fsum((va,vb,vc))
    if denominator > 0.0:
        v,w = vb/denominator,vc/denominator
        return result((va/denominator,v,w))
    candidates = []
    for start,end,initial,final in ((a,b,(1,0,0),(0,1,0)),(a,c,(1,0,0),(0,0,1)),(b,c,(0,1,0),(0,0,1))):
        edge = difference(end,start)
        length_squared = dot(edge,edge)
        t = max(0.0,min(1.0,dot(difference(point,start),edge)/length_squared)) if length_squared else 0.0
        candidates.append(result(tuple((1.0-t)*x+t*y for x,y in zip(initial,final))))
    return min(candidates,key=lambda candidate:math.dist(point,candidate[0]))


def _barycentric_point(barycentric,triangle):
    return [math.fsum(weight*vertex[axis] for weight,vertex in zip(barycentric,triangle)) for axis in range(3)]


def canonical_raw_bind_anchor(point,original,repaired,producer_anchor):
    """Derived source metadata; never a new rendered/runtime observation."""
    old_hit,barycentric = closest_triangle_point(point,*original)
    new_hit = _barycentric_point(barycentric,repaired)
    old_normal = _unit(_cross(_subtract(original[1],original[0]),_subtract(original[2],original[0])))
    new_normal = _unit(_cross(_subtract(repaired[1],repaired[0]),_subtract(repaired[2],repaired[0])))
    return {"frame":"raw_glb_bind", "evidence_kind":"derived_source_metadata", "runtime_observation":False,
            "triangle":producer_anchor["triangle"],"surface":copy.deepcopy(producer_anchor["surface"]),
            "projection_method":"float64_ericson_triangle_regions", "barycentric":list(barycentric),
            "old_surface_point":list(old_hit),"new_surface_point":list(new_hit),
            "old_surface_distance_m":math.dist(point,old_hit),
            "old_normal":list(old_normal),"new_normal":list(new_normal)}


def _beard_scope(old,new,row,certificate):
    primitive = old.json["meshes"][row["mesh"]]["primitives"][row["primitive"]]
    material = old.json["materials"][primitive["material"]].get("name","").lower()
    _require("authoredclothesatlas" in material, "beard edit is outside original generated hair atlas")
    skins = {n["skin"] for n in old.json["nodes"] if n.get("mesh") == row["mesh"] and "skin" in n}
    _require(len(skins) == 1, "beard mesh skin is ambiguous")
    skin = old.json["skins"][next(iter(skins))]
    names = [old.json["nodes"][n].get("name") for n in skin["joints"]]
    joints = old.accessor(primitive["attributes"]["JOINTS_0"])
    weights = old.accessor(primitive["attributes"]["WEIGHTS_0"])
    uv = old.accessor(primitive["attributes"]["TEXCOORD_0"],(5126,"VEC2"))
    before = old.accessor(primitive["attributes"]["POSITION"],(5126,"VEC3"))
    after = new.accessor(primitive["attributes"]["POSITION"],(5126,"VEC3"))
    head = _inverse(old.accessor(skin["inverseBindMatrices"],(5126,"MAT4"))[names.index("Head")])[1][3]
    old_triangles,new_triangles,surface_ids,boxes = [],[],[],[]
    for mesh_index,mesh in enumerate(old.json["meshes"]):
        for primitive_index,part in enumerate(mesh["primitives"]):
            name = old.json["materials"][part["material"]].get("name","").lower()
            if "anatom" not in name: continue
            source = old.accessor(part["attributes"]["POSITION"],(5126,"VEC3"))
            result = new.accessor(part["attributes"]["POSITION"],(5126,"VEC3"))
            indices = [v[0] for v in old.accessor(part["indices"])]
            for at in range(0,len(indices),3):
                tri = indices[at:at+3]
                if all(abs(source[i][0]) < .24 and source[i][1] > head-.10 for i in tri):
                    old_triangles.append([(source[i][0],-source[i][2],source[i][1]) for i in tri])
                    new_triangles.append([(result[i][0],-result[i][2],result[i][1]) for i in tri])
                    surface_ids.append({"mesh":mesh_index,"primitive":primitive_index,"triangle":at//3,"vertices":tri})
                    triangle = old_triangles[-1]
                    boxes.append(([min(v[axis] for v in triangle) for axis in range(3)],[max(v[axis] for v in triangle) for axis in range(3)]))
    anchors = row.get("beard_anchors")
    _require(isinstance(anchors,list) and len(anchors) == len(row["vertices"]),"beard same-triangle anchor witnesses missing")
    for vertex,wrapped in zip(row["vertices"],anchors):
        producer = wrapped.get("producer_neutral_bind_anchor")
        anchor = wrapped.get("raw_bind_anchor_proof")
        _require(isinstance(producer,dict) and producer.get("frame") == "producer_float32_neutral_bind" and isinstance(producer.get("anchor"),dict),"original producer neutral-bind anchor is not preserved")
        original_anchor = producer["anchor"]
        _require(isinstance(anchor,dict) and anchor.get("frame") == "raw_glb_bind" and anchor.get("evidence_kind") == "derived_source_metadata" and anchor.get("runtime_observation") is False,"raw-bind anchor proof is not labelled derived source metadata")
        _require(original_anchor.get("triangle") == anchor.get("triangle") and original_anchor.get("surface") == anchor.get("surface") and original_anchor.get("projection_method") == "float64_ericson_triangle_regions","canonical anchor changed original producer triangle")
        for field in ("old_normal","new_normal"):
            value = original_anchor.get(field)
            _require(isinstance(value,list) and len(value) == 3 and all(type(v) in (int,float) and math.isfinite(v) for v in value) and abs(math.sqrt(_dot(value,value))-1) < 2e-5,"preserved producer normal is not finite unit data")
        influence = {names[j]:w for j,w in zip(joints[vertex],weights[vertex]) if w > 1e-7}
        _require(set(influence) == {"Head","Face_Jaw"} and abs(influence["Head"]-.7) < 2e-5 and abs(influence["Face_Jaw"]-.3) < 2e-5, "beard weights do not identify generated beard")
        _require(.25 <= uv[vertex][0] <= .5 and 0 <= uv[vertex][1] <= .5, "beard lies outside original hair atlas tile")
        _require(abs(before[vertex][0]) <= .10 and head-.01 < before[vertex][1] < head+.12 and math.dist(before[vertex],after[vertex]) <= .12, "beard repair exceeds retained authored region")
        point = [before[vertex][0],-before[vertex][2],before[vertex][1]]
        triangle_index = anchor.get("triangle")
        _require(anchor.get("projection_method") == "float64_ericson_triangle_regions", "beard anchor uses another projection method")
        _require(type(triangle_index) is int and 0 <= triangle_index < len(old_triangles),"beard anchor triangle out of bounds")
        _require(anchor.get("surface") == surface_ids[triangle_index],"beard anchor changed original triangle identity")
        original,repaired = old_triangles[triangle_index],new_triangles[triangle_index]
        original_cross = _cross(_subtract(original[1],original[0]),_subtract(original[2],original[0]))
        repaired_cross = _cross(_subtract(repaired[1],repaired[0]),_subtract(repaired[2],repaired[0]))
        _require(_dot(original_cross,original_cross) >= 1e-16 and _dot(repaired_cross,repaired_cross) >= 1e-16,"degenerate beard anchor surface")
        old_hit,barycentric = closest_triangle_point(point,*original)
        _require(min(barycentric) >= 0.0 and max(barycentric) <= 1.0, "beard closest point lies outside original triangle")
        new_hit = _barycentric_point(barycentric,repaired)
        old_normal,new_normal = _unit(original_cross),_unit(repaired_cross)
        distance = math.dist(point,old_hit)
        _require(distance <= .018,"beard does not rest on original head within18mm")
        # Retain the producer's selected BVH triangle only if it is a nearest
        # original surface. Tiny ties at a shared edge remain valid choices.
        for other,box in zip(old_triangles,boxes):
            lower_bound = sum(max(box[0][axis]-point[axis],0.0,point[axis]-box[1][axis])**2 for axis in range(3))
            if lower_bound > (distance+2e-6)**2: continue
            cross = _cross(_subtract(other[1],other[0]),_subtract(other[2],other[0]))
            if _dot(cross,cross) < 1e-16: continue
            other_hit,_ = closest_triangle_point(point,*other)
            _require(math.dist(point,other_hit)+2e-6 >= distance,"beard anchor is not nearest original surface")
        for key,value in (("barycentric",barycentric),("old_surface_point",old_hit),("new_surface_point",new_hit),("old_normal",old_normal),("new_normal",new_normal)):
            _require(_close(anchor.get(key,[]),value,2e-5),"beard anchor witness differs: "+key)
        _require(abs(float(anchor.get("old_surface_distance_m",math.inf))-distance) <= 2e-6,"beard anchor distance differs")
        dot = _dot(old_normal,new_normal)
        _require(dot > -.9999,"beard refit reverses surface orientation")
        qv,qw = _cross(old_normal,new_normal),1+dot
        length = math.sqrt(_dot(qv,qv)+qw*qw)
        qv,qw = _scale(qv,1/length),qw/length
        offset = _subtract(point,old_hit)
        turn = _cross(qv,offset)
        rotated = _add(offset,_add(_scale(turn,2*qw),_scale(_cross(qv,turn),2)))
        expected = _add(new_hit,rotated)
        _require(_close(after[vertex],[expected[0],expected[2],-expected[1]],1e-4), "beard differs from the same original/repaired triangle normal-offset transfer")


def _preserved_producer_anchor_record(repository,certificate):
    rows = [row for row in certificate.get("allowed_edits",[]) if row.get("kind") == "beard"]
    if not rows: return
    identity = certificate.get("raw_bind_anchor_canonicalization")
    _require(isinstance(identity,dict) and identity.get("evidence_kind") == "derived_source_metadata" and identity.get("runtime_observation") is False and identity.get("producer_frame") == "producer_float32_neutral_bind" and identity.get("canonical_frame") == "raw_glb_bind","raw anchor metadata frame identity missing")
    _require(identity.get("helper_sha256") == _digest(Path(__file__)) and identity.get("baseline_model_sha256") == certificate["baseline_model"]["sha256"] and identity.get("model_sha256") == certificate["model"]["sha256"],"raw anchor metadata source identity differs")
    archive = _artifact(repository,identity.get("producer_certificate"),"original producer certificate")
    _require(str(identity["producer_certificate"]["path"]).replace("\\","/").startswith("art_source/") and archive.suffix == ".json","original producer certificate is not archived source evidence")
    restored = copy.deepcopy(certificate)
    restored.pop("raw_bind_anchor_canonicalization")
    count = 0
    for row in restored["allowed_edits"]:
        if row.get("kind") != "beard": continue
        originals = []
        for wrapped in row["beard_anchors"]:
            original = wrapped.get("producer_neutral_bind_anchor")
            _require(isinstance(original,dict) and original.get("frame") == "producer_float32_neutral_bind" and isinstance(original.get("anchor"),dict),"producer anchor fields were not preserved")
            originals.append(original["anchor"])
            count += 1
        row["beard_anchors"] = originals
    _require(identity.get("anchor_count") == count and restored == json.loads(archive.read_text(encoding="utf-8")),"derived anchor metadata changes original producer certificate fields")


def resolve_model_successor(repository, asset, old_model_sha, old_prepared_sha=None, prepared_path=None):
    """Return an admitted exact successor, or None only when no pointer exists.

Passing either prepared argument requires complete prepared admission. Authoring
may omit both, while packaging always requires the prepared stanza separately.
    """
    repository = Path(repository).resolve()
    registry = json.loads(_path(repository,"res://data/design_pack_assets.json").read_text(encoding="utf-8"))
    entry = registry.get("assets",{}).get(asset)
    _require(isinstance(entry,dict), "asset absent from authoritative registry")
    if "face_repair_certificate" not in entry: return None
    pointer = entry["face_repair_certificate"]
    cert_path = _artifact(repository,pointer,"repair certificate")
    cert = json.loads(cert_path.read_text(encoding="utf-8"))
    _require(cert.get("schema_version") == 1 and cert.get("certificate_kind") == KIND and cert.get("asset") == asset and cert.get("baseline_commit") == "b4b52e4", "certificate identity differs")
    model = cert.get("model",{})
    _require(model.get("path") == entry.get("path") and model.get("sha256") == entry.get("sha256") and model.get("baseline_sha256") == old_model_sha, "registry/model predecessor differs")
    model_path = _artifact(repository,model,"repaired runtime model")
    old_path = _artifact(repository,cert.get("baseline_model"),"immutable baseline model")
    _require(str(cert["baseline_model"]["path"]).replace("\\","/").startswith("art_source/") and old_path.suffix == ".glb", "baseline snapshot is not an archived GLB")
    _require(cert["baseline_model"]["sha256"] == old_model_sha, "baseline snapshot is not measured predecessor")
    new_path = _artifact(repository,cert.get("new_glb"),"authored GLB")
    _require(cert["new_glb"]["sha256"] == model["sha256"], "authored and runtime model differ")
    editable = _artifact(repository,cert.get("editable_source"),"editable Blender source")
    _require(editable.suffix == ".blend", "editable source is not a Blender master")
    life = cert.get("life_library",{})
    _require(life.get("path") == "res://assets_external/characters_prepared/animations/life_"+asset+".res", "life library identity differs")
    _artifact(repository,life,"retained life library")
    _preserved_producer_anchor_record(repository,cert)
    _raw_scope(repository,cert,Document(old_path),Document(new_path))
    prepared = cert.get("prepared")
    require_prepared = old_prepared_sha is not None or prepared_path is not None
    if require_prepared or (isinstance(prepared,dict) and "sha256" in prepared):
        _require(isinstance(prepared,dict), "prepared handoff missing")
        if prepared_path is not None: _require(prepared.get("path") == prepared_path, "prepared path differs")
        if old_prepared_sha is not None: _require(prepared.get("baseline_sha256") == old_prepared_sha, "prepared predecessor differs")
        _artifact(repository,prepared,"repaired prepared scene")
        _require(prepared.get("source_sha256") == model["sha256"], "prepared source identity differs")
        _require(prepared.get("compiler_sha256") == _digest(_path(repository,"res://tools/build_prepared_actors.gd")), "prepared compiler differs")
        catalog = json.loads(_path(repository,"res://data/prepared_actors.json").read_text(encoding="utf-8"))
        matching = [row for row in catalog.values() if row.get("source") == model["path"] or row.get("path") == prepared["path"]]
        _require(matching and all(row.get("source") == model["path"] and row.get("path") == prepared["path"] and row.get("source_sha256") == model["sha256"] and row.get("compiled_sha256") == prepared["sha256"] for row in matching), "prepared catalog ownership/source differs")
    elif prepared is not None:
        _require(isinstance(prepared,dict) and isinstance(prepared.get("baseline_sha256"),str) and re.fullmatch(r"[0-9a-f]{64}",prepared["baseline_sha256"]) is not None, "authoring prepared predecessor malformed")
    return {"asset":asset,"certificate_path":str(pointer["path"]),"certificate_sha256":pointer["sha256"],"model_path":model["path"],"baseline_model_sha256":old_model_sha,"model_sha256":model["sha256"],"prepared_path":prepared.get("path") if prepared else None,"baseline_prepared_sha256":prepared.get("baseline_sha256") if prepared else None,"prepared_sha256":prepared.get("sha256") if prepared else None,"prepared_source_sha256":prepared.get("source_sha256") if prepared else None,"life_library_path":life["path"],"life_library_sha256":life["sha256"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository",required=True,type=Path)
    parser.add_argument("--write-admission",default=DEFAULT_ADMISSION)
    args = parser.parse_args()
    registry = json.loads(_path(args.repository,"res://data/design_pack_assets.json").read_text(encoding="utf-8"))
    accepted = {}
    for asset,entry in sorted(registry["assets"].items()):
        if "face_repair_certificate" not in entry: continue
        pointer = entry["face_repair_certificate"]
        _require(pointer.get("admission_path") == args.write_admission, "shared admission pointer differs")
        cert_path = _artifact(args.repository,pointer,"repair certificate")
        cert = json.loads(cert_path.read_text(encoding="utf-8"))
        prepared = cert.get("prepared")
        _require(isinstance(prepared,dict) and prepared.get("baseline_sha256"), "delivery requires prepared scene predecessor")
        accepted[asset] = resolve_model_successor(args.repository,asset,cert.get("model",{}).get("baseline_sha256"),prepared_path=prepared.get("path"),old_prepared_sha=prepared.get("baseline_sha256"))
    destination = _path(args.repository,args.write_admission)
    _require(destination.suffix == ".json", "admission must be JSON")
    destination.parent.mkdir(parents=True,exist_ok=True)
    admission = {"schema_version":1,"certificate_kind":KIND,"helper_sha256":_digest(Path(__file__)),"accepted":True,"assets":accepted}
    destination.write_text(json.dumps(admission,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps({"admitted_assets":list(accepted),"admission_path":args.write_admission}))


if __name__ == "__main__":
    main()
