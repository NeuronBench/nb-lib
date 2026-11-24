# nb-lib

The NeuronBench model library, written in [Nickel](https://nickel-lang.org).

Every file evaluates with the `nb` prelude in scope. The prelude provides
the scene schema as contracts (`nb.Scene`, `nb.Neuron`, `nb.Membrane`,
`nb.Channel`, `nb.Synapse`, ...) generated from `src/serialize.rs`, plus
helpers:

- `nb.Slider { min, max }` marks a numeric `params` field as a UI slider.
- `nb.Nullable C` accepts `null` or a `C`.
- `nb.Tagged { A = {...}, B = {...} }` checks `{ type = 'A, ... }` records.

A scene file is either a `nb.Scene` value or a record `{ params, scene }`.
Fields of `params` that carry a `default` can be overridden live from the
simulator UI; `scene` is re-evaluated on every change.

Watch out for Nickel's recursive record scoping: inside `{ neuron = neuron }`
the right-hand `neuron` refers to the field itself, not an outer `let`. Use
a different name for the binding.

Files import each other by relative path, and can be imported from anywhere
by URL once this repository is published, for example
`import "https://raw.githubusercontent.com/neuronbench/nb-lib/main/channels.ncl"`.

## Checking the library

`check/` is a small Rust crate whose tests link and fully evaluate every
`.ncl` file here against the prelude contracts. It expects `nb-nickel`
checked out as a sibling directory.

    cd check && cargo test

## Running a scene

With nb-sim checked out as a sibling, it loads `../nb-lib/scene.ncl` by
default:

    cargo run --bin bevy
    NB_SCENE=../nb-lib/demos/refractory.ncl cargo run --bin bevy
    NB_SCENE=../nb-lib/demos/onnx_clamp.ncl cargo run --bin bevy
    NB_SCENE=../nb-lib/demos/onnx_digits.ncl cargo run --bin bevy
    NB_SCENE=../nb-lib/demos/onnx_mnist.ncl cargo run --bin bevy
    NB_SCENE=../nb-lib/demos/onnx_mnist_neurons.ncl cargo run --release --bin bevy
    NB_SIM_BACKEND=cpu NB_SCENE=../nb-lib/demos/stdp_pairing.ncl cargo run --release --bin bevy

`onnx_clamp.ncl` couples an ONNX model (`models/voltage_clamp.onnx`) to the
simulation. Scenes list models under `scene.models`, binding each graph
input to voltages, time or constants and each output to injected current.
Regenerate the models with
`uv run --with onnx --with numpy python -I models/make_models.py`.

`onnx_digits.ncl` runs a small digit classifier (`models/digits_mlp.onnx`,
trained on scikit-learn's 8x8 digits) and injects each class probability
into one of ten neurons, so the neuron for the recognized digit fires.
Retrain with
`uv run --with onnx --with numpy --with scikit-learn python -I models/make_digits.py`.

`onnx_mnist.ncl` does the same with the ONNX model zoo's MNIST CNN
(`models/mnist-12.onnx`, MIT license, from
https://github.com/onnx/models) on 28x28 digits written as ASCII art: twenty
MNIST test images, or your own drawing in the demo file. Regenerate the
Softmax-wrapped model and the samples with
`uv run --with onnx --with numpy python -I models/make_mnist.py`
(it downloads the MNIST test set, about 1.6 MB, once).

`onnx_mnist_neurons.ncl` wires the same CNN into neurons at both ends and
in the middle. Its input is a 28x28 retina of passive pixel cells that you
paint in the `retina` canvas window (left-drag raises a cell's current,
right-drag lowers it); the model samples their voltages each run. One
channel of its last pooling layer drives the dendrite tips of each of four
Allen Institute cells through `hidden` taps, and the class probabilities
drive ten more. It has about 2,600 segments, so run it with `--release`.

`neurons/allen_656411100.ncl` is a human cortical neuron from the Allen
Cell Types Database (specimen 656411100,
`neurons/swc/H17.03.010.11.13.01_656411100_m.swc`), decimated to 132 of its
1497 points with every branch point and tip kept. Regenerate it, or
decimate another SWC, with
`python3 -I neurons/decimate_swc.py neurons/swc/<cell>.swc neurons/<name>.ncl [fraction]`.

`plasticity.ncl` builds glutamatergic synapses that learn from calcium:
AMPA receptors (the plastic part), NMDA receptors with Mg2+ block and slow
unbinding, a spine calcium pool, and the Graupner–Brunel calcium-threshold
rule. `demos/stdp_pairing.ncl` pairs two presynaptic cells with one
postsynaptic cell: the synapse whose spikes precede the postsynaptic spike
keeps its strength, the one whose spikes follow it is erased. nb-sim logs
each plastic synapse's calcium peak and efficacy on the CPU backend
(`NB_SIM_BACKEND=cpu`); the GPU backend doesn't read synapse state back yet.
