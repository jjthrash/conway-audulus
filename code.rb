require 'json'
require 'yaml'
require 'securerandom'

def uuid?(string)
  string.kind_of?(String) && /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/ =~ string
end

# Node -> [ UUID ]
def scan_uuids(node)
  case node
  when Hash
    node.map {|key, elem|
      if uuid?(elem)
        elem
      else
        scan_uuids(elem)
      end
    }.flatten
  when Array
    node.map {|elem| scan_uuids(elem)}.flatten
  else
    []
  end
end

def build_uuid_map(node)
  existing_uuids = scan_uuids(node)
  existing_uuids.reduce({}) {|h, uuid|
    h[uuid] = SecureRandom.uuid()
    h
  }
end

def clone_node(node)
  uuid_map = build_uuid_map(node)
  clone_node_helper(node, uuid_map)
end

def clone_node_helper(node, uuid_map)
  case node
  when Hash
    Hash[node.map {|key, elem|
      if uuid?(elem)
        [key, uuid_map[elem]]
      else
        [key, clone_node_helper(elem, uuid_map)]
      end
    }]
  when Array
    node.map {|elem|
      clone_node_helper(elem, uuid_map)
    }
  else
    node
  end
end

def add_node(patch, node)
  patch['nodes'] << node
  patch
end

def add_nodes(patch, nodes)
  nodes.each do |node|
    add_node(patch, node)
  end
end

def move_node(node, x, y)
  node['position'] = {
    'x' => x,
    'y' => y,
  }
  node
end

def expose_node(node, x, y)
  node['exposedPosition'] = {
    'x' => x,
    'y' => y,
  }
  node
end

def build_init_doc
  print "building init doc.."
  result = clone_node(INIT_PATCH)
  puts "done."
  result
end

def build_interlace_grid_node
  doc = build_init_doc
  patch = doc['patch']
  input_nodes =
    64.times.map {|i|
      node = build_input_node
      node['name'] = ''
      move_node(node, 0, i*50)
      expose_node(node, (i % 8) * 20, (20*8) - (i / 8) * 20)
      node
    }
  add_nodes(input_nodes)

  mux_nodes =
    8.times.map {|i|
      node = build_mux_node
      move_node(node, 100, i*50*8)
      node
    }
  add_nodes(mux_nodes)

  mux_nodes.zip(input_nodes.each_slice(8)) do |mux_node, input_slice|
    input_slice.each_with_index do |input_node, i|
      wire_output_to_input(patch, input_node, 0, mux_node, i+1)
    end
  end

  top_mux_node = build_mux_node
  move_node(top_mux_node, 200, 0)
  add_node(patch, top_mux_node)

  mux_nodes.each_with_index do |mux_node, i|
    wire_output_to_input(patch, mux_node, 0, top_mux_node, i+1)
  end

  mono_to_stereo_node = build_simple_node("MonoToStereo")
  move_node(mono_to_stereo_node, 400, 0)
  add_node(patch, mono_to_stereo_node)

  wire_output_to_input(patch, top_mux_node, 0, mono_to_stereo_node, 1)

  output_node = build_output_node
  move_node(output_node, 600, 0)
  add_node(patch, output_node)

  wire_output_to_input(patch, mono_to_stereo_node, 0, output_node, 0)

  divider = build_simple_node("Expr")
  divider['expr'] = "x/8"
  move_node(divider, input_nodes.last['position']['x'] - 200, 0)
  add_node(patch, divider)

  wire_output_to_input(patch, divider, 0, top_mux_node, 0)

  clock_via = build_via_node
  move_node(clock_via, divider['position']['x'] - 200, 0)
  add_node(patch, clock_via)

  wire_output_to_input(patch, clock_via, 0, divider, 0)
  wire_output_to_input(patch, clock_via, 0, mono_to_stereo_node, 0)
  mux_nodes.each do |mux_node|
    wire_output_to_input(patch, clock_via, 0, mux_node, 0)
  end

  doc
