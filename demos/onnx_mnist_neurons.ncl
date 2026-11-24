# The MNIST CNN wired into realistic neurons at both ends and in the middle.
#
# - Input: a 28x28 "retina" of single-compartment pixel cells. Paint on the
#   `retina` canvas (left-drag raises a cell's current, right-drag lowers
#   it); the model samples the cells' voltages each run as its image.
# - Middle: four decimated Allen Institute cells (neurons/allen_656411100.ncl)
#   each get one channel of the last pooling layer (`maxpool2d2`, 16 values)
#   on 16 of their basal-dendrite tips.
# - Output: ten more Allen cells, one per digit, take the class
#   probabilities at the soma.
#
# Open the Models window to see every layer; with "Show in the 3D scene" on,
# the layers stand between the retina (at the back) and the output cells.
let channels = import "../channels.ncl" in
let allen = import "../neurons/allen_656411100.ncl" in
let samples = import "../models/mnist_samples.ncl" in

# ASCII art (. - + #) to 784 values in 0..1, row-major.
let levels_of = fun art =>
  let level = fun c =>
    if c == "#" then 1.0
    else if c == "+" then 0.6667
    else if c == "-" then 0.3333
    else if c == "." || c == " " then 0
    else std.fail_with "unknown pixel `%{c}` in a digit drawing: use . - + #" in
  std.array.flat_map (fun row => std.array.map level (std.string.characters row)) (std.string.split "\n" art) in

# A fast passive compartment: 1 ms time constant, about 1 mV per µA/cm².
let pixel_membrane = {
  capacitance_farads_per_square_cm = 1.0e-6,
  membrane_channels = [{ channel = channels.giant_squid.leak, siemens_per_square_cm = 1.0e-3 }],
} in
let pixel_cell = {
  segments = [{ id = 1, x = 0.0, y = 0.0, z = 0.0, r = 6.0, type = 1, parent = -1 }],
  membranes = [pixel_membrane],
} in

let side = 28 in
let pixels = std.array.range 0 (side * side) in
let digits = std.array.range 0 10 in
let hidden_cells = std.array.range 0 4 in

# Basal-dendrite tips of the Allen cell: type 3 segments nothing grows from.
let tips =
  let segs = allen.segments in
  segs
  |> std.array.filter (fun s => s.type == 3 && !(std.array.any (fun t => t.parent == s.id) segs))
  |> std.array.map (fun s => s.id) in
let tip = fun k => std.array.at (k % std.array.length tips) tips in

# Neuron indices: pixels first, then hidden cells, then digit cells.
let first_hidden = side * side in
let first_digit = first_hidden + 4 in
{
  params = {
    sample
      | nb.Slider { min = 0, max = 19 }
      | doc "MNIST test image painted on the retina at load (two per digit); Reset in the canvas window restores it"
      | default = 6,
    rest_mv
      | nb.Slider { min = -100, max = -40 }
      | doc "Pixel cells' resting voltage (their leak reversal, about -90 mV), read as a black pixel"
      | default = -90,
    pixel_mv
      | nb.Slider { min = 5, max = 60 }
      | doc "Depolarization read as a white pixel (255)"
      | default = 30,
    hidden_drive
      | nb.Slider { min = 0, max = 0.1 }
      | doc "µA/cm² into a dendrite tip per unit of its maxpool2d2 value (which runs to the hundreds); a passive tip gains about 1 mV per µA/cm²"
      | default = 0.03,
    drive
      | nb.Slider { min = 0, max = 400 }
      | doc "Current into a digit cell's soma at probability 1 (µA/cm²)"
      | default = 150,
  },

  scene | nb.Scene =
    let image = std.array.at (std.number.floor params.sample) samples in
    {
      neurons =
        # The retina stands behind the network's input layer.
        std.array.map
          (fun p => {
            neuron = pixel_cell,
            location = {
              x_mm = 1.35 + ((p % side) - side / 2) * 0.04,
              y_mm = 0.6 - (std.number.floor (p / side)) * 0.04,
              z_mm = -3.6,
            },
            stimulator_segments = [],
          })
          pixels
        @ std.array.map
          (fun h => {
            neuron = allen,
            location = { x_mm = h * 0.9, y_mm = -0.2, z_mm = -1.1 },
            stimulator_segments = [],
          })
          hidden_cells
        @ std.array.map
          (fun d => {
            neuron = allen,
            location = { x_mm = d * 0.6 - 1.35, y_mm = -0.2, z_mm = 0.0 },
            stimulator_segments = [],
          })
          digits,
      synapses = [],
      canvases = [
        {
          name = "retina",
          width = side,
          height = side,
          taps = std.array.map (fun p => { neuron = p, segment = 1 }) pixels,
          max_uamps_per_square_cm = params.pixel_mv,
          initial = levels_of image.art,
        },
      ],
      models = [
        {
          url = "../models/mnist_softmax.onnx",
          interval_sec = 0.001,
          inputs = [
            {
              type = 'Voltages,
              taps = std.array.map (fun p => { neuron = p, segment = 1 }) pixels,
              offset_mv = params.rest_mv,
              scale = 255 / params.pixel_mv,
            },
          ],
          outputs = [
            {
              type = 'InjectCurrent,
              taps = std.array.map (fun d => { neuron = first_digit + d, segment = 1 }) digits,
              scale_uamps_per_square_cm = params.drive,
            },
          ],
          hidden =
            std.array.map
              (fun h => {
                value = "maxpool2d2",
                elements = std.array.map (fun k => h * 16 + k) (std.array.range 0 16),
                output = {
                  type = 'InjectCurrent,
                  taps = std.array.map (fun k => { neuron = first_hidden + h, segment = tip k }) (std.array.range 0 16),
                  scale_uamps_per_square_cm = params.hidden_drive,
                },
              })
              hidden_cells,
        },
      ],
    },
}
