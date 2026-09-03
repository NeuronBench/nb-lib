# Membrane library: channel densities per compartment type.
let channels = import "channels.ncl" in
let leak = channels.giant_squid.leak in
let k_slow = channels.rat_thalamocortical.k_slow in
let na_transient = channels.rat_thalamocortical.na_transient in
let hcn_soma = channels.rat_ca1_pyramidal.hcn_soma in
let hcn_dendrite = channels.rat_ca1_pyramidal.hcn_dendrite in
{
  pyramidal_cell = {
    apical_dendrite | nb.Membrane = {
      capacitance_farads_per_square_cm = 2.0e-6,
      membrane_channels = [
        { channel = na_transient, siemens_per_square_cm = 0.023 },
        { channel = leak, siemens_per_square_cm = 0.03e-3 },
        { channel = hcn_dendrite, siemens_per_square_cm = 0.08e-3 },
        { channel = k_slow, siemens_per_square_cm = 0.040 },
      ],
    },

    basal_dendrite | nb.Membrane = {
      capacitance_farads_per_square_cm = 2.0e-6,
      membrane_channels = [
        { channel = leak, siemens_per_square_cm = 0.03e-3 },
        { channel = hcn_dendrite, siemens_per_square_cm = 0.08e-3 },
      ],
    },

    axon_initial_segment | nb.Membrane = {
      capacitance_farads_per_square_cm = 1.0e-6,
      membrane_channels = [
        { channel = na_transient, siemens_per_square_cm = 120.0e-3 },
        { channel = leak, siemens_per_square_cm = 0.3e-3 },
        { channel = k_slow, siemens_per_square_cm = 36.0e-3 },
      ],
    },

    axon | nb.Membrane = {
      capacitance_farads_per_square_cm = 1.0e-6,
      membrane_channels = [
        { channel = na_transient, siemens_per_square_cm = 120.0e-3 },
        { channel = leak, siemens_per_square_cm = 0.3e-3 },
        { channel = k_slow, siemens_per_square_cm = 36.0e-3 },
      ],
    },

    soma | nb.Membrane = {
      capacitance_farads_per_square_cm = 1.0e-6,
      membrane_channels = [
        { channel = k_slow, siemens_per_square_cm = 36.0e-3 },
        { channel = na_transient, siemens_per_square_cm = 120.0e-3 },
        { channel = leak, siemens_per_square_cm = 3.0e-5 },
      ],
    },
  },
}
