require_relative 'audulus'

# input 0: gate
# input 1-8: neighbors
# input 9: button
def build_conway_node
  print "building conway node.."
  result = clone_node(CONWAY_PATCH)
  puts "done."
  result
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

  # INTERLACE NODE
  interlace = build_interlace64_node
  move_node(interlace, light_nodes.last['position']['x'] + 100, 0)
  add_node(patch, interlace)

  conway_nodes.each_with_index do |conway_node, i|
    wire_output_to_input(patch, conway_node, 0, interlace, i)
  end

  # OUTPUT NODE
  output = build_output_node
  move_node(output, interlace['position']['x'] + 200, 0)
  add_node(patch, output)

  wire_output_to_input(patch, interlace, 0, output, 0)

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

def build_interlace64_node
  clone_node(INTERLACE64_NODE)
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


CONWAY_PATCH = JSON.parse(File.read('conway_node.audulus'))['patch']['nodes'][0]

CLOCK_NODE = JSON.parse(File.read('clock.json'))
INTERLACE_NODE = JSON.parse(File.read('interlace-deinterlace.audulus'))['patch']['nodes'][0]
DEINTERLACE_NODE = JSON.parse(File.read('interlace-deinterlace.audulus'))['patch']['nodes'][1]
INTERLACE64_NODE = JSON.parse(File.read('interlace-64.audulus'))['patch']['nodes'][0]
