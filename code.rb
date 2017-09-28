require 'json'
require 'yaml'

#patch = JSON.parse(IO.read("Conway.audulus"))

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

def build_init_doc
  print "building init doc.."
  result = clone_node(INIT_PATCH)
  puts "done."
  result
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

def build_input_node
  clone_node(INPUT_NODE)
end

def add_node(patch, node)
  patch['nodes'] << node
  patch
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
        node['position']['x'] = column * 160
      end
      nodes.each do |node|
        node['position']['y'] = (height - row) * conway_node_height
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
        node['position']['x'] = width * -trigger_node_width - 100 + trigger_node_width * column
        node['exposedPosition'] = {}
        node['exposedPosition']['x'] = column * 35
      end
      nodes.each do |node|
        node['position']['y'] = (height - row) * trigger_node_height
        node['exposedPosition']['y'] = 35*(height - row)
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
      nodes =
        width.times.map {|column|
          build_light_node
        }

      nodes.each_with_index do |node, column|
        node['position']['x'] = width * conway_node_width + 100 + light_node_width * column
        node['exposedPosition'] = {}
        node['exposedPosition']['x'] = column * 35
      end
      nodes.each do |node|
        node['position']['y'] = (height - row) * light_node_height
        node['exposedPosition']['y'] = 35*(height - row)
      end
    }

  light_nodes.each do |node|
    add_node(patch, node)
  end

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

"""
Notes:

- when wiring inputs to outputs, the wire connects patches together, then specifies which numbered input or output,
  presumably based on order of appearance
"""

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


CONWAY_PATCH = JSON.parse(File.read('Conway.audulus'))['patch']['nodes'][0]

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
