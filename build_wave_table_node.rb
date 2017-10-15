require_relative 'audulus'

class Wav
  def self.load_samples(io)
    header = load_header(io)
    load_chunks(header, io)[0][:samples]
  end

  def self.load_header(io)
    base_keys = %w(master_chunk_id master_chunk_size wave_id format_chunk_id format_chunk_size)
    base_values = io.read(20).unpack("A4L<A4A4L<")
    base_header = Hash[base_keys.map(&:to_sym).zip(base_values)]
    format_header =
      case base_header[:format_chunk_size]
        when 16
          format_keys = %w(format number_of_channels samples_per_second average_bytes_per_second block_align bits_per_sample)
          format_values = io.read(16).unpack("S<S<L<L<S<S<")
          Hash[format_keys.map(&:to_sym).zip(format_values)]
        else
          raise "not supported"
      end

    base_header.merge(format_header)
  #  %w(number_of_channels samples_per_second average_bytes_per_second block_align bits_per_sample
  #      extension_size valid_bits_per_sample channel_mask subformat).map(&:to_sym)
  #  header = io.read(60).unpack("A4L<A4A4L<S<S<L<L<S<S<S<S<L<A16")
  #  Hash[keys.zip(header)]
  end

  def self.load_chunks(header, io)
    chunks = []
    while !io.eof?
      chunk_id = io.read(4)
      case chunk_id
      when "data"
        chunks << read_data_chunk(header, io)
      when "fact"
        read_fact_chunk(header, io)
      end
    end

    chunks
  end

  def self.read_data_chunk(header, io)
    size = io.read(4).unpack("L<")[0]
    p header
    sample_count = size / header[:block_align]
    samples = sample_count.times.map {
      sample = io.read(header[:block_align]).unpack("S<")[0]
    }
    data = io.read(size)
    { :type => "data",
      :samples => samples }
  end

  def self.scale_samples(samples_16_bit)
    samples_16_bit.map {|sample|
      (sample.to_f / 0x7FFF.to_f) - 1.0
    }
  end
end

class Patch
  def self.build_patch(samples)
    doc = build_init_doc
    patch = doc['patch']

    hertz_node = build_input_node
    hertz_node['name'] = 'hz'
    move_node(hertz_node, -700, 0)
    add_node(patch, hertz_node)

    phaser_node = build_simple_node('Phasor')
    move_node(phaser_node, -500, 0)
    add_node(patch, phaser_node)

    wire_output_to_input(patch, hertz_node, 0, phaser_node, 0)

    scaler_node = build_simple_node('Expr')
    scaler_node['expr'] = "t/2/pi*#{samples.count.to_f - 0.001}"
    move_node(scaler_node, -300, 0)
    add_node(patch, scaler_node)

    wire_output_to_input(patch, phaser_node, 0, scaler_node, 0)

    expression_nodes =
      samples.each_with_index.map {|sample, i|
        node = build_simple_node('Expr')
        node['expr'] = sample.to_s
        move_node(node, 0, i*50)
        node
      }
    add_nodes(patch, expression_nodes)

    mux_count = (samples.count.to_f / 64.0).ceil
    mux_nodes =
      mux_count.times.map {|i|
        node = build_mux64_node
        move_node(node, 300, i*50*64)
        node
      }
    add_nodes(patch, mux_nodes)

    mux_nodes.zip(expression_nodes.each_slice(64)) do |mux_node, slice|
      slice.each_with_index do |expression_node, i|
        wire_output_to_input(patch, expression_node, 0, mux_node, i+1)
      end

      wire_output_to_input(patch, scaler_node, 0, mux_node, 0)
    end

    output_multiplexer_node = build_mux64_node
    move_node(output_multiplexer_node, 600, 0)
    add_node(patch, output_multiplexer_node)

    mux_nodes.each_with_index do |mux_node, i|
      wire_output_to_input(patch, mux_node, 0, output_multiplexer_node, i+1)
    end

    selector_node = build_simple_node('Expr')
    selector_node['expr'] = 'x/64'
    move_node(selector_node, 0, -100)
    add_node(patch, selector_node)

    wire_output_to_input(patch, scaler_node, 0, selector_node, 0)
    wire_output_to_input(patch, selector_node, 0, output_multiplexer_node, 0)

    filter_node = build_simple_node("Filter")
    filter_node['res'] = 0
    move_node(filter_node, 900, 0)
    add_node(patch, filter_node)

    output_node = build_output_node
    move_node(output_node, 1100, 0)
    expose_node(output_node, 100, 0)
    add_node(patch, output_node)

    hertz_2_node = build_simple_node("Expr")
    hertz_2_node['expr'] = 'x*2'
    move_node(hertz_2_node, 700, -100)
    add_node(patch, hertz_2_node)

    wire_output_to_input(patch, hertz_node, 0, hertz_2_node, 0)
    wire_output_to_input(patch, hertz_2_node, 0, filter_node, 1)

    wire_output_to_input(patch, output_multiplexer_node, 0, filter_node, 0)
    wire_output_to_input(patch, filter_node, 0, output_node, 0)

    doc
  end

  MUX64_NODE = JSON.parse(File.read('mux64.audulus'))['patch']['nodes'][0]
  def self.build_mux64_node
    clone_node(MUX64_NODE)
  end
end

if __FILE__ == $0
  require 'json'
  samples =
    File.open(ARGV[0]) do |file|
      Wav.scale_samples(Wav.load_samples(file))
    end
#  samples = 256.times.map {|i|
#    x = i.to_f/255.0*2*Math::PI
#    Math.sin(x)
#  }
  File.write('wavetable.audulus', JSON.generate(make_subpatch(Patch.build_patch(samples)['patch'])))
end
