# Cell shapes and placement for mnist_wta.ncl, built so that every synapse
# joins segments that touch: an axon ends a few microns from the dendrite
# it contacts.
#
# Coordinates are in microns. Population d (one per digit) is centred at
# (x d, 0, 0); its three pyramidal cells stand around that axis (`member`)
# and its interneuron sits below them (`interneuron_at`).
#
# - Pyramidal cell (23 segments): an apical dendrite rising 170 µm into a
#   tuft, with two obliques; four basal dendrites, two reaching toward the
#   other members of its population, one in toward the population's axis
#   (where the interneurons' axons end), one out; an axon that descends to
#   its interneuron's dendrite, with a collateral to each other member's
#   basal dendrite.
# - Interneuron (33 segments, a basket cell): a round soma with short
#   smooth dendrites, three of them reaching up to its population's axons;
#   an axon that climbs to a horizontal trunk of its own height, running
#   under every other population, and drops a terminal to the meeting point
#   of each one's inward basal dendrites.
#
# Each neuron is { segments, at = the segment index (0-based, as synapses
# want it) of a named segment }. Soma segments have SWC id 1.
let default_swc_neuron = import "../default_swc_neuron.ncl" in

let v = fun x_ y_ z_ => { x = x_, y = y_, z = z_ } in
let add = fun a b => v (a.x + b.x) (a.y + b.y) (a.z + b.z) in
let sub = fun a b => v (a.x - b.x) (a.y - b.y) (a.z - b.z) in
let scale = fun k a => v (k * a.x) (k * a.y) (k * a.z) in
let down = fun h => v 0 (-h) 0 in

# Segments named and parented by name; ids follow the list order (soma
# first, id 1). Types: 1 soma, 2 axon, 3 basal dendrite, 4 apical dendrite.
let tree = fun parts =>
  let n = std.array.length parts in
  let ids = std.record.from_array (std.array.generate (fun i => { field = (std.array.at i parts).name, value = i + 1 }) n) in
  {
    neuron = default_swc_neuron (std.array.generate
      (fun i =>
        let p = std.array.at i parts in
        {
          id = i + 1,
          parent = if p.parent == "" then -1 else std.record.get p.parent ids,
          type = p.type,
          r = p.r,
          x = p.at.x,
          y = p.at.y,
          z = p.at.z,
        })
      n),
    at = fun name => std.record.get name ids - 1,
  } in
let seg = fun name_ parent_ type_ r_ at_ => { name = name_, parent = parent_, type = type_, r = r_, at = at_ } in

let spacing = 300 in
let column_x = fun d => (d - 4.5) * spacing in
let all_digits = std.array.range 0 10 in
let all_members = std.array.range 0 3 in
# The three pyramidal cells around their population's axis, 60 µm out.
let member = fun k => std.array.at k [v 0 0 60, v (-52) 0 (-30), v 52 0 (-30)] in
let others = fun k => std.array.filter (fun j => j != k) all_members in
# Each member's decorations turn with it, so the three don't look alike.
let turn = fun k p =>
  let cs = std.array.at k [{ c = 0, s = 1 }, { c = -0.866, s = -0.5 }, { c = 0.866, s = -0.5 }] in
  v (cs.c * p.x - cs.s * p.z) p.y (cs.s * p.x + cs.c * p.z) in
let below = v 0 (-360) 0 in
# Interneuron d's axon trunk: each at its own height and depth.
let trunk_y = fun d => -150 - 11 * d in
let trunk_z = fun d => -70 - 3 * d in
# Where interneuron d's terminal ends at another population (relative to
# that population's axis), just under its members' inward basal dendrites
# (which end at 0.08 * member k, 105 µm down).
let terminal_end = fun d => v (d - 4.5) (-111) (((d % 3) - 1) * 3) in

