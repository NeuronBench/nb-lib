"""Make models/mnist_canvas.onnx: mnist_softmax.onnx reading a canvas.

    uv run --with onnx --with numpy python -I models/make_mnist_canvas.py

A canvas gives its cells in 0..1 (white = 1); the MNIST CNN wants pixels
in 0..255. This prepends a Mul by 255 to models/mnist_softmax.onnx (made
by make_mnist.py), so a scene can feed a canvas straight in with a
`'Canvas` input. A cleared canvas is then exactly black, which the CNN
reads as chance (about 0.1 per class); retina voltages a fraction of a
millivolt off rest already read as a confident, arbitrary digit.

Deterministic; rerun after editing and commit the output.
"""

import pathlib

import numpy as np
import onnx
from onnx import helper, numpy_helper
from onnx.reference import ReferenceEvaluator

OUT = pathlib.Path(__file__).resolve().parent

model = onnx.load(OUT / "mnist_softmax.onnx")
graph = model.graph
(image,) = [i for i in graph.input if i.name not in {t.name for t in graph.initializer}]
canvas_name = "canvas"
graph.initializer.append(numpy_helper.from_array(np.array(255.0, dtype=np.float32), "canvas_to_pixels"))
for node in graph.node:
    node.input[:] = ["pixels_0_255" if x == image.name else x for x in node.input]
graph.node.insert(0, helper.make_node("Mul", [canvas_name, "canvas_to_pixels"], ["pixels_0_255"], name="canvas_to_pixels"))
canvas = helper.make_tensor_value_info(canvas_name, onnx.TensorProto.FLOAT, [1, 1, 28, 28])
graph.input.remove(image)
graph.input.insert(0, canvas)
onnx.checker.check_model(model, full_check=True)
onnx.save(model, OUT / "mnist_canvas.onnx")

# Check: the same answers as mnist_softmax on scaled inputs, chance on black.
ref = ReferenceEvaluator(onnx.load(OUT / "mnist_softmax.onnx"))
new = ReferenceEvaluator(model)
x = np.random.default_rng(0).random((1, 1, 28, 28), dtype=np.float32)
assert np.allclose(ref.run(None, {image.name: x * 255})[0], new.run(None, {canvas_name: x})[0], atol=1e-5)
black = new.run(None, {canvas_name: np.zeros((1, 1, 28, 28), np.float32)})[0]
assert black.max() < 0.12, black
print("black canvas:", np.round(black, 3))
