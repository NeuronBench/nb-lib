# The ONNX model zoo's MNIST CNN drives a row of ten neurons, one per digit
# 0-9. The model (models/mnist_softmax.onnx: the zoo's mnist-12 plus a
# Softmax, see models/make_mnist.py) reads a 28x28 image; probability p of
# digit d injects `drive * p` into neuron d's soma, so the neuron for the
# recognized digit fires and the rest stay near rest.
#
# Images are ASCII art: `.` (or space) is black, `-` `+` `#` are brighter.
# Pick one of 20 MNIST test images with the `sample` slider, or set it to 20
# and edit `drawing` below to draw your own. Open the Models window to see
# the image, both conv layers and the probabilities.
let default_swc_neuron = import "../default_swc_neuron.ncl" in
let samples = import "../models/mnist_samples.ncl" in

let drawing = m%"
  ............................
  ............................
  ............................
  ............................
  ............................
  ..........+######+..........
  .........##########.........
  ........###+....+###........
  ........##........##........
  ..................##........
  .................+##........
  ................###+........
  ..............####..........
  ............####............
  ...........###..............
  ..........###...............
  .........###................
  ........###.................
  ........##..................
  ........##################..
  ........##################..
  ............................
  ............................
  ............................
  ............................
  ............................
  ............................
  ............................
"% in

# ASCII art to 784 pixel values in 0-255, row-major.
let pixels_of = fun art =>
  let level = fun c =>
    if c == "#" then 255
    else if c == "+" then 170
    else if c == "-" then 85
    else if c == "." || c == " " then 0
    else std.fail_with "unknown pixel `%{c}` in a digit drawing: use . - + #" in
  let rows = std.string.split "\n" art in
  let pixels = std.array.flat_map (fun row => std.array.map level (std.string.characters row)) rows in
  if std.array.length rows != 28 || std.array.length pixels != 784 then
    std.fail_with "a digit drawing must be 28 rows of 28 characters; this one has %{std.to_string (std.array.length rows)} rows and %{std.to_string (std.array.length pixels)} characters"
  else pixels in

let cell = default_swc_neuron [
  { id = 1, x = 0.0, y = 0.0, z = 0.0, r = 0.5, type = 1, parent = -1 },
  { id = 2, x = 0.0, y = -100, z = 0.0, r = 0.5, type = 2, parent = 1 },
  { id = 3, x = 0.0, y = 100, z = 0.0, r = 0.5, type = 4, parent = 1 },
] in
let digits = std.array.range 0 10 in
{
  params = {
    sample
      | nb.Slider { min = 0, max = 20 }
      | doc "MNIST test image (two per digit: 0-1 are zeros, 2-3 ones, ...); 20 is your `drawing`"
      | default = 6,
    drive
      | nb.Slider { min = 0, max = 400 }
      | doc "Current into a neuron whose digit has probability 1 (µA/cm²); about 100-200 fires repetitively, much higher blocks"
      | default = 150,
  },

  scene | nb.Scene =
    let index = std.number.floor params.sample in
    let art = if index >= 20 then drawing else (std.array.at index samples).art in
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
          url = "../models/mnist_softmax.onnx",
          interval_sec = 0.001,
          inputs = [{ type = 'Constant, values = pixels_of art }],
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
