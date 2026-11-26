# Teaching realistic neurons to do what an ANN does, layer by layer.
#
# digits_mlp (8x8 pixels -> 32 hidden ReLUs -> 10 digit probabilities) gets
# a realistic twin with the same three layers:
#
# - 64 input cells, one per pixel, driven by a stream of digit images (the
#   `digits` canvas). The ANN sees the same images.
# - 32 hidden cells: input -> hidden synapses, all excitatory and plastic.
# - 10 output cells, one per digit: hidden -> output synapses, plastic.
# - Two inhibitory interneurons, one per layer, excited by the whole layer
#   below and inhibiting every cell of the layer above (feedforward
#   inhibition): what lets excitatory-only synapses act like the ANN's
#   negative weights.
#
# The ANN is the teacher. Its hidden layer gives each hidden cell a target
# firing rate, and its output probabilities give each output cell one
# (`TargetRate`: nothing is injected). The plastic synapses learn by ReSuMe
# (plasticity.supervised_synapse): strengthened toward the target rate in
# proportion to the presynaptic trace, weakened by each spike the cell
# fires, so learning stops when every cell fires as its ANN unit asks.
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
let hidden_inhibitor = first_digit + 10 in
let digit_inhibitor = hidden_inhibitor + 1 in
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
      | doc "Target rate (Hz) for a digit of probability 1, and for the largest hidden value"
      | default = 80,
    learning_rate
      | nb.Slider { min = 0, max = 0.02 }
      | doc "ReSuMe rate: efficacy change per unit of presynaptic trace per missing (or extra) spike"
      | default = 0.003,
    max_weight
      | nb.Slider { min = 10, max = 2000 }
      | doc "AMPA conductance multiplier of a plastic synapse at efficacy 1 (about 1000 makes one 94 Hz input drive a cell on its own)"
      | default = 400,
    inhibition
      | nb.Slider { min = 0, max = 2000 }
      | doc "Strength of each interneuron's synapses onto the layer above"
      | default = 300,
  },

  scene | nb.Scene =
    let images = if params.stream < 0.5 then stream.train else stream.test in
    let plastic = fun pre post => plasticity.supervised_synapse {
      pre_neuron = pre, pre_segment = 0, post_neuron = post, post_segment = 0,
      learning_rate = params.learning_rate, initial_efficacy = 0.05, max_weight = params.max_weight,
    } in
    # A fixed excitatory synapse onto an interneuron (a supervised synapse
    # that never learns).
    let onto_inhibitor = fun pre post => plasticity.supervised_synapse {
      pre_neuron = pre, pre_segment = 0, post_neuron = post, post_segment = 0,
      learning_rate = 0, initial_efficacy = 1, max_weight = 200,
    } in
    let inhibit = fun pre post => plasticity.inhibitory_synapse {
      pre_neuron = pre, pre_segment = 0, post_neuron = post, post_segment = 0,
      strength = params.inhibition,
    } in
    {
      neurons =
        std.array.map (fun p => place ((p % side) * 0.15 - 0.5) (0.5 - (std.number.floor (p / side)) * 0.15) (-2.0)) pixels
        @ std.array.map (fun h => place (h * 0.1 - 1.6) 0.0 (-1.0)) hiddens
        @ std.array.map (fun d => place (d * 0.3 - 1.35) 0.0 0.0) digits
        @ [place 1.9 0.0 (-1.5), place 1.9 0.0 (-0.5)],
      synapses =
        std.array.flat_map (fun h => std.array.map (fun p => plastic p (first_hidden + h)) pixels) hiddens
        @ std.array.flat_map (fun d => std.array.map (fun h => plastic (first_hidden + h) (first_digit + d)) hiddens) digits
        @ std.array.map (fun p => onto_inhibitor p hidden_inhibitor) pixels
        @ std.array.map (fun h => inhibit hidden_inhibitor (first_hidden + h)) hiddens
        @ std.array.map (fun h => onto_inhibitor (first_hidden + h) digit_inhibitor) hiddens
        @ std.array.map (fun d => inhibit digit_inhibitor (first_digit + d)) digits,
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
                  scale_hz = params.max_rate / stream.hidden_max,
                },
              },
            ],
          },
        ],
    },
}
