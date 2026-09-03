# Two pyramidal cells, the first stimulated at segment 100, connected by
# two synapses. The `params` record is discovered by nb-sim and rendered as
# sliders; every field with a `default` can be overridden live.
let cell = import "neurons/neuron_3.ncl" in
let syns = import "synapse.ncl" in
{
  params = {
    stim_current
      | nb.Slider { min = 0, max = 5000 }
      | doc "Stimulating current during the on phase (µA/cm²)"
      | default = 10.0,
    stim_offset_sec
      | nb.Slider { min = 0.001, max = 0.1 }
      | doc "Time within each period at which the stimulus switches off (s)"
      | default = 0.05,
    spacing_mm
      | nb.Slider { min = 0, max = 2 }
      | doc "Offset of the second cell from the first, per axis (mm)"
      | default = 0.5,
  },

  scene | nb.Scene =
    # Named `stim`, not `stimulator`: a record field of the same name would
    # shadow it (Nickel records are recursively scoped).
    let stim = {
      envelope = { period_sec = 0.1, onset_sec = 0.0, offset_sec = params.stim_offset_sec },
      current_shape = {
        type = 'SquareWave,
        on_current_uamps_per_square_cm = params.stim_current,
        off_current_uamps_per_square_cm = -1.0,
      },
    } in
    {
      neurons = [
        {
          neuron = cell,
          location = { x_mm = params.spacing_mm, y_mm = params.spacing_mm, z_mm = params.spacing_mm },
          stimulator_segments = [ { segment = 100, stimulator = stim } ],
        },
        {
          neuron = cell,
          location = { x_mm = 0.0, y_mm = 0.0, z_mm = 0.0 },
          stimulator_segments = [],
        },
      ],
      synapses = syns,
    },
}
