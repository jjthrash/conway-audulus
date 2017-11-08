require_relative 'audulus'

class Sox
  def self.load_samples(path)
    `sox #{path} -t dat -`.
      lines.
      reject {|l| l.start_with?(';')}.
      map(&:strip).
      map(&:split).
      map(&:last).
      map(&:to_f)
  end
end

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

    hertz_input_node = build_input_node
    hertz_input_node['name'] = 'hz'
    move_node(hertz_input_node, -700, 0)
    add_node(patch, hertz_input_node)

    hertz_node = build_expr_node('clamp(hz, 0.0001, 12000)')
    move_node(hertz_node, -700, -100)
    add_node(patch, hertz_node)

    wire_output_to_input(patch, o2hz_node, 0, hertz_node, 0)

    phaser_node = build_simple_node('Phasor')
    move_node(phaser_node, -500, 0)
    add_node(patch, phaser_node)

    wire_output_to_input(patch, hertz_node, 0, phaser_node, 0)

    domain_scale_node = build_expr_node('x/2/pi')
    move_node(domain_scale_node, -300, 0)
    add_node(patch, domain_scale_node)

    wire_output_to_input(patch, phaser_node, 0, domain_scale_node, 0)

    frequencies = (0..7).map {|i| 55*2**i}
    spline_nodes =
      frequencies.each_with_index.map {|frequency, i|
        resampled = Resample2.resample_for_fundamental(44100, frequency, samples)
        spline_node = build_simple_node("Spline")
        spline_node["controlPoints"] = resampled.each_with_index.map {|sample, i|
          {
            "x" => i.to_f/(samples.count-1).to_f,
            "y" => (sample+1)/2,
          }
        }
        move_node(spline_node, -100, i*200)
        spline_node
      }

    add_nodes(patch, spline_nodes)

    spline_nodes.each do |spline_node|
      wire_output_to_input(patch, domain_scale_node, 0, spline_node, 0)
    end

    spline_picker_node = build_expr_node("clamp(log2(hz/55), 0, 8)")
    move_node(spline_picker_node, -100, -100)
    add_node(patch, spline_picker_node)

    mux_node = build_xmux_node
    move_node(mux_node, 400, 0)
    add_node(patch, mux_node)

    spline_nodes.each_with_index do |spline_node, i|
      wire_output_to_input(patch, spline_node, 0, mux_node, i+1)
    end

    wire_output_to_input(patch, hertz_node, 0, spline_picker_node, 0)
    wire_output_to_input(patch, spline_picker_node, 0, mux_node, 0)

    range_scale_node = build_simple_node("Expr")
    range_scale_node['expr'] = 'x*2-1'
    move_node(range_scale_node, 600, 0)
    add_node(patch, range_scale_node)

    wire_output_to_input(patch, mux_node, 0, range_scale_node, 0)

    output_node = build_output_node
    move_node(output_node, 1100, 0)
    expose_node(output_node, 100, 0)
    add_node(patch, output_node)

    wire_output_to_input(patch, range_scale_node, 0, output_node, 0)

    doc
  end

  MUX64_NODE = JSON.parse(File.read('mux64.audulus'))['patch']['nodes'][0]
  def self.build_mux64_node
    clone_node(MUX64_NODE)
  end

  XMUX_NODE = JSON.parse(File.read('xmux.audulus'))['patch']['nodes'][0]
  def self.build_xmux_node
    clone_node(XMUX_NODE)
  end
end

class Resample
  def initialize(samples)
    @samples = samples
  end

  def self.resample(new_count, samples)
    resampler = Resample.new(samples)
    new_count.times.map {|i|
      resampler.interpolate(calculate_x(samples.count, new_count, i))
    }
  end

  def self.calculate_x(original_count, new_count, i)
    i.to_f * original_count.to_f / new_count.to_f
  end

  def interpolate(x)
    k = x.floor
    t = (x - x(k))/(x(k+1) - x(k))
    h00(t)*p(k) + h10(t)*m(k) + h01(t)*p(k+1) + h11(t)*m(k+1)
  end

  def x(k)
    k.to_f
  end

  def p(k)
    @samples[k]
  end

  def m(k)
    slopes(k)
  end

  def slopes(k)
    @slopes ||= build_slopes
    @slopes[k]
  end

  def build_slopes
    two_point_slopes = @samples[0..-2].zip(@samples[1..-1]).map {|p1, p2|
      p2 - p1
    }
    three_point_slopes = two_point_slopes[0..-2].zip(two_point_slopes[1..-1]).map {|s1, s2|
      (s1+s2)/2.0
    }
    two_point_slopes[0,1] +
      three_point_slopes +
      two_point_slopes[-1,1]
  end

  def h00(t)
    2*(t**3) - 3*(t**2) + 1
  end

  def h01(t)
    t**3 - 2*t**2 + t
  end

  def h10(t)
    -2*t**3 + 3*t**2
  end

  def h11(t)
    t**3 - t**2
  end
end

class Resample2
  require 'fftw3'
  # sample_rate, Hz, e.g. 44100
  # fundamental, Hz, e.g. 440
  # samples: -1..1
  def self.resample_for_fundamental(sample_rate, fundamental, samples)
    fft = FFTW3.fft(NArray[samples]).to_a.flatten
    dampened = dampen_higher_partials(sample_rate, fundamental, fft)
    (FFTW3.ifft(NArray[dampened]) / samples.count).real.to_a.flatten
  end

  # kill everything higher than a scaled nyquist limit
  # ease in/out everything else to minimize partials near nyquist
  def self.dampen_higher_partials(sample_rate, fundamental, fft)
    nyquist = sample_rate.to_f / 2
    sample_fundamental = sample_rate.to_f / fft.count
    scaled_nyquist = nyquist / fundamental * sample_fundamental
    sample_duration = fft.count.to_f / sample_rate
    sub_nyquist_sample_count = scaled_nyquist * sample_duration
    fft.each_with_index.map {|power, i|
      hz = i.to_f / fft.count * sample_rate.to_f
      if hz < scaled_nyquist
        power * (Math.cos(i*Math::PI/2/sub_nyquist_sample_count)**2)
      else
        0+0i
      end
    }
  end
end

if __FILE__ == $0
  require 'json'
  path = ARGV[0]
  parent, file = path.split("/")[-2..-1]
  samples = Sox.load_samples(path)
  basename = File.basename(file, ".wav")
  puts "building #{basename}.audulus"
  File.write("#{basename}.audulus", JSON.generate(make_subpatch(Patch.build_patch(samples, parent, basename)['patch'])))
end
