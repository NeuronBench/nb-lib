# Teaching realistic neurons to do what an ANN does, layer by layer.
#
# digits_mlp (8x8 pixels -> 32 hidden ReLUs -> 10 digit probabilities) gets
# a realistic twin with the same three layers:
#
# - 64 input cells, one per pixel, driven by a stream of digit images (the
#   `digits` canvas). The ANN sees the same images.
# - 32 hidden cells: input -> hidden synapses, all excitatory and plastic.
# - 10 output cells, one per digit: hidden -> output synapses, plastic.
# - An inhibitory partner for every input and hidden cell, which fires
#   when its partner does and inhibits the layer above through plastic
#   synapses of its own. Real neurons are excitatory or inhibitory, never
#   both, so this is how the realistic network gets the ANN's negative
#   weights: input cell i excites hidden cell h with one learned weight
#   and, through its partner, inhibits it with another.
#
# The ANN is the teacher. Its hidden layer gives each hidden cell a target
# firing rate, and its output probabilities give each output cell one
# (`TargetRate`: nothing is injected). The plastic synapses learn by ReSuMe
# (plasticity.supervised_synapse): an excitatory synapse strengthens while
# its cell fires below the target rate and weakens while it fires above,
# in proportion to the presynaptic trace; an inhibitory one does the
# opposite. Learning stops when every cell fires as its ANN unit asks.
#
# The Readouts window scores the output cells: the one with the most spikes
# during an image is the realistic network's answer. To see what was
# learned, set `teacher` to 0 (the ANN is removed; learning stops, and the
# input alone drives the network) and `stream` to 1 (images the realistic
# cells never trained on). Learned weights survive slider changes.
#
# Natively, a larger step and more steps per frame run about 0.26 simulated
# seconds per second on the GPU (a pass over the 300 images in about 3
# minutes):
#
#   NB_SIM_DT=1e-5 NB_STEPS_PER_FRAME=1000 NB_SCENE=../nb-lib/demos/digits_transfer.ncl cargo run --release --bin bevy
let plasticity = import "../plasticity.ncl" in
let default_swc_neuron = import "../default_swc_neuron.ncl" in
let stream = import "../models/digit_stream.ncl" in
# The small three-compartment cell of the digit demos. With the default
# -1.8 µA/cm² bias it rests near -90 mV and fires about 40 Hz at 9 µA/cm²,
# 66 Hz at 30 and 94 Hz at 60 (depolarization block above about 200).
let cell = default_swc_neuron [
  { id = 1, x = 0.0, y = 0.0, z = 0.0, r = 0.5, type = 1, parent = -1 },
  { id = 2, x = 0.0, y = -100, z = 0.0, r = 0.5, type = 2, parent = 1 },
  { id = 3, x = 0.0, y = 100, z = 0.0, r = 0.5, type = 4, parent = 1 },
] in
let side = 8 in
let pixels = std.array.range 0 (side * side) in
let hiddens = std.array.range 0 32 in
let digits = std.array.range 0 10 in
# Neuron indices.
let first_hidden = side * side in
let first_digit = first_hidden + 32 in
# Inhibitory partners of the input cells, then of the hidden cells.
let first_input_partner = first_digit + 10 in
let first_hidden_partner = first_input_partner + side * side in
let soma = fun n => { neuron = n, segment = 1 } in
let place = fun x y z => {
  neuron = cell,
  location = { x_mm = x, y_mm = y, z_mm = z },
  stimulator_segments = [],
} in
{
  params = {
    teacher
      | nb.Slider { min = 0, max = 1 }
      | doc "1: the ANN teaches (target rates, learning on); 0: the ANN is removed and the input alone drives the network"
      | default = 1,
    stream
      | nb.Slider { min = 0, max = 1 }
      | doc "0: the 300 training images; 1: 100 images the realistic network never trained on"
      | default = 0,
    frame_sec
      | nb.Slider { min = 0.05, max = 0.5 }
      | doc "Simulated seconds each image is shown"
      | default = 0.15,
    pixel_drive
      | nb.Slider { min = 0, max = 150 }
      | doc "µA/cm² into an input cell for a white pixel"
      | default = 60,
    max_rate
      | nb.Slider { min = 10, max = 150 }
      | doc "Target rate (Hz) for a digit of probability 1"
      | default = 80,
    hidden_rate
      | nb.Slider { min = 1, max = 60 }
      | doc "Target rate (Hz) per unit of an ANN hidden value (typical active values are 1-3, the largest about 7; the cells top out near 150 Hz)"
      | default = 15,
    learning_rate
      | nb.Slider { min = 0, max = 0.02 }
      | doc "ReSuMe rate of the input -> hidden synapses: efficacy change per unit of presynaptic trace per missing (or extra) spike"
      | default = 0.003,
    max_weight
      | nb.Slider { min = 10, max = 2000 }
      | doc "AMPA conductance multiplier of an input -> hidden synapse at efficacy 1 (about 1000 makes one 94 Hz input drive a cell on its own)"
      | default = 400,
    output_learning_rate
      | nb.Slider { min = 0, max = 0.1 }
      | doc "ReSuMe rate of the hidden -> digit synapses (hidden cells fire sparsely, so their traces are small)"
      | default = 0.003,
    output_max_weight
      | nb.Slider { min = 10, max = 4000 }
      | doc "AMPA conductance multiplier of a hidden -> digit synapse at efficacy 1"
      | default = 1000,
    inhibition
      | nb.Slider { min = 0, max = 4 }
      | doc "Conductance at efficacy 1 of a plastic inhibitory synapse, relative to the excitatory synapses of the same layer"
      | default = 1,
  },

  scene | nb.Scene =
    let images = if params.stream < 0.5 then stream.train else stream.test in
    let plastic = fun rate weight pre post => plasticity.supervised_synapse {
      pre_neuron = pre, pre_segment = 0, post_neuron = post, post_segment = 0,
      learning_rate = rate, initial_efficacy = 0.05, max_weight = weight,
    } in
    # A cell drives its inhibitory partner one to one: a fixed synapse
    # strong enough (about 3000) for the partner to follow every spike.
    let onto_partner = fun pre post => plasticity.supervised_synapse {
      pre_neuron = pre, pre_segment = 0, post_neuron = post, post_segment = 0,
      learning_rate = 0, initial_efficacy = 1, max_weight = 3000,
    } in
    let inhibit = fun rate weight pre post => plasticity.inhibitory_synapse {
      pre_neuron = pre, pre_segment = 0, post_neuron = post, post_segment = 0,
      learning_rate = rate, strength = weight * params.inhibition,
    } in
    {
      neurons =
        std.array.map (fun p => place ((p % side) * 0.15 - 0.5) (0.5 - (std.number.floor (p / side)) * 0.15) (-2.0)) pixels
        @ std.array.map (fun h => place (h * 0.1 - 1.6) 0.0 (-1.0)) hiddens
        @ std.array.map (fun d => place (d * 0.3 - 1.35) 0.0 0.0) digits
        @ std.array.map (fun p => place ((p % side) * 0.15 - 0.5) (0.5 - (std.number.floor (p / side)) * 0.15) (-2.3)) pixels
        @ std.array.map (fun h => place (h * 0.1 - 1.6) (-0.3) (-1.0)) hiddens,
      synapses =
        std.array.flat_map (fun h => std.array.map (fun p => plastic params.learning_rate params.max_weight p (first_hidden + h)) pixels) hiddens
        @ std.array.flat_map (fun d => std.array.map (fun h => plastic params.output_learning_rate params.output_max_weight (first_hidden + h) (first_digit + d)) hiddens) digits
        @ std.array.map (fun p => onto_partner p (first_input_partner + p)) pixels
        @ std.array.map (fun h => onto_partner (first_hidden + h) (first_hidden_partner + h)) hiddens
        @ std.array.flat_map (fun h => std.array.map (fun p => inhibit params.learning_rate params.max_weight (first_input_partner + p) (first_hidden + h)) pixels) hiddens
        @ std.array.flat_map (fun d => std.array.map (fun h => inhibit params.output_learning_rate params.output_max_weight (first_hidden_partner + h) (first_digit + d)) hiddens) digits,
      canvases = [
        {
          name = "digits",
          width = side,
          height = side,
          taps = std.array.map soma pixels,
          max_uamps_per_square_cm = params.pixel_drive,
          frames = std.array.map (fun i => i.pixels) images,
          frame_sec = params.frame_sec,
          labels = std.array.map (fun i => i.label) images,
        },
      ],
      readouts = [
        {
          name = "digit cells vs. labels",
          taps = std.array.map (fun d => soma (first_digit + d)) digits,
          canvas = "digits",
          spike_threshold_mv = -20,
        },
        {
          name = "hidden cells",
          taps = std.array.map (fun h => soma (first_hidden + h)) hiddens,
          canvas = "digits",
          spike_threshold_mv = -20,
          labeled = false,
        },
        {
          name = "hidden partners",
          taps = std.array.map (fun h => soma (first_hidden_partner + h)) hiddens,
          canvas = "digits",
          spike_threshold_mv = -20,
          labeled = false,
        },
      ],
      models =
        if params.teacher < 0.5 then []
        else [
          {
            url = "../models/digits_mlp.onnx",
            interval_sec = 0.005,
            inputs = [{ type = 'Canvas, name = "digits" }],
            outputs = [
              { type = 'TargetRate, taps = std.array.map (fun d => soma (first_digit + d)) digits, scale_hz = params.max_rate },
            ],
            hidden = [
              {
                value = "relu1",
                elements = hiddens,
                output = {
                  type = 'TargetRate,
                  taps = std.array.map (fun h => soma (first_hidden + h)) hiddens,
                  scale_hz = params.hidden_rate,
                },
              },
            ],
          },
        ],
    },
}
