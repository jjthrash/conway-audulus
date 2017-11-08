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

def wire_output_to_input(patch, source_node, source_output, destination_node, destination_input)
  patch['wires'] << {
    "from" => source_node['id'],
    "output" => source_output,
    "to" => destination_node['id'],
    "input": destination_input
  }
end

def build_init_doc
  result = clone_node(INIT_PATCH)
  result
end

def make_subpatch(subpatch)
  doc = build_init_doc
  patch = doc['patch']

  subpatch_node = build_subpatch_node
  subpatch_node['subPatch'] = subpatch
  add_node(patch, subpatch_node)
  doc
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

def build_knob_node
  result = build_simple_node("Knob")
  result['knob'] = {
    'value' => 0.5,
    'min' => 0.0,
    'max' => 1.0,
  }
  expose_node(result, 0, 0)
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

def build_expr_node(expr)
  result = build_simple_node('Expr')
  result['expr'] = expr
  result
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
VIA_NODE = JSON.parse(File.read('via.audulus'))['patch']['nodes'][0]
