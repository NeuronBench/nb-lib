"""Generate the ONNX models used by nb-lib scenes.

    uv run --with onnx --with numpy python -I models/make_models.py

Rerun after editing; commit the regenerated .onnx files.
"""

import pathlib

import onnx
from onnx import TensorProto, helper

OUT = pathlib.Path(__file__).resolve().parent


def save(name, nodes, inputs, outputs, doc):
    graph = helper.make_graph(
        nodes,
        name,
        [helper.make_tensor_value_info(n, TensorProto.FLOAT, s) for n, s in inputs],
        [helper.make_tensor_value_info(n, TensorProto.FLOAT, s) for n, s in outputs],
        doc_string=doc,
    )
    model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 17)])
    model.ir_version = 8
    onnx.checker.check_model(model, full_check=True)
    onnx.save(model, OUT / f"{name}.onnx")


# A saturating proportional controller: drive = tanh(gain * (target - v)).
# The scene scales `drive` (in [-1, 1]) to a current.
save(
    "voltage_clamp",
    [
        helper.make_node("Sub", ["target_mv", "v_mv"], ["error_mv"]),
        helper.make_node("Mul", ["error_mv", "gain_per_mv"], ["scaled"]),
        helper.make_node("Tanh", ["scaled"], ["drive"]),
    ],
    inputs=[("v_mv", [1, 1]), ("target_mv", [1, 1]), ("gain_per_mv", [1, 1])],
    outputs=[("drive", [1, 1])],
    doc="Soft voltage clamp: drive = tanh(gain_per_mv * (target_mv - v_mv)).",
)
