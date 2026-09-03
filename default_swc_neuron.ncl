# Build a neuron from SWC-style segment rows, assigning a membrane by the
# SWC `type` column: 1 soma, 2 axon, 3 basal dendrite, 4 apical dendrite.
#
# Note: `lib` must not be named `membranes`, because a record field named
# `membranes` would shadow it inside the record (Nickel records are
# recursively scoped).
let lib = import "membranes.ncl" in
fun segs =>
  {
    segments = segs,
    membranes = [
      lib.pyramidal_cell.soma,
      lib.pyramidal_cell.axon,
      lib.pyramidal_cell.basal_dendrite,
      lib.pyramidal_cell.apical_dendrite,
      lib.pyramidal_cell.apical_dendrite,
    ],
  } | nb.Neuron
