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

class Patch
  def self.build_patch(samples, title1, title2)
    doc = build_init_doc
    patch = doc['patch']

    title1_node = build_text_node(title1)
    move_node(title1_node, -700, 300)
    expose_node(title1_node, -10, -30)

    add_node(patch, title1_node)

    title2_node = build_text_node(title2)
    move_node(title2_node, -700, 250)
    expose_node(title2_node, -10, -45)

    add_node(patch, title2_node)

    o_input_node = build_input_node
    o_input_node['name'] = ''
    move_node(o_input_node, -700, 0)
    expose_node(o_input_node, 0, 0)
    add_node(patch, o_input_node)

    o2hz_node = build_o2hz_node
    move_node(o2hz_node, -700, -100)
    add_node(patch, o2hz_node)

    wire_output_to_input(patch, o_input_node, 0, o2hz_node, 0)

    hertz_node = build_expr_node('clamp(hz, 0.0001, 12000)')
    move_node(hertz_node, -700, -200)
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
    sample_sets = frequencies.map {|frequency|
      Resample.resample_for_fundamental(44100, frequency, samples)
    }

    normalization_factor = 1.0 / sample_sets.flatten.map(&:abs).max

    normalized_sample_sets = sample_sets.map {|sample_set|
      sample_set.map {|sample| sample*normalization_factor}
    }

    spline_nodes =
      normalized_sample_sets.each_with_index.map {|samples, i|
        spline_node = build_simple_node("Spline")
        spline_node["controlPoints"] = samples.each_with_index.map {|sample, i|
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

    range_scale_node = build_expr_node('x*2-1')
    move_node(range_scale_node, 600, 0)
    add_node(patch, range_scale_node)

    wire_output_to_input(patch, mux_node, 0, range_scale_node, 0)

    output_node = build_output_node
    output_node['name'] = ''
    move_node(output_node, 1100, 0)
    expose_node(output_node, 50, 0)
    add_node(patch, output_node)

    wire_output_to_input(patch, range_scale_node, 0, output_node, 0)

    doc
  end

  XMUX_NODE = JSON.parse(File.read('xmux.audulus'))['patch']['nodes'][0]
  def self.build_xmux_node
    clone_node(XMUX_NODE)
  end

  O2HZ_NODE = JSON.parse(File.read('o2Hz.audulus'))['patch']['nodes'][0]
  def self.build_o2hz_node
    clone_node(O2HZ_NODE)
  end
end

class Resample
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
