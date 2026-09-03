# A row of identical small neurons, each receiving a fixed pulse on one
# dendrite and a second pulse whose timing and strength depend on the
# neuron's column. Demonstrates building a scene with functions.
let default_swc_neuron = import "../default_swc_neuron.ncl" in
let cell = default_swc_neuron [
  { id = 1, x = 0.0, y = 0.0, z = 0.0, r = 0.5, type = 1, parent = -1 },

  { id = 2, x = 0.0, y = -100, z = 0.0, r = 0.5, type = 2, parent = 1 },
  { id = 3, x = -50, y = -200, z = 0.0, r = 0.5, type = 2, parent = 2 },
  { id = 4, x = 50, y = -200, z = 0.0, r = 0.5, type = 2, parent = 2 },

  { id = 5, x = -100, y = 0.0, z = 0.0, r = 0.5, type = 2, parent = 1 },
  { id = 6, x = -200, y = -50, z = 0.0, r = 0.5, type = 2, parent = 5 },
  { id = 7, x = -200, y = 50, z = 0.0, r = 0.5, type = 2, parent = 5 },

  { id = 8, x = 100, y = 0.0, z = 0.0, r = 0.5, type = 2, parent = 1 },
  { id = 9, x = 200, y = -50, z = 0.0, r = 0.5, type = 2, parent = 8 },
  { id = 10, x = 200, y = 50, z = 0.0, r = 0.5, type = 2, parent = 8 },

  { id = 11, x = 0.0, y = 75, z = 0.0, r = 0.5, type = 4, parent = 1 },
  { id = 12, x = 0.0, y = 150, z = 0.0, r = 0.5, type = 4, parent = 11 },
  { id = 13, x = 0.0, y = 225, z = 0.0, r = 0.5, type = 4, parent = 12 },
  { id = 14, x = 0.0, y = 300, z = 0.0, r = 0.5, type = 4, parent = 13 },
] in
let mk_neuron = fun row column =>
  let stim1 = {
    envelope = { period_sec = 0.020, onset_sec = 0.0, offset_sec = 0.0010 },
    current_shape = {
      type = 'SquareWave,
      on_current_uamps_per_square_cm = 200.0,
      off_current_uamps_per_square_cm = -2.0,
    },
  } in
  let onset = 0.0005 + column * 0.0010 in
  let stim2 = {
    envelope = { period_sec = 0.020, onset_sec = onset, offset_sec = onset + 0.001 },
    current_shape = {
      type = 'SquareWave,
      on_current_uamps_per_square_cm = row * 50.1 + 200.1,
      off_current_uamps_per_square_cm = -2.0,
    },
  } in
  {
    neuron = cell,
    location = { x_mm = column * 0.6, y_mm = row * 0.7, z_mm = 0.0 },
    stimulator_segments = [
      { segment = 3, stimulator = stim1 },
      { segment = 4, stimulator = stim2 },
    ],
  }
in
{
  params = {
    columns
      | nb.Slider { min = 1, max = 20 }
      | doc "Number of neurons in the row"
      | default = 11,
  },

  scene | nb.Scene = {
    neurons = std.array.map (fun c => mk_neuron 0 c) (std.array.range 0 (std.number.floor params.columns)),
    synapses = [],
  },
}