end

def build_deinterlace_grid_node
  doc = build_init_doc
  patch = doc['patch']
  output_nodes =
    64.times.map {|i|
      node = build_output_node
      node['name'] = ''
      move_node(node, 0, i*100)
      expose_node(node, (i % 8) * 20, 20*8 - (i / 8) * 20)
      node
    }

  sh_nodes =
    64.times.map {|i|
      node = build_sample_and_hold_node
      move_node(node, -200, i*100)
      node
    }

  sh_nodes.zip(output_nodes) do |sh_node, output_node|
    wire_output_to_input(patch, sh_node, 0, output_node, 0)
  end

  signal_demux_nodes =
    8.times.map {|i|
      node = build_demux_node
      move_node(node, -400, i*800)
      node
    }

  gate_demux_nodes =
    8.times.map {|i|
      node = build_demux_node
      move_node(node, -600, i * 800 + 100)
      node
    }

  (output_nodes + sh_nodes + signal_demux_nodes + gate_demux_nodes).each do |node|
    add_node(patch, node)
  end

  signal_demux_nodes.zip(gate_demux_nodes, sh_nodes.each_slice(8)) do |signal_demux_node, gate_demux_node, sh_slice|
    sh_slice.each_with_index do |sh_node, i|
      wire_output_to_input(patch, signal_demux_node, i, sh_node, 0)
      wire_output_to_input(patch, gate_demux_node, i, sh_node, 1)
    end
  end

  top_signal_demux_node = build_demux_node
  move_node(top_signal_demux_node, -800, 200)
  add_node(patch, top_signal_demux_node)

  top_gate_demux_node = build_demux_node
  move_node(top_gate_demux_node, -1000, 300)
  add_node(patch, top_gate_demux_node)

  signal_demux_nodes.each_slice(8) do |slice|
    slice.each_with_index do |node, i|
      wire_output_to_input(patch, top_signal_demux_node, i, node, 1)
    end
  end

  gate_demux_nodes.each_slice(8) do |slice|
    slice.each_with_index do |node, i|
      wire_output_to_input(patch, top_gate_demux_node, i, node, 1)
    end
  end

  pulse_via = build_via_node
  move_node(pulse_via, -1200, 0)
  add_node(patch, pulse_via)

  clock_via = build_via_node
  move_node(clock_via, -1200, 50)
  add_node(patch, clock_via)

  divided_clock_via = build_via_node
  move_node(divided_clock_via, -1200, 100)
  add_node(patch, divided_clock_via)

  divider = build_simple_node("Expr")
  divider['expr'] = "x/8"
  move_node(divider, -1400, 100)
  add_node(patch, divider)

  wire_output_to_input(patch, divider, 0, divided_clock_via, 0)

  signal_via = build_via_node
  move_node(signal_via, -1200, 150)
  add_node(patch, signal_via)

  stereo_to_mono = build_simple_node('StereoToMono')
  move_node(stereo_to_mono, -1600, 150)
  add_node(patch, stereo_to_mono)

  wire_output_to_input(patch, stereo_to_mono, 0, signal_via, 0)
  wire_output_to_input(patch, stereo_to_mono, 1, divider, 0)
  wire_output_to_input(patch, stereo_to_mono, 1, clock_via, 0)

  (signal_demux_nodes + gate_demux_nodes).each do |node|
    wire_output_to_input(patch, clock_via, 0, node, 0)
  end

  wire_output_to_input(patch, pulse_via, 0, top_gate_demux_node, 1)
  wire_output_to_input(patch, divided_clock_via, 0, top_gate_demux_node, 0)
  wire_output_to_input(patch, divided_clock_via, 0, top_signal_demux_node, 0)
  wire_output_to_input(patch, signal_via, 0, top_signal_demux_node, 1)

  input_node = build_input_node
  move_node(input_node, -1800, 150)
  expose_node(input_node, -40, 0)
  add_node(patch, input_node)

  wire_output_to_input(patch, input_node, 0, stereo_to_mono, 0)

  doc
