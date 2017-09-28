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

# gate output is output 0
def build_clock_node
  clone_node(CLOCK_NODE)
end

def add_node(patch, node)
  patch['nodes'] << node
  patch
end

def build_conway_patch(width, height)
  doc = build_init_doc()
  patch = doc['patch']

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
      end
      nodes.each do |node|
        node['position']['y'] = (height - row) * light_node_height
      end
    }

  light_nodes.each do |node|
    add_node(patch, node)
  end

  conway_nodes.zip(light_nodes) do |conway_node, light_node|
    wire_output_to_input(patch, conway_node, 0, light_node, 0)
  end

  clock = build_clock_node
  add_node(patch, clock)
  conway_nodes.each do |node|
    wire_output_to_input(patch, clock, 0, node, 0)
  end

  doc
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
  NEIGHBOR_POSITIONS.map {|relative_column, relative_row|
    neighbor_row = row + relative_row
    neighbor_column = column + relative_column
    if neighbor_row < 0 || neighbor_row >= conway_nodes.count / stride ||
        neighbor_column < 0 || neighbor_column >= stride
      next nil
    end

    conway_nodes[neighbor_column + neighbor_row * stride]
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

CLOCK_NODE = JSON.parse(File.read('clock.json'))
