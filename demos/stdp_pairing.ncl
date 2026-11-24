# Spike-timing-dependent plasticity from biophysics. Two presynaptic cells
# each synapse onto one postsynaptic cell through plastic NMDA/AMPA synapses
# (see ../plasticity.ncl). Every `period` seconds, cell A fires `lead`
# before the postsynaptic cell and cell B fires `lead` after it, so A's
# glutamate is still bound to NMDA receptors when the postsynaptic spike
# expels their Mg2+ (calcium soars: potentiation), while B's arrives after
# the spike (calcium only reaches the depression range). Watch the
# synapses' efficacy in the log (`synapse N: ... efficacy`).
let plasticity = import "../plasticity.ncl" in
let default_swc_neuron = import "../default_swc_neuron.ncl" in
# The small three-compartment cell of the digit demos: it rests near
# -85 mV and fires one spike per brief strong pulse.
let cell = default_swc_neuron [
  { id = 1, x = 0.0, y = 0.0, z = 0.0, r = 0.5, type = 1, parent = -1 },
  { id = 2, x = 0.0, y = -100, z = 0.0, r = 0.5, type = 2, parent = 1 },
  { id = 3, x = 0.0, y = 100, z = 0.0, r = 0.5, type = 4, parent = 1 },
] in
let pulse = fun onset period =>
  {
    envelope = { period_sec = period, onset_sec = onset, offset_sec = onset + 0.001 },
    current_shape = {
      type = 'SquareWave,
      on_current_uamps_per_square_cm = 400.0,
      off_current_uamps_per_square_cm = 0.0,
    },
  } in
{
  params = {
    lead
      | nb.Slider { min = 0.002, max = 0.04 }
      | doc "How long (s) cell A fires before, and cell B after, the postsynaptic cell"
      | default = 0.01,
    period
      | nb.Slider { min = 0.05, max = 0.5 }
      | doc "Seconds between pairings"
      | default = 0.1,
    learning_time_constant
      | nb.Slider { min = 0.1, max = 150 }
      | doc "Graupner–Brunel time constant (s); 150 is physiological, smaller learns faster"
      | default = 10,
  },

  scene | nb.Scene =
    let at = fun index onset => {
      neuron = cell,
      location = { x_mm = index * 0.3, y_mm = 0.0, z_mm = 0.0 },
      stimulator_segments = [{ segment = 1, stimulator = pulse onset params.period }],
    } in
    let base = 0.02 in
    # These cells rest near -90 mV, where the Mg2+ block is tighter than at
    # the library's -70 mV calibration: a lone presynaptic spike lifts spine
    # calcium to about 0.3 µM, a pairing about three times that.
    let thresholds = { depression = 0.25e-6, potentiation = 0.36e-6 } in
    {
      # 0: cell A, 1: the postsynaptic cell, 2: cell B.
      neurons = [
        at 0 base,
        at 1 (base + params.lead),
        at 2 (base + 2 * params.lead),
      ],
      synapses = [
        plasticity.synapse {
          pre_neuron = 0, pre_segment = 0, post_neuron = 1, post_segment = 0,
          initial_efficacy = 0.5, time_constant_sec = params.learning_time_constant,
          depression_threshold_molar = thresholds.depression,
          potentiation_threshold_molar = thresholds.potentiation,
        },
        plasticity.synapse {
          pre_neuron = 2, pre_segment = 0, post_neuron = 1, post_segment = 0,
          initial_efficacy = 0.5, time_constant_sec = params.learning_time_constant,
          depression_threshold_molar = thresholds.depression,
          potentiation_threshold_molar = thresholds.potentiation,
        },
      ],
    },
}
