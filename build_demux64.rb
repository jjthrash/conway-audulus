require_relative 'audulus'

def build_demux64_patch
  doc = build_init_doc
  patch = doc['patch']

  output_nodes =
    64.times.map {|i|
      node = build_output_node
      node['name'] = ''
      move_node(node, 0, i*50)
      expose_node(node, (i%8)*20, (8-i/8)*20)
      node
    }
  add_nodes(patch, output_nodes)

  demux_nodes =
    8.times.map {|i|
      node = build_demux_node
      move_node(node, -200, i*8*50)
      node
    }
  add_nodes(patch, demux_nodes)

  demux_nodes.zip(output_nodes.each_slice(8)) do |demux_node, slice|
    slice.each_with_index do |output_node, i|
      wire_output_to_input(patch, demux_node, i, output_node, 0)
    end
  end

  top_demux_node = build_demux_node
  move_node(top_demux_node, -400, 0)
  add_node(patch, top_demux_node)

  demux_nodes.each_with_index do |demux_node, i|
    wire_output_to_input(patch, top_demux_node, i, demux_node, 1)
  end

  divider = build_simple_node('Expr')
  divider['expr'] = 'x/8'
  move_node(divider, -600, 0)
  add_node(patch, divider)

  wire_output_to_input(patch, divider, 0, top_demux_node, 0)

  selector = build_input_node
  selector['name'] = 'sel'
  move_node(selector, -800, 0)
  expose_node(selector, 0, -20)
  add_node(patch, selector)

  wire_output_to_input(patch, selector, 0, divider, 0)

  demux_nodes.each do |demux_node|
    wire_output_to_input(patch, selector, 0, demux_node, 0)
  end

  input = build_input_node
  move_node(input, -800, 50)
  expose_node(input, 0, -40)
  add_node(patch, input)

  wire_output_to_input(patch, input, 0, top_demux_node, 1)

  doc
end

if __FILE__ == $0
  require 'json'
  File.write('demux64.audulus', JSON.generate(make_subpatch(build_demux64_patch['patch'])))
end
