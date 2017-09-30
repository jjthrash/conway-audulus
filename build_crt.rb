require_relative 'audulus'

def build_crt_node
  doc = build_init_doc
  patch = doc['patch']

  light_nodes =
    64.times.map {|i|
      result = build_light_node
      move_node(result, (i % 8) * 100, (8 - i/8) * 50)
      expose_node(result, (i % 8) * 10, (8 - i/8) * 10)
    }
  add_nodes(patch, light_nodes)

  deinterlace_node = clone_node(JSON.parse(File.read('deinterlace-64.audulus'))['patch']['nodes'][0])
  move_node(deinterlace_node, -200, 0)
  add_node(patch, deinterlace_node)

  light_nodes.each_with_index do |light_node, i|
    wire_output_to_input(patch, deinterlace_node, i, light_node, 0)
  end

  input_node = build_input_node
  move_node(input_node, -400, 0)
  expose_node(input_node, 0, -10)
  add_node(patch, input_node)

  wire_output_to_input(patch, input_node, 0, deinterlace_node, 0)

  patch
end

def build_crt_patch
  doc = build_init_doc
  patch = doc['patch']

  subpatch = build_subpatch_node
  subpatch['subPatch'] = build_crt_node
  add_node(patch, subpatch)

  doc
end

if __FILE__ == $0
  require 'json'
  File.write('crt.audulus', JSON.generate(build_crt_patch))
end
