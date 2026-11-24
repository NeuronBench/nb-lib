# Glutamatergic synapses that learn from calcium, built from biophysics:
#
# - AMPA receptors: fast, carry most of the depolarizing current, and are
#   the plastic part (their conductance scales with the synapse's weight).
# - NMDA receptors: unbind slowly (50 ms) and are blocked by Mg2+ at rest,
#   so they pass calcium mostly when glutamate is bound *and* the
#   postsynaptic membrane is depolarized: a coincidence detector.
# - Spine voltage-gated calcium channels (VGCCs), opened by the
#   back-propagating spike: the postsynaptic spike's own calcium.
# - A spine calcium pool fed by both, cleared in 12 ms.
# - The Graupner–Brunel (2012) rule: calcium above `depression_threshold`
#   weakens the synapse, above `potentiation_threshold` strengthens it.
#
# Calibrated with clamped spikes (postsynaptic rest -70 mV) in nb-sim's
# tests/plasticity.rs, in Graupner & Brunel's arrangement: a lone
# presynaptic spike lifts spine calcium to about 1 µM, under the depression
# threshold (no change); a lone postsynaptic spike to about 1.4 µM, between
# the thresholds (depression); a postsynaptic spike 5-40 ms after a
# presynaptic one, while NMDA receptors are still bound, to about 4 µM
# (potentiation). That gives the Bi & Poo spike-timing window. Rates are
# Graupner & Brunel's; their 150 s time constant is a parameter, since
# simulated seconds are slow.
let release = {
  transmitter = "Glutamate",
  transmitter_pump_params = {
    target_concentration = {
      min_molar = 1.0e-4,
      max_molar = 1.1e-2,
      slope = 2.0,
      v_at_half_max_mv = 0.0,
    },
    time_constant = {
      type = 'Gaussian,
      v_at_max_tau_mv = 0.0,
      c_base = 1.0e-3,
      c_amp = 0.0,
      sigma = 1.0,
    },
  },
} in
let glutamate_sensitivity = {
  transmitter = "Glutamate",
  concentration_at_half_max_molar = 3.0e-3,
  slope = 2000.0,
} in
let ampa_receptor = {
  membrane_channel = {
    channel = { ion_selectivity = { k = 0.5, na = 0.5, cl = 0.0, ca = 0.0 }, activation = null, inactivation = null },
    siemens_per_square_cm = 1000.0,
  },
  neurotransmitter_sensitivity = glutamate_sensitivity,
  plastic = true,
} in
let nmda_receptor = {
  membrane_channel = {
    channel = { ion_selectivity = { k = 0.45, na = 0.45, cl = 0.0, ca = 0.1 }, activation = null, inactivation = null },
    siemens_per_square_cm = 10.0,
  },
  neurotransmitter_sensitivity = glutamate_sensitivity,
  binding = { rise_sec = 5.0e-3, decay_sec = 50.0e-3 },
  magnesium_block = { magnesium_molar = 1.0e-3 },
} in
# A spine voltage-gated calcium channel: always "bound" (it needs no
# transmitter), opened by the back-propagating spike, so a postsynaptic
# spike brings calcium of its own.
let vgcc_receptor = {
  membrane_channel = {
    channel = {
      ion_selectivity = { k = 0.0, na = 0.0, cl = 0.0, ca = 1.0 },
      activation = {
        gates = 1,
        magnitude = { v_at_half_max_mv = -20.0, slope = 5.0 },
        time_constant = { type = 'Gaussian, v_at_max_tau_mv = -20.0, c_base = 1.0e-3, c_amp = 0.0, sigma = 1.0 },
      },
      inactivation = null,
    },
    siemens_per_square_cm = 0.1,
  },
  neurotransmitter_sensitivity = { transmitter = "Glutamate", concentration_at_half_max_molar = 0.0, slope = 1.0e6 },
} in
{
  # (The `let` names differ from the field names: Nickel records are
  # recursive, so `ampa = ampa` would refer to the field itself.)
  receptors = { ampa = ampa_receptor, nmda = nmda_receptor, vgcc = vgcc_receptor },
  glutamate_release = release,

  # A plastic glutamatergic synapse. `time_constant_sec` sets how fast it
  # learns (Graupner & Brunel use 150 s); the weight runs from 0 to 2x the
  # AMPA conductance as the efficacy runs from 0 to 1. The calcium
  # thresholds default to the calibration above. Cells that rest lower, or
  # spike differently, need their own `depression_threshold_molar` (just
  # above a lone presynaptic spike's calcium peak) and
  # `potentiation_threshold_molar` (just above a lone postsynaptic spike's);
  # nb-sim logs plastic synapses' calcium peaks to read these off.
  # (The argument is one record, `args`: a field like `pre_neuron = pre_neuron`
  # would refer to itself, since Nickel records are recursive.)
  synapse = fun args =>
    {
      pre_neuron = args.pre_neuron,
      pre_segment = args.pre_segment,
      post_neuron = args.post_neuron,
      post_segment = args.post_segment,
      synapse_membranes = {
        cleft_solution = { k = 5.0e-3, na = 145.0e-3, cl = 110.0e-3, ca = 2.5e-3 },
        presynaptic_pumps = [release],
        postsynaptic_receptors = [ampa_receptor, nmda_receptor, vgcc_receptor],
        surface_area_square_mm = 1.0e-6,
        transmitter_concentrations = { glutamate_molar = 1.0e-4, gaba_molar = 0.0 },
        calcium = { resting_molar = 50.0e-9, decay_sec = 12.0e-3, spine_volume_cubic_um = 0.1 },
        plasticity = {
          depression_threshold_molar = std.record.get_or "depression_threshold_molar" 1.2e-6 args,
          potentiation_threshold_molar = std.record.get_or "potentiation_threshold_molar" 1.5e-6 args,
          depression_rate = 200.0,
          potentiation_rate = 321.8,
          time_constant_sec = args.time_constant_sec,
          bistability = 0.0,
          initial_efficacy = args.initial_efficacy,
          weight_at_0 = 0.0,
          weight_at_1 = 2.0,
        },
      },
    } | nb.Synapse,
}
