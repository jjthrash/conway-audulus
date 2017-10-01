require_relative 'audulus'

def build_mux64_patch
  doc = build_init_doc
  patch = doc['patch']

  selector_input = build_input_node
  selector_input['name'] = 'sel'
  move_node(selector_input, -100, 0)
  add_node(patch, selector_input)

  input_nodes =
    64.times.map {|i|
      node = build_input_node
      node['name'] = ''
      move_node(node, 0, i*50)
      expose_node(node, (i%8)*20, (8-i/8)*20)
      node
    }
  add_nodes(patch, input_nodes)

  mux_nodes =
    8.times.map {|i|
      node = build_mux_node
      move_node(node, 100, i*8*50)
      node
    }
  add_nodes(patch, mux_nodes)

  mux_nodes.zip(input_nodes.each_slice(8)) do |mux_node, slice|
    slice.each_with_index do |input_node, i|
      wire_output_to_input(patch, input_node, 0, mux_node, i+1)
    end
  end

  final_mux_node = build_mux_node
  move_node(final_mux_node, 300, 0)
  add_node(patch, final_mux_node)

  mux_nodes.each_with_index do |mux_node, i|
    wire_output_to_input(patch, mux_node, 0, final_mux_node, i+1)
  end

  mod_8 = build_simple_node('Expr')
  mod_8['expr'] = 'mod(s, 8)'
  move_node(mod_8, 0, -50)
  add_node(patch, mod_8)

  wire_output_to_input(patch, selector_input, 0, mod_8, 0)

  mux_nodes.each do |mux_node|
    wire_output_to_input(patch, mod_8, 0, mux_node, 0)
  end

  divide_8 = build_simple_node('Expr')
  divide_8['expr'] = 's/8'
  move_node(divide_8, 0, -100)
  add_node(patch, divide_8)

  wire_output_to_input(patch, selector_input, 0, divide_8, 0)

  wire_output_to_input(patch, divide_8, 0, final_mux_node, 0)

  output_node = build_output_node
  output_node['name'] = ''
  move_node(output_node, 500, 0)
  expose_node(output_node, 160, -20)
  add_node(patch, output_node)

  wire_output_to_input(patch, final_mux_node, 0, output_node, 0)

  doc
end

if __FILE__ == $0
  require 'json'
  File.write('mux64.audulus', JSON.generate(make_subpatch(build_mux64_patch['patch'])))
end
