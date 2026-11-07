"""Add a short neutral-pose blend to each GLB animation.

Usage: python tools/smooth_animation_boundaries.py INPUT.glb OUTPUT.glb
The clips must share a rig and use float animation accessors.
"""

import json
import struct
import sys
from pathlib import Path


FADE_SECONDS = 0.28
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
FLOAT = 5126
COMPONENTS = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}
REST = {
    "translation": [0.0, 0.0, 0.0],
    "rotation": [0.0, 0.0, 0.0, 1.0],
    "scale": [1.0, 1.0, 1.0],
}


def read_glb(path):
    data = Path(path).read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or length != len(data):
        raise ValueError("Expected a valid glTF 2.0 binary file")
    position = 12
    chunks = []
    while position < len(data):
        size, kind = struct.unpack_from("<II", data, position)
        position += 8
        chunks.append((kind, data[position : position + size]))
        position += size
    if [kind for kind, _ in chunks] != [JSON_CHUNK, BIN_CHUNK]:
        raise ValueError("Expected a JSON chunk followed by a BIN chunk")
    return json.loads(chunks[0][1]), bytearray(chunks[1][1])


def read_accessor(document, binary, index):
    accessor = document["accessors"][index]
    view = document["bufferViews"][accessor["bufferView"]]
    if accessor["componentType"] != FLOAT or "sparse" in accessor:
        raise ValueError("Only non-sparse float animation accessors are supported")
    width = COMPONENTS[accessor["type"]]
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride", width * 4)
    return [
        list(struct.unpack_from("<" + "f" * width, binary, offset + i * stride))
        for i in range(accessor["count"])
    ]


def add_accessor(document, binary, values, kind):
    width = COMPONENTS[kind]
    while len(binary) % 4:
        binary.append(0)
    offset = len(binary)
    for value in values:
        if len(value) != width:
            raise ValueError("Animation value has the wrong width")
        binary.extend(struct.pack("<" + "f" * width, *value))
    view_index = len(document["bufferViews"])
    document["bufferViews"].append(
        {"buffer": 0, "byteOffset": offset, "byteLength": len(binary) - offset}
    )
    accessor = {
        "bufferView": view_index,
        "componentType": FLOAT,
        "count": len(values),
        "type": kind,
    }
    if kind == "SCALAR":
        accessor["min"] = [min(value[0] for value in values)]
        accessor["max"] = [max(value[0] for value in values)]
    document["accessors"].append(accessor)
    return len(document["accessors"]) - 1


def smooth(document, binary):
    for animation in document["animations"]:
        for channel in animation["channels"]:
            sampler = animation["samplers"][channel["sampler"]]
            times = read_accessor(document, binary, sampler["input"])
            output = document["accessors"][sampler["output"]]
            values = read_accessor(document, binary, sampler["output"])
            if len(times) != len(values) or not times:
                raise ValueError("Unexpected animation sampler layout")
            path = channel["target"]["path"]
            node = document["nodes"][channel["target"]["node"]]
            rest = list(node.get(path, REST[path]))
            end_time = times[-1][0] + 2 * FADE_SECONDS
            blended_times = [[0.0]] + [[time[0] + FADE_SECONDS] for time in times] + [[end_time]]
            blended_values = [rest] + values + [rest]
            sampler["input"] = add_accessor(document, binary, blended_times, "SCALAR")
            sampler["output"] = add_accessor(document, binary, blended_values, output["type"])
            sampler["interpolation"] = "LINEAR"
    document["buffers"][0]["byteLength"] = len(binary)


def write_glb(path, document, binary):
    encoded = json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    binary.extend(b"\0" * (-len(binary) % 4))
    total = 12 + 8 + len(encoded) + 8 + len(binary)
    Path(path).write_bytes(
        struct.pack("<4sII", b"glTF", 2, total)
        + struct.pack("<II", len(encoded), JSON_CHUNK)
        + encoded
        + struct.pack("<II", len(binary), BIN_CHUNK)
        + binary
    )


if __name__ == "__main__":
    source, destination = sys.argv[1:3]
    document, binary = read_glb(source)
    smooth(document, binary)
    write_glb(destination, document, binary)
    print(destination, len(document["animations"]), "clips")