let pyramid = fun k =>
  let m = member k in
  let toward = fun j => sub (member j) m in
  tree (
    [
      seg "soma" "" 1 9 (v 0 0 0),
      # Apical dendrite, oblique branches and tuft.
      seg "ap1" "soma" 4 1.4 (v 0 50 0),
      seg "ap2" "ap1" 4 1.1 (v 0 110 0),
      seg "ap3" "ap2" 4 0.9 (v 0 170 0),
      seg "ob1" "ap1" 4 0.6 (turn k (v (-40) 85 12)),
      seg "ob2" "ap2" 4 0.6 (turn k (v 35 145 (-15))),
      seg "tf1" "ap3" 4 0.5 (turn k (v (-45) 220 5)),
      seg "tf2" "ap3" 4 0.5 (turn k (v 5 232 40)),
      seg "tf3" "ap3" 4 0.5 (turn k (v 45 218 (-20))),
      # Basal dendrites: inward (inhibition lands at its tip) and outward.
      seg "in_a" "soma" 3 0.8 (add (scale (-0.4) m) (down 50)),
      seg "in_b" "in_a" 3 0.6 (add (scale (-0.92) m) (down 105)),
      seg "out_a" "soma" 3 0.8 (add (scale 0.4 m) (down 15)),
      seg "out_b" "out_a" 3 0.6 (add (scale 0.9 m) (down 45)),
      # Axon: down to the interneuron's dendrite (which ends at
      # 0.6 * member k, 290 µm down).
      seg "ais" "soma" 2 0.8 (down 20),
      seg "ax1" "ais" 2 0.6 (down 45),
      seg "ax2" "ax1" 2 0.5 (add (scale (-0.2) m) (down 170)),
      seg "ax3" "ax2" 2 0.5 (add (scale (-0.4) m) (down 286)),
    ]
    # A basal dendrite toward each other member, and an axon collateral to
    # that member's basal dendrite toward this one (which ends at
    # 0.4 of the way, 55 µm down).
    @ std.array.flat_map
      (fun j => [
        seg "to%{std.string.from_number j}_a" "soma" 3 0.8 (add (scale 0.2 (toward j)) (down 25)),
        seg "to%{std.string.from_number j}_b" "to%{std.string.from_number j}_a" 3 0.6 (add (scale 0.4 (toward j)) (down 55)),
        seg "col%{std.string.from_number j}" "ax1" 2 0.4 (add (scale 0.6 (toward j)) (down 51)),
      ])
      (others k)
  ) in

let interneuron = fun d =>
  let ty = trunk_y d - below.y in
  let tz = trunk_z d in
  let name = fun prefix e => "%{prefix}%{std.string.from_number e}" in
  let right = std.array.filter (fun e => e > d) all_digits in
  let left = std.array.filter (fun e => e < d) all_digits in
  let trunk_parent = fun e =>
    if e == d + 1 || e == d - 1 then "ia1"
    else if e > d then name "tr" (e - 1)
    else name "tr" (e + 1) in
  tree (
    [
      seg "soma" "" 1 7 (v 0 0 0),
      seg "dn1a" "soma" 3 0.5 (v (-40) (-30) 15),
      seg "dn1b" "dn1a" 3 0.4 (v (-62) (-75) 30),
      seg "dn2a" "soma" 3 0.5 (v 40 (-30) (-15)),
      seg "dn2b" "dn2a" 3 0.4 (v 65 (-70) (-25)),
      seg "dn3a" "soma" 3 0.5 (v 0 (-40) (-35)),
      seg "dn3b" "dn3a" 3 0.4 (v 10 (-85) (-50)),
      # The axon climbs behind the up-dendrites to the trunk.
      seg "ia0" "soma" 2 0.5 (v 0 30 (-40)),
      seg "ia1" "ia0" 2 0.5 (v 0 ty tz),
    ]
    # Up-dendrites, one under each member of the population (its axon ends
    # 4 µm above the tip).
    @ std.array.flat_map
      (fun k =>
        let m = member k in
        [
          seg (name "up" k ++ "_a") "soma" 3 0.5 (add (scale 0.3 m) (v 0 35 0)),
          seg (name "up" k ++ "_b") (name "up" k ++ "_a") 3 0.4 (add (scale 0.6 m) (v 0 70 0)),
        ])
      all_members
    # The trunk, out both ways, with a terminal up to each population.
    @ std.array.flat_map
      (fun e =>
        let dx = (e - d) * spacing in
        [
          seg (name "tr" e) (trunk_parent e) 2 0.45 (v dx ty tz),
          seg (name "te" e) (name "tr" e) 2 0.35 (sub (add (v dx 0 0) (terminal_end d)) below),
        ])
      (right @ std.array.reverse left)
  ) in

{
  digits = all_digits,
  members = all_members,
  pyramids = std.array.map pyramid all_members,
  interneurons = std.array.map interneuron all_digits,
  # Soma positions in µm.
  pyramid_at = fun d k => add (v (column_x d) 0 0) (member k),
  interneuron_at = fun d => add (v (column_x d) 0 0) below,
  # Segment names for the synapses.
  collateral = fun k => "col%{std.string.from_number k}",
  toward = fun j => "to%{std.string.from_number j}_b",
  up = fun k => "up%{std.string.from_number k}_b",
  terminal = fun e => "te%{std.string.from_number e}",
  inward = "in_b",
  axon_end = "ax3",
  # Total membrane capacitance, in units of the soma's (default_swc_neuron:
  # soma and axon 1 µF/cm², dendrites 2; every compartment has the same
  # area), for scaling currents into these larger cells.
  capacitance = fun cell =>
    std.array.fold_left (fun acc s => acc + std.array.at (s.type - 1) [1, 1, 2, 2, 2]) 0 cell.neuron.segments,
}
