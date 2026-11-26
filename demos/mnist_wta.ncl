# MNIST into a winner-takes-all network of realistic neurons: the network
# decides which digit it saw, and remembers it.
#
# - Input: paint a digit on the 28x28 retina canvas (left-drag raises a
#   cell, right-drag lowers it; the `sample` slider paints an MNIST test
#   image). The canvas drives a retina of passive pixel cells (at the
#   back, for show) and is read by the MNIST CNN (models/mnist_canvas.onnx:
#   mnist_softmax.onnx reading the canvas's 0..1 cells, so a cleared
#   canvas reads as exactly black).
# - Ten populations, one per digit, of three pyramidal cells standing
#   around a common axis, plus one basket-cell interneuron below them (the
#   shapes are in mnist_wta_cells.ncl). The CNN's probability for digit d
#   injects current into population d's cells. Every pyramidal cell also
#   gets a constant -0.15 * drive: a cleared canvas gives about 0.1 per
#   class (0.088-0.115), so it drives nothing.
# - Recurrent self-excitation: each pyramidal cell sends an axon
#   collateral to a basal dendrite of each other cell of its population,
#   through slow glutamate receptors (NMDA kinetics, 50 ms), so a
#   population that starts firing keeps itself firing. (Fast AMPA
#   self-excitation can't: the cells fire together, so each EPSP lands
#   while they are refractory.)
# - Lateral inhibition: each population's axons descend to its
#   interneuron's dendrites (fast AMPA). The interneuron's axon climbs to a
#   horizontal trunk of its own height running under the other
#   populations, and drops a terminal to each one, ending among the tips
#   of its cells' inward basal dendrites: slow (20 ms) GABA synapses onto
#   K+-selective channels.
#
# Every synapse joins the end of an axon branch to the end of a dendrite
# it touches (within 11 µm), so the wiring can be read off the shapes.
#
# Paint a digit: its population wins and silences the others. Press Clear
# in the canvas window: the drive drops to nothing, but the winner keeps
# firing (memory). Paint another digit: its population takes over (its
# interneuron switches the old winner off) and stays on in turn.
#
# The `demo` slider shows ten MNIST test digits in turn instead, each
# followed by a blank frame, and the Readouts window scores the winner
# (the population with the most spikes) against the digit shown or, on a
# blank frame, the digit just before it. (Each population's interneuron
# stands for it there: it fires with its population.) Natively, a larger
# step runs it about 20x faster:
#
#   NB_SIM_DT=1e-5 NB_STEPS_PER_FRAME=1000 NB_SET_PARAMS_AT="0.01:demo=1" NB_SCENE=../nb-lib/demos/mnist_wta.ncl cargo run --release --bin bevy
#
# Checked natively that way with three-compartment cells (GPU kernel: both
# MNIST test images of every digit; CPU kernel: one of each): the shown
# digit's population always won alone (about 100 Hz), the old winner fell
# silent within a few spikes, and the winner kept firing at about 60-70 Hz
# through 1 s blanks. (The one 5 that the CNN reads as a 6 makes population
# 6 win.) Without inhibition old winners keep firing beside new ones;
# self-excitation above about 60000 locks in the first winner for good.
# With the shaped cells and the scaling below (GPU kernel, the demo's ten
# digits twice): every frame right with a unique winner, about 120 Hz
# while shown and 45 Hz through the 0.3 s blank.
#
# Moving a slider respawns the cells, so the memory starts over (the
# painting stays, unless you move `sample`).
let plasticity = import "../plasticity.ncl" in
let channels = import "../channels.ncl" in
let cells = import "mnist_wta_cells.ncl" in
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
let pixel_cell = {
  segments = [{ id = 1, x = 0.0, y = 0.0, z = 0.0, r = 6.0, type = 1, parent = -1 }],
  membranes = [{
    capacitance_farads_per_square_cm = 1.0e-6,
    membrane_channels = [{ channel = channels.giant_squid.leak, siemens_per_square_cm = 1.0e-3 }],
  }],
} in
# Every compartment has the same area whatever its drawn size, so a cell's
# currents spread over all its compartments: scale what goes into these
# cells by their capacitance relative to the three-compartment cell of the
# digit demos (soma 1, axon 1, apical dendrite 2), for which the slider
# values were found. Currents go into the soma (capacitance 1); synapses
# end on dendrites (capacitance 2).
let small_cell = 4 in
let current_scale = cells.capacitance (std.array.at 0 cells.pyramids) / small_cell in
let synapse_scale = fun cell => cells.capacitance cell / 2 / small_cell in
let pyramid_scale = synapse_scale (std.array.at 0 cells.pyramids) in
let interneuron_scale = synapse_scale (std.array.at 0 cells.interneurons) in
let pyramid = fun k => std.array.at k cells.pyramids in
let interneuron = fun d => std.array.at d cells.interneurons in

