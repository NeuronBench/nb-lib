# A digit classifier drives a row of ten neurons, one per digit 0-9.
# The model (models/digits_mlp.onnx, trained by models/make_digits.py on
# scikit-learn's 8x8 digits) reads one held-out image and outputs class
# probabilities; probability p of digit d injects `drive * p` into neuron
# d's soma, so the neuron for the recognized digit fires and the rest rest.
# Open the Models window to see the image, hidden layer and probabilities.
let default_swc_neuron = import "../default_swc_neuron.ncl" in
let samples = import "../models/digit_samples.ncl" in
let cell = default_swc_neuron [
  { id = 1, x = 0.0, y = 0.0, z = 0.0, r = 0.5, type = 1, parent = -1 },
  { id = 2, x = 0.0, y = -100, z = 0.0, r = 0.5, type = 2, parent = 1 },
  { id = 3, x = 0.0, y = 100, z = 0.0, r = 0.5, type = 4, parent = 1 },
] in
let digits = std.array.range 0 10 in
{
  params = {
    sample
      | nb.Slider { min = 0, max = 19 }
      | doc "Which held-out image to show (two per digit: 0-1 are zeros, 2-3 ones, ...)"
      | default = 6,
    drive
      | nb.Slider { min = 0, max = 400 }
      | doc "Current into a neuron whose digit has probability 1 (µA/cm²); about 100-200 fires repetitively, much higher blocks"
      | default = 150,
  },

  scene | nb.Scene =
    let image = std.array.at (std.number.floor params.sample) samples in
    {
      neurons =
        std.array.map
          (fun d => {
            neuron = cell,
            location = { x_mm = d * 0.3, y_mm = 0.0, z_mm = 0.0 },
            stimulator_segments = [],
          })
          digits,
      synapses = [],
      models = [
        {
          url = "../models/digits_mlp.onnx",
          interval_sec = 0.001,
          inputs = [{ type = 'Constant, values = image.pixels }],
          outputs = [
            {
              type = 'InjectCurrent,
              taps = std.array.map (fun d => { neuron = d, segment = 1 }) digits,
              scale_uamps_per_square_cm = params.drive,
            },
          ],
        },
      ],
    },
}
