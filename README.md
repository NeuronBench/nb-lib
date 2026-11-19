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

`onnx_clamp.ncl` couples an ONNX model (`models/voltage_clamp.onnx`) to the
simulation. Scenes list models under `scene.models`, binding each graph
input to voltages, time or constants and each output to injected current.
Regenerate the models with
`uv run --with onnx --with numpy python -I models/make_models.py`.