let side = 28 in
let pixels = std.array.range 0 (side * side) in
let digits = std.array.range 0 10 in
let size = 3 in
let members = std.array.range 0 size in
# Neuron indices: pixels, then the excitatory cells population by
# population, then one interneuron per population.
let first_cell = side * side in
let first_interneuron = first_cell + 10 * size in
let member = fun d k => first_cell + d * size + k in
let soma = fun n => { neuron = n, segment = 1 } in

# The demo's digits: one MNIST test image of each (the second of each pair
# in mnist_samples.ncl, all classified correctly), in a mixed order.
let demo_digits = [3, 7, 0, 5, 9, 2, 6, 1, 8, 4] in
let blank = std.array.map (fun _ => 0) pixels in
{
  params = {
    demo
      | nb.Slider { min = 0, max = 1 }
      | doc "0: paint on the retina; 1: show ten test digits in turn, each followed by a blank frame, and score the winner in the Readouts window"
      | default = 0,
    sample
      | nb.Slider { min = 0, max = 19 }
      | doc "MNIST test image painted on the retina (two per digit): moving this slider repaints it, and Reset in the canvas window restores it"
      | default = 6,
    frame_sec
      | nb.Slider { min = 0.1, max = 1 }
      | doc "Demo: simulated seconds each digit, and each blank, is shown"
      | default = 0.3,
    drive
      | nb.Slider { min = 0, max = 300 }
      | doc "µA/cm² into a population's cells at probability 1 (less a constant 0.15 * drive, just above chance)"
      | default = 100,
    self_excitation
      | nb.Slider { min = 0, max = 100000 }
      | doc "Conductance of the slow excitatory synapses between the cells of one population, times plasticity.ncl's NMDA conductance (about 30000-50000 keeps a population firing on its own yet lets a driven rival switch it off; more locks in the first winner)"
      | default = 40000,
    inhibition
      | nb.Slider { min = 0, max = 100000 }
      | doc "Conductance of each interneuron's slow GABA synapses onto the other populations' cells, times plasticity.ncl's inhibitory_synapse conductance (10000-20000 works; 0 leaves old winners firing beside new ones)"
      | default = 10000,
  },

  scene | nb.Scene =
    # A fixed (non-plastic) glutamatergic synapse, soma to soma, with
    # AMPA receptors at `fast` times plasticity.ncl's AMPA conductance and
    # slow receptors at `slow` times its NMDA conductance. The slow ones
    # have NMDA kinetics (unbinding in 50 ms) but no Mg2+ block: with the
    # block, this small cell latches into a depolarized plateau near
    # -20 mV instead of firing.
    let scaled = fun r weight => {
      membrane_channel = {
        channel = r.membrane_channel.channel,
        siemens_per_square_cm = r.membrane_channel.siemens_per_square_cm * weight,
      },
      neurotransmitter_sensitivity = r.neurotransmitter_sensitivity,
    } in
    let slow_receptor = fun weight => scaled plasticity.receptors.nmda weight & {
      binding = { rise_sec = 2.0e-3, decay_sec = 50.0e-3 },
    } in
    let excite = fun fast slow pre pre_seg post post_seg => {
      pre_neuron = pre, pre_segment = pre_seg, post_neuron = post, post_segment = post_seg,
      synapse_membranes = {
        cleft_solution = { k = 5.0e-3, na = 145.0e-3, cl = 110.0e-3, ca = 2.5e-3 },
        presynaptic_pumps = [plasticity.glutamate_release],
        postsynaptic_receptors =
          (if fast > 0 then [scaled plasticity.receptors.ampa fast] else [])
          @ (if slow > 0 then [slow_receptor slow] else []),
        surface_area_square_mm = 1.0e-6,
        transmitter_concentrations = { glutamate_molar = 1.0e-4, gaba_molar = 0.0 },
      },
    } in
    # A fixed GABA synapse onto a K+-selective channel (as plasticity.ncl's
    # inhibitory_synapse, since these cells rest below the Cl- reversal),
    # at `params.inhibition` times its conductance, and slow like the
    # excitation (unbinding in 20 ms): a 1 ms pulse of K+ conductance only
    # delays a driven cell's next spike.
    let inhibit = fun pre pre_seg post post_seg => {
      pre_neuron = pre, pre_segment = pre_seg, post_neuron = post, post_segment = post_seg,
      synapse_membranes = {
        cleft_solution = { k = 5.0e-3, na = 145.0e-3, cl = 110.0e-3, ca = 2.5e-3 },
        presynaptic_pumps = [{ transmitter = "GABA", transmitter_pump_params = plasticity.glutamate_release.transmitter_pump_params }],
        postsynaptic_receptors = [{
          membrane_channel = {
            channel = { ion_selectivity = { k = 1.0, na = 0.0, cl = 0.0, ca = 0.0 }, activation = null, inactivation = null },
            siemens_per_square_cm = 1000.0 * params.inhibition * pyramid_scale,
          },
          neurotransmitter_sensitivity = { transmitter = "GABA", concentration_at_half_max_molar = 3.0e-3, slope = 2000.0 },
          binding = { rise_sec = 2.0e-3, decay_sec = 20.0e-3 },
        }],
        surface_area_square_mm = 1.0e-6,
        transmitter_concentrations = { glutamate_molar = 0.0, gaba_molar = 1.0e-4 },
      },
    } in
    # A constant current: the chance-level drive taken back.
    let bias = {
      envelope = { period_sec = 1.0, onset_sec = 0.0, offset_sec = 1.0 },
      current_shape = {
        type = 'SquareWave,
        on_current_uamps_per_square_cm = -0.15 * params.drive * current_scale,
        off_current_uamps_per_square_cm = -0.15 * params.drive * current_scale,
      },
    } in
    let place = fun n x y z stimulated => {
      neuron = n,
      location = { x_mm = x, y_mm = y, z_mm = z },
      stimulator_segments = if stimulated then [{ segment = 1, stimulator = bias }] else [],
    } in
    # A shaped cell at a position in µm.
    let place_at = fun cell at stimulated => {
      neuron = cell.neuron,
      location = { x_mm = at.x / 1000, y_mm = at.y / 1000, z_mm = at.z / 1000 },
      stimulator_segments = if stimulated then [{ segment = 1, stimulator = bias }] else [],
    } in
    let demo = params.demo >= 0.5 in
    let sample = std.number.floor params.sample in
    let image = std.array.at sample samples in
    # The canvas keeps its painting across slider moves while its name
    # stays the same; naming it after the sample repaints it on a new one.
    let canvas_name = if demo then "retina: demo" else "retina: sample %{std.string.from_number sample}" in
    {
      neurons =
        std.array.map
          (fun p => place pixel_cell (((p % side) - side / 2) * 0.04) (1.2 - (std.number.floor (p / side)) * 0.04) (-2.0) false)
          pixels
        @ std.array.flat_map
          (fun d => std.array.map (fun k => place_at (pyramid k) (cells.pyramid_at d k) true) members)
          digits
        @ std.array.map (fun d => place_at (interneuron d) (cells.interneuron_at d) false) digits,
      synapses =
        # Self-excitation within each population: member j's axon
        # collateral toward k ends on k's basal dendrite toward j.
        std.array.flat_map
          (fun d =>
            std.array.flat_map
              (fun j =>
                std.array.map
                  (fun k =>
                    excite 0 (params.self_excitation * pyramid_scale)
                      (member d j) ((pyramid j).at (cells.collateral k))
                      (member d k) ((pyramid k).at (cells.toward j)))
                  (std.array.filter (fun k => k != j) members))
              members)
          digits
        # Each population's axons end on its interneuron's up-dendrites...
        @ std.array.flat_map
          (fun d =>
            std.array.map
              (fun k =>
                excite (1500 * interneuron_scale) 0
                  (member d k) ((pyramid k).at cells.axon_end)
                  (first_interneuron + d) ((interneuron d).at (cells.up k)))
              members)
          digits
        # ...and its interneuron's terminal at each other population ends
        # among that population's inward basal dendrites.
        @ std.array.flat_map
          (fun d =>
            std.array.flat_map
              (fun e =>
                std.array.map
                  (fun k =>
                    inhibit
                      (first_interneuron + d) ((interneuron d).at (cells.terminal e))
                      (member e k) ((pyramid k).at cells.inward))
                  members)
              (std.array.filter (fun e => e != d) digits))
          digits,
      canvases = [
        {
          name = canvas_name,
          width = side,
          height = side,
          taps = std.array.map soma pixels,
          max_uamps_per_square_cm = 30,
          initial = levels_of image.art,
        }
        & (if demo then {
          frames = std.array.flat_map (fun d => [levels_of (std.array.at (2 * d + 1) samples).art, blank]) demo_digits,
          labels = std.array.flat_map (fun d => [d, d]) demo_digits,
          frame_sec = params.frame_sec,
        } else {}),
      ],
      readouts =
        if demo then [
          {
            name = "winning population vs. digit (blank frames: the digit before)",
            taps = std.array.map (fun d => soma (first_interneuron + d)) digits,
            canvas = canvas_name,
            spike_threshold_mv = -20,
          },
          {
            name = "every excitatory cell",
            taps = std.array.flat_map (fun d => std.array.map (fun k => soma (member d k)) members) digits,
            canvas = canvas_name,
            spike_threshold_mv = -20,
            labeled = false,
          },
        ] else [],
      models = [
        {
          url = "../models/mnist_canvas.onnx",
          interval_sec = 0.002,
          inputs = [{ type = 'Canvas, name = canvas_name }],
          outputs = [{ type = 'Ignore }],
          hidden = [
            {
              value = "probs",
              elements = std.array.flat_map (fun d => std.array.map (fun _ => d) members) digits,
              output = {
                type = 'InjectCurrent,
                taps = std.array.flat_map (fun d => std.array.map (fun k => soma (member d k)) members) digits,
                scale_uamps_per_square_cm = params.drive * current_scale,
              },
            },
          ],
        },
      ],
    },
}
