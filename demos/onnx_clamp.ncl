# An ONNX model in the loop: a soft voltage clamp holds one neuron's soma at
# a target voltage, while a second, identical neuron without the clamp
# rests for comparison. The model (models/voltage_clamp.onnx) reads the soma
# voltage every `interval_sec` and injects
#   max_current * tanh(gain * (target - v))
# back into the soma.
let default_swc_neuron = import "../default_swc_neuron.ncl" in
let cell = default_swc_neuron [
  { id = 1, x = 0.0, y = 0.0, z = 0.0, r = 0.5, type = 1, parent = -1 },
  { id = 2, x = 0.0, y = -100, z = 0.0, r = 0.5, type = 2, parent = 1 },
  { id = 3, x = -100, y = 0.0, z = 0.0, r = 0.5, type = 3, parent = 1 },
  { id = 4, x = 100, y = 0.0, z = 0.0, r = 0.5, type = 3, parent = 1 },
  { id = 5, x = 0.0, y = 100, z = 0.0, r = 0.5, type = 4, parent = 1 },
] in
let soma_of = fun n => { neuron = n, segment = 1 } in
let at = fun x => { neuron = cell, location = { x_mm = x, y_mm = 0.0, z_mm = 0.0 }, stimulator_segments = [] } in
{
  params = {
    target_mv
      | nb.Slider { min = -90, max = 0 }
      | doc "Voltage the clamp holds the left soma at (mV)"
      | default = -50,
    gain
      | nb.Slider { min = 0, max = 2 }
      | doc "Controller gain (1/mV): higher is stiffer"
      | default = 0.5,
    max_current
      | nb.Slider { min = 0, max = 500 }
      | doc "Largest current the clamp may inject (µA/cm²)"
      | default = 200,
  },

  scene | nb.Scene = {
    neurons = [at 0.0, at 0.4],
    synapses = [],
    models = [
      {
        url = "../models/voltage_clamp.onnx",
        interval_sec = 0.0001,
        inputs = [
          { type = 'Voltages, taps = [soma_of 0], offset_mv = 0, scale = 1 },
          { type = 'Constant, values = [params.target_mv] },
          { type = 'Constant, values = [params.gain] },
        ],
        outputs = [
          { type = 'InjectCurrent, taps = [soma_of 0], scale_uamps_per_square_cm = params.max_current },
        ],
      },
    ],
  },
}
