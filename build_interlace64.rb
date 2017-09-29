require_relative 'audulus'

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
  add_nodes(patch, input_nodes)

  mux_nodes =
    8.times.map {|i|
      node = build_mux_node
      move_node(node, 100, i*50*8)
      node
    }
  add_nodes(patch, mux_nodes)

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

if __FILE__ == $0
  require 'json'
  File.write('interlace64.audulus', JSON.generate(build_interlace_grid_node))
end
