"""
The following code builds an Audulus wavetable node given a single cycle waveform.

The way it works is by building a spline node corresponding to the waveform, then
building the support patch to drive a Phasor node at the desired frequency into the
spline node to generate the output.

The complexity in the patch comes from the fact that for any wavetable you will
quickly reach a point where you are generating harmonics that are beyond the Nyquist
limit. Without diving into details, the problem with this is that it will cause
aliasing, or frequencies that are not actually part of the underlying waveform.
These usually sound bad and one usually doesn't want them.

The solution is as follows (glossing over important details):
1. determine a set of frequency bands we care about. In my case, 0-55Hz, and up by
   octaves for 8 octaves
2. for each frequency band, run the waveform through a Fast Fourier Transform
3. attenuate frequencies higher than the Nyquist limit for that frequency band
4. run an inverse FFT to get a new waveform
5. generate a wavetable for each frequency band
6. generate support patch to make sure the right wavetable is chosen for a given
   frequency

Steps 2–4 behave like a very precise single-pole non-resonant low-pass-filter, and
I probably could have used that, but this approach was more direct.
"""


require 'json'

# Load the library for building Audulus patches programmatically.
require_relative 'audulus'

class Sox
  # load the WAV file at `path` and turn it into a list of samples,
  # -1 to 1 in value
  def self.load_samples(path)
    `sox "#{path}" -t dat -`.
      lines.
      reject {|l| l.start_with?(';')}.
      map(&:strip).
      map(&:split).
      map(&:last).
      map(&:to_f)
  end
end

class Patch
  # Take a list of samples corresponding to a single cycle wave form
  # and generate an Audulus patch with a single wavetable node that
  # has title1 and title2 as title and subtitle
  def self.build_patch(samples, title1, title2)
    # The below code lays out the Audulus nodes as needed to build
    # the patch. It should mostly be familiar to anyone who's built
    # an Audulus patch by hand.
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

    # for each frequency band, resample using the method outlined above
    frequencies = (0..7).map {|i| 55*2**i}
    sample_sets = frequencies.map {|frequency|
      Resample.resample_for_fundamental(44100, frequency, samples)
    }

    # normalize the samples
    normalization_factor = 1.0 / sample_sets.flatten.map(&:abs).max
    normalized_sample_sets = sample_sets.map {|sample_set|
      sample_set.map {|sample| sample*normalization_factor}
    }

    # generate the actual spline nodes corresponding to each wavetable
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

    # generate the "picker," the node that determines which wavetable
    # to used based on the desired output frequency
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
        scale_partial(i, sub_nyquist_sample_count, power)
      else
        0+0i
      end
    }
  end

  # dampen partials higher than a certain frequency using a smooth
  # "ease-in-out" shape
  def self.scale_partial(partial_index, partial_count, partial_value)
    partial_value * (Math.cos(partial_index.to_f*Math::PI/2/partial_count)**2)
  end
end

# Given a path to a single-cycle-waveform wav file, generate an Audulus wavetable
# node
def build_patch_from_wav_file(path)
  # break the path into directory and path so we can build the audulus file's name
  parent, file = path.split("/")[-2..-1]

  # load the samples from the WAV file
  samples = Sox.load_samples(path)

  # build the audulus patch name from the WAV file name
  basename = File.basename(file, ".wav")
  puts "building #{basename}.audulus"
  audulus_patch_name = "#{basename}.audulus"

  # build the patch as a full patch
  base_patch = Patch.build_patch(samples, parent, basename)['patch']

  # wrap it up as a subpatch
  final_patch = make_subpatch(base_patch)

  # write the patch to a file as JSON (the format Audulus uses)
  File.write(audulus_patch_name, JSON.generate(final_patch))
end

# Make a set of random samples. Useful for generating a cyclic
# noise wavetable. This method would be used in place of loading
# the WAV file.
def make_random_samples(count)
  count.times.map {
    rand*2-1
  }
end

# Make a set of samples conforming to a parabola. This method would
# be used in place of loading the WAV file.
def make_parabolic_samples(count)
  f = ->(x) { -4*x**2 + 4*x }
  count.times.map {|index|
    index.to_f / (count-1)
  }.map(&f).map {|sample|
    sample*2-1
  }
end

# Given a set of samples, build the Audulus wavetable node
def build_patch_from_samples(samples, title1, title2, output_path)
  puts "building #{output_path}"
  File.write(output_path, JSON.generate(make_subpatch(Patch.build_patch(samples, title1, title2)['patch'])))
end

# This code is the starting point.. if we run this file as
# its own program, do the following
if __FILE__ == $0
  path = ARGV[0]
  build_patch_from_wav_file(path)
end
