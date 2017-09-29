require_relative 'audulus'

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

if __FILE__ == $0
  require 'json'
  File.write('deinterlace64.audulus', JSON.generate(build_deinterlace_grid_node))
end