end

# input 0: gate
# input 1-8: neighbors
# input 9: button
def build_conway_node
  print "building conway node.."
  result = clone_node(CONWAY_PATCH)
  puts "done."
  result
end

def build_light_node
  clone_node(LIGHT_NODE)
end

def build_trigger_node
  clone_node(TRIGGER_NODE)
end

def build_subpatch_node
  clone_node(SUBPATCH_NODE)
end

# gate output is output 0
def build_clock_node
  clone_node(CLOCK_NODE)
end

def build_via_node
  clone_node(VIA_NODE)
end

def build_input_node
  clone_node(INPUT_NODE)
end

def build_output_node
  result = build_simple_node("Output")
  result['name'] = "Output"
  result
end

def build_sample_and_hold_node
  build_simple_node("Sample & Hold")
end

def build_mux_node
  build_simple_node("Mux8")
end

def build_demux_node
  build_simple_node("Demux8")
end

def build_simple_node(type)
  clone_node({
    "type" => type,
    "id" => "7e5486fc-994c-44f0-ae83-5ebba54d7e3b",
    "position" => {
      "x" => 0,
      "y" => 0
    }
  })
end

def build_conway_grid_patch(width, height)
  doc = build_init_doc()
  patch = doc['patch']

  # CONWAY NODES
  conway_node_width = 160
  conway_node_height = 170
  conway_nodes =
    height.times.flat_map {|row|
      print "building row #{row}.."
      nodes =
        width.times.map {|column| # columns
          build_conway_node()
        }

      nodes.each_with_index do |node, column|
        move_node(node, column * 160, (height - row) * conway_node_height)
      end

      puts "done."
      nodes
    }

  print "adding (#{conway_nodes.count}) nodes"
  conway_nodes.each do |node|
    print "."
    add_node(patch, node)
  end
  puts "done."

  print "wiring outputs"
  conway_nodes.each do |node|
    print "."
    neighbor_nodes(conway_nodes, width, node).each_with_index do |neighbor, i|
      if neighbor
        wire_output_to_input(patch, node, 0, neighbor, i+1)
      end
    end
  end
  puts "done."

  # TRIGGER NODES
  trigger_node_width = 150
  trigger_node_height = 50
  trigger_nodes =
    height.times.flat_map {|row|
      nodes =
        width.times.map {|column|
          build_trigger_node
        }

      nodes.each_with_index do |node, column|
        move_node(node, width * -trigger_node_width - 100 + trigger_node_width * column, (height - row) * trigger_node_height)
        expose_node(node, column * 35, 35*(height - row))
      end
    }

  trigger_nodes.each do |node|
    add_node(patch, node)
  end

  conway_nodes.zip(trigger_nodes) do |conway_node, trigger_node|
    wire_output_to_input(patch, trigger_node, 0, conway_node, 9)
  end

  # LIGHT NODES
  light_node_width = 100
  light_node_height = 50
  light_nodes =
    height.times.flat_map {|row|
      nodes = width.times.map { build_light_node }
      nodes.each_with_index do |node, column|
        move_node(node, width * conway_node_width + 100 + light_node_width * column, (height - row) * light_node_height)
        expose_node(node, column * 35, 35*(height - row))
      end
    }
  add_nodes(patch, light_nodes)

  conway_nodes.zip(light_nodes) do |conway_node, light_node|
    wire_output_to_input(patch, conway_node, 0, light_node, 0)
  end

  # INPUT NODE
  input = build_input_node
  input["name"] = "clock"
  add_node(patch, input)

  conway_nodes.each do |node|
    wire_output_to_input(patch, input, 0, node, 0)
  end

  patch
end

