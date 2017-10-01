require_relative 'audulus'

def build_deinterlace_node(rows, columns)
  doc = build_init_doc
  patch = doc['patch']
  output_nodes =
    1024.times.map {|i|
      node = build_output_node
      node['name'] = ''
      move_node(node, 0, i*100)
      expose_node(node, (i % columns) * 20, 20*columns - (i / columns) * 20)
      node
    }
  add_nodes(patch, output_nodes)

  sh_nodes =
    1024.times.map {|i|
      node = build_sample_and_hold_node
      move_node(node, -200, i*100)
      node
    }

  sh_nodes.zip(output_nodes) do |sh_node, output_node|
    wire_output_to_input(patch, sh_node, 0, output_node, 0)
  end
  add_nodes(patch, sh_nodes)

  signal_demux_nodes =
    16.times.map {|i|
      node = build_demux64_node
      move_node(node, -400, i*64*100)
      node
    }
  add_nodes(patch, signal_demux_nodes)

  gate_demux_nodes =
    16.times.map {|i|
      node = build_demux64_node
      move_node(node, -600, i*64*100+ 100)
      node
    }
  add_nodes(patch, gate_demux_nodes)

  signal_demux_nodes.zip(gate_demux_nodes, sh_nodes.each_slice(64)) do |signal_demux_node, gate_demux_node, sh_slice|
    sh_slice.each_with_index do |sh_node, i|
      wire_output_to_input(patch, signal_demux_node, i, sh_node, 0)
      wire_output_to_input(patch, gate_demux_node, i, sh_node, 1)
    end
  end

  top_signal_demux_node = build_demux64_node
  move_node(top_signal_demux_node, -800, 200)
  add_node(patch, top_signal_demux_node)

  top_gate_demux_node = build_demux64_node
  move_node(top_gate_demux_node, -1000, 300)
  add_node(patch, top_gate_demux_node)

  signal_demux_nodes.each_slice(64) do |slice|
    slice.each_with_index do |node, i|
      wire_output_to_input(patch, top_signal_demux_node, i, node, 1)
    end
  end

  gate_demux_nodes.each_slice(64) do |slice|
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
  divider['expr'] = "x/64"
  move_node(divider, -1400, 100)
  add_node(patch, divider)

  wire_output_to_input(patch, divider, 0, divided_clock_via, 0)

  signal_via = build_via_node
  move_node(signal_via, -1200, 150)
  add_node(patch, signal_via)

  stereo_to_mono = build_simple_node('QuadToMono')
  move_node(stereo_to_mono, -1600, 150)
  add_node(patch, stereo_to_mono)

  wire_output_to_input(patch, stereo_to_mono, 1, signal_via, 0)
  wire_output_to_input(patch, stereo_to_mono, 0, divider, 0)
  wire_output_to_input(patch, stereo_to_mono, 0, clock_via, 0)

  (signal_demux_nodes + gate_demux_nodes).each do |node|
    wire_output_to_input(patch, clock_via, 0, node, 0)
  end

  wire_output_to_input(patch, pulse_via, 0, top_gate_demux_node, 1)
  wire_output_to_input(patch, divided_clock_via, 0, top_gate_demux_node, 0)
  wire_output_to_input(patch, divided_clock_via, 0, top_signal_demux_node, 0)
  wire_output_to_input(patch, signal_via, 0, top_signal_demux_node, 1)

  pulse_if_changed_node = build_pulse_if_changed_node
  move_node(pulse_if_changed_node, -1400, 0)
  add_node(patch, pulse_if_changed_node)

  wire_output_to_input(patch, stereo_to_mono, 0, pulse_if_changed_node, 0)
  wire_output_to_input(patch,  pulse_if_changed_node, 0, pulse_via, 0)

  input_node = build_input_node
  move_node(input_node, -1800, 150)
  expose_node(input_node, 0, 0)
  add_node(patch, input_node)

  wire_output_to_input(patch, input_node, 0, stereo_to_mono, 0)

  doc
end

DEMUX64_NODE = JSON.parse(File.read('demux64.audulus'))['patch']['nodes'][0]
def build_demux64_node
  clone_node(DEMUX64_NODE)
end

PULSE_IF_CHANGED_NODE = JSON.parse(File.read('pulse-if-changed.audulus'))['patch']['nodes'][0]
def build_pulse_if_changed_node
  clone_node(PULSE_IF_CHANGED_NODE)
end

if __FILE__ == $0
  require 'json'
  File.write('deinterlace-1024.audulus', JSON.generate(make_subpatch(build_deinterlace_node(32, 32)['patch'])))
end

