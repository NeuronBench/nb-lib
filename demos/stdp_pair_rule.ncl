# Spike-timing-dependent plasticity with the phenomenological pair rule
# (plasticity.stdp_synapse); stdp_pairing.ncl is the same protocol with
# calcium-based plasticity. Every `period` seconds cell A fires `lead`
# before the postsynaptic cell and cell B fires `lead` after it, so A's
# synapse strengthens toward efficacy 1 and B's weakens toward 0. Plastic
# synapses log their efficacy on the CPU backend:
#
#   NB_SIM_DT=1e-5 NB_SIM_BACKEND=cpu NB_SCENE=../nb-lib/demos/stdp_pair_rule.ncl cargo run --release --bin bevy
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
    learning_rate
      | nb.Slider { min = 0.0, max = 0.2 }
      | doc "Efficacy change of a simultaneous pairing"
      | default = 0.05,
  },

  scene | nb.Scene =
    let at = fun index onset => {
      neuron = cell,
      location = { x_mm = index * 0.3, y_mm = 0.0, z_mm = 0.0 },
      stimulator_segments = [{ segment = 1, stimulator = pulse onset params.period }],
    } in
    let base = 0.02 in
    let synapse = fun pre => plasticity.stdp_synapse {
      pre_neuron = pre, pre_segment = 0, post_neuron = 1, post_segment = 0,
      potentiation = params.learning_rate, depression = 0.6 * params.learning_rate,
    } in
    {
      # 0: cell A, 1: the postsynaptic cell, 2: cell B.
      neurons = [
        at 0 base,
        at 1 (base + params.lead),
        at 2 (base + 2 * params.lead),
      ],
      synapses = [synapse 0, synapse 2],
    },
}