def build_conway_patch(width, height)
  doc = build_init_doc
  patch = doc['patch']

  # CONWAY SUBPATCH
  subpatch = build_subpatch_node
  subpatch['subPatch'] = build_conway_grid_patch(width, height)
  add_node(patch, subpatch)

  # CLOCK NODE
  clock = build_clock_node
  add_node(patch, clock)
  wire_output_to_input(patch, clock, 0, subpatch, 0)

  doc
end

def make_subpatch_node(patch)
  patch["type"] = "Patch"
  patch['subPatch'] = pa
  patch
end

# return array of surrounding neighbors, starting bottom right going CW
# nil if no neighbor there
NEIGHBOR_POSITIONS = [
  [1,1], #br
  [0,1],
  [-1,1],
  [-1,0],
  [-1,-1], #tl
  [0,-1],
  [1,-1],
  [1,0],
]

def neighbor_nodes(conway_nodes, stride, node)
  index = conway_nodes.index(node)
  row = index / stride
  column = index - row * stride
  height = conway_nodes.count / stride
  NEIGHBOR_POSITIONS.map {|relative_column, relative_row|
    proposed_row = row + relative_row
    proposed_column = column + relative_column
    if proposed_row < 0
      proposed_row += height
    elsif proposed_row >= height
      proposed_row -= height
    end
    if proposed_column < 0
      proposed_column += stride
    elsif proposed_column >= stride
      proposed_column -= stride
    end

    conway_nodes[proposed_column + proposed_row * stride]
  }
end

def wire_output_to_input(patch, source_node, source_output, destination_node, destination_input)
  patch['wires'] << {
    "from" => source_node['id'],
    "output" => source_output,
    "to" => destination_node['id'],
    "input": destination_input
  }
end

INIT_PATCH = YAML.load <<YAML
---
version: 1
patch:
  id: 2aedc73c-4095-4d1b-ab1b-2121ea9ac19d
  pan:
    x: 0.0
    y: 0.0
  zoom: 1.0
  nodes: []
  wires: []
YAML


CONWAY_PATCH = JSON.parse(File.read('conway_node.audulus'))['patch']['nodes'][0]

LIGHT_NODE = YAML.load <<YAML
---
type: Light
id: b264602f-365b-48a2-9d25-9b95055a2c34
position:
  x: 0.0
  y: 0.0
YAML

TRIGGER_NODE = JSON.parse <<JSON
{
  "type": "Trigger",
  "id": "3e8e612d-3b7a-4c6d-a2ea-2e5f1a00161d",
  "position": {
    "x": 0,
    "y": 0
  },
  "toggle": false,
  "state": false
}
JSON

INPUT_NODE = JSON.parse <<JSON
{
  "type": "Input",
  "id": "3e8e612d-3b7a-4c6d-a2ea-2e5f1a00161d",
  "position": {
    "x": 0,
    "y": 0
  },
  "exposedPosition": {
    "x": 0,
    "y": 0
  },
  "name": "input"
}
JSON

SUBPATCH_NODE = JSON.parse <<JSON
{
  "type": "Patch",
  "id": "0fe72e0e-2616-4366-8036-f852398d1c73",
  "position": {
    "x": -33.04297,
    "y": -44.77734
  },
  "subPatch": {
    "id": "0e096166-2c2d-4c0e-bce3-f9c5f42ce5c5",
    "pan": {
      "x": 0,
      "y": 0
    },
    "zoom": 1,
    "nodes": [],
    "wires": []
  }
}
JSON

CLOCK_NODE = JSON.parse(File.read('clock.json'))
INTERLACE_NODE = JSON.parse(File.read('interlace-deinterlace.audulus'))['patch']['nodes'][0]
DEINTERLACE_NODE = JSON.parse(File.read('interlace-deinterlace.audulus'))['patch']['nodes'][1]
VIA_NODE = JSON.parse(File.read('via.audulus'))['patch']['nodes'][0]
