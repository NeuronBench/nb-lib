# Two glutamatergic synapses from neuron 0 onto neuron 1.
let glutamate_release = {
  transmitter = "Glutamate",
  transmitter_pump_params = {
    target_concentration = {
      min_molar = 1.0e-4,
      max_molar = 1.1e-2,
      slope = 1.0,
      v_at_half_max_mv = 0.0,
    },
    time_constant = {
      type = 'Gaussian,
      v_at_max_tau_mv = 0.0,
      c_base = 1.0e-3,
      c_amp = 1.0e-6,
      sigma = 1.0,
    },
  },
} in
let ampa_receptor = {
  membrane_channel = {
    channel = {
      ion_selectivity = { k = 0.5, na = 0.5, cl = 0.0, ca = 0.0 },
      activation = null,
      inactivation = null,
    },
    siemens_per_square_cm = 1.0e7,
  },
  neurotransmitter_sensitivity = {
    transmitter = "Glutamate",
    concentration_at_half_max_molar = 1.0,
    slope = 1000.0,
  },
} in
# The parameter must not be called `post_segment`: inside the record that
# name would refer to the field itself.
let mk_synapse = fun post_seg =>
  {
    pre_neuron = 0,
    pre_segment = 37,
    post_neuron = 1,
    post_segment = post_seg,
    synapse_membranes = {
      cleft_solution = { k = 5.0e-3, na = 145.0e-3, cl = 4.0e-3, ca = 2.5e-3 },
      presynaptic_pumps = [ glutamate_release ],
      postsynaptic_receptors = [ ampa_receptor ],
      surface_area_square_mm = 1.0e-6,
      transmitter_concentrations = { glutamate_molar = 0.1e-3, gaba_molar = 0.1e-3 },
    },
  } | nb.Synapse
in
[ mk_synapse 333, mk_synapse 303 ]
