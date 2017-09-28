require 'json'
require 'yaml'

#patch = JSON.parse(IO.read("Conway.audulus"))

require 'securerandom'

def uuid?(string)
  string.kind_of?(String) && /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/ =~ string
end

# Node -> [ UUID ]
def scan_uuids(node)
  case node
  when Hash
    node.map {|key, elem|
      if uuid?(elem)
        elem
      else
        scan_uuids(elem)
      end
    }.flatten
  when Array
    node.map {|elem| scan_uuids(elem)}.flatten
  else
    []
  end
end

def build_uuid_map(node)
  existing_uuids = scan_uuids(node)
  existing_uuids.reduce({}) {|h, uuid|
    h[uuid] = SecureRandom.uuid()
    h
  }
end

def clone_node(node)
  uuid_map = build_uuid_map(node)
  clone_node_helper(node, uuid_map)
end

def clone_node_helper(node, uuid_map)
  case node
  when Hash
    Hash[node.map {|key, elem|
      if uuid?(elem)
        [key, uuid_map[elem]]
      else
        [key, clone_node_helper(elem, uuid_map)]
      end
    }]
  when Array
    node.map {|elem|
      clone_node_helper(elem, uuid_map)
    }
  else
    node
  end
end

def build_init_doc
  print "building init doc.."
  result = clone_node(INIT_PATCH)
  puts "done."
  result
end

def build_conway_node
  print "building conway node.."
  result = clone_node(CONWAY_PATCH)
  puts "done."
  result
end

def build_light_node
  clone_node(LIGHT_NODE)
end

def add_node(patch, node)
  patch['nodes'] << node
  patch
end

def build_conway_patch(m, n)
  doc = build_init_doc()
  patch = doc['patch']

  conway_nodes =
    n.times.flat_map {|row|
      print "building row #{row}.."
      nodes =
        m.times.map {|column| # columns
          build_conway_node()
        }

      nodes.each_with_index do |node, column|
        node['position']['x'] = column * 160
      end
      nodes.each do |node|
        node['position']['y'] = row * 170
      end

      puts "done."
      nodes
    }

  print "adding (#{conway_nodes.count}) nodes"
  conway_nodes.each do |node|
    print "."
    add_node(patch, node)
  end

  doc
end

"""
Notes:

- when wiring inputs to outputs, the wire connects patches together, then specifies which numbered input or output,
  presumably based on order of appearance
"""

INIT_PATCH = YAML.load <<YAML
---
version: 1
patch:
  id: 2aedc73c-4095-4d1b-ab1b-2121ea9ac19d
  pan:
    x: 0.0
    y: 0.0
  zoom: 1.0
  nodes: []
  wires: []
YAML


CONWAY_PATCH = YAML.load <<YAML
---
type: Patch
id: f53ad3ab-bf33-40dd-b9ef-713c2b108cc2
position:
  x: 14.539043426513672
  y: 5.307900428771973
subPatch:
  id: 6d958203-a5c9-45e0-8c88-3270535fee8e
  pan:
    x: -547.2945556640625
    y: -103.71400451660156
  zoom: 1.422074317932129
  nodes:
  - type: Output
    id: 7b00f4c4-e000-4555-9884-78de377b851d
    position:
      x: 646.3172607421875
      y: 40.1475715637207
    name: Output
    exposedPosition:
      x: 5.0
      y: 0.0
  - type: Input
    id: 5b5fe154-af7e-4007-b8ee-a87885030917
    position:
      x: -287.3603210449219
      y: 207.10015869140625
    name: Gate
    exposedPosition:
      x: -95.0
      y: 0.0
  - type: Input
    id: b064a8da-2852-43bf-9f9c-e3b709afffcf
    position:
      x: -454.7121276855469
      y: -132.2213134765625
    name: ''
    exposedPosition:
      x: -45.0
      y: 90.0
  - type: Input
    id: 3d4feaa7-2746-4446-8e63-6bf2c94f0cee
    position:
      x: -454.7121276855469
      y: -102.2213134765625
    name: ''
    exposedPosition:
      x: -45.0
      y: 30.0
  - type: Input
    id: 00f8bbbf-24fb-4d35-b610-ec60491268a1
    position:
      x: -454.7121276855469
      y: -72.2213134765625
    name: ''
    exposedPosition:
      x: -15.0
      y: 60.0
  - type: Input
    id: 7124decb-098a-468b-ad93-989e5bccfaf8
    position:
      x: -454.7121276855469
      y: -42.2213134765625
    name: ''
    exposedPosition:
      x: -75.0
      y: 60.0
  - type: Input
    id: 1b7a019a-c902-4b6c-8bd2-3f71c5634da1
    position:
      x: -454.7121276855469
      y: -12.2213134765625
    name: ''
    exposedPosition:
      x: -75.0
      y: 90.0
  - type: Input
    id: 6f5cc4bd-cd93-4199-8d28-63834b02e1fd
    position:
      x: -454.7121276855469
      y: 17.7786865234375
    name: ''
    exposedPosition:
      x: -75.0
      y: 30.0
  - type: Input
    id: 933d7e40-0d81-418b-a281-7bfb27b2910d
    position:
      x: -454.7121276855469
      y: 47.7786865234375
    name: ''
    exposedPosition:
      x: -15.0
      y: 30.0
  - type: Input
    id: 1d77b4d2-9a56-425e-b538-938cee883573
    position:
      x: -454.7121276855469
      y: 77.7786865234375
    name: ''
    exposedPosition:
      x: -15.0
      y: 90.0
  - type: Patch
    id: 43344530-a83c-4044-b4e9-d893f0024871
    position:
      x: -304.7121276855469
      y: -132.2213134765625
    subPatch:
      id: e3a17cf5-6aaa-4567-8d62-399546ad4ce4
      pan:
        x: 456.4017639160156
        y: 64.45499420166016
      zoom: 0.7472640872001648
      nodes:
      - type: Output
        id: 8be630ad-b6aa-41b6-bf5b-d15073af3c2b
        position:
          x: 103.424560546875
          y: -80.28302764892578
        name: Output
        exposedPosition:
          x: 63.5
          y: 20.0
      - type: Input
        id: 5e9f5156-ed81-4cc0-b350-35bbde233615
        position:
          x: -836.8306884765625
          y: 131.662841796875
        name: N
        exposedPosition:
          x: 0.0
          y: 20.0
      - type: Input
        id: 094896a6-d50c-4753-ac5e-0352bebd4485
        position:
          x: -839.4378051757812
          y: -20.97498321533203
        name: S
        exposedPosition:
          x: 0.0
          y: 50.0
      - type: Input
        id: e6a66361-0ab0-4b26-8864-ccf705186c29
        position:
          x: -833.6060180664062
          y: 28.829376220703125
        name: E
        exposedPosition:
          x: 0.0
          y: 80.0
      - type: Input
        id: bc00e303-25b7-46ba-bf9c-43dc2f266956
        position:
          x: -836.8307495117188
          y: 82.21681213378906
        name: W
        exposedPosition:
          x: 0.0
          y: 110.0
      - type: Add
        id: 1f844e25-efe3-44e2-83c2-8c7cecc38eff
        position:
          x: -644.220947265625
          y: 17.455047607421875
      - type: Add
        id: d705fd23-afdf-4183-af68-b59548a81d2e
        position:
          x: -539.8375854492188
          y: 69.81144714355469
      - type: Add
        id: fee13ba0-a7df-4cf6-b8f0-5a5cc43c6120
        position:
          x: -644.2166748046875
          y: 119.88740539550781
      - type: Input
        id: 4df4d00c-9a3d-4f66-b83f-8e2698718f2e
        position:
          x: -835.7213745117188
          y: -73.92465209960938
        name: NW
        exposedPosition:
          x: 0.0
          y: 140.0
      - type: Input
        id: 3a97abe5-c4ab-4df1-b8a5-562eac19fc0c
        position:
          x: -838.3284912109375
          y: -226.56246948242188
        name: SW
        exposedPosition:
          x: 0.0
          y: 170.0
      - type: Input
        id: c82b0ec8-8bba-464a-bbdc-e0f3c060376a
        position:
          x: -832.4967041015625
          y: -176.75811767578125
        name: SE
        exposedPosition:
          x: 0.0
          y: 200.0
      - type: Input
        id: 74e0a3e7-7e5a-4448-92e1-df02db148973
        position:
          x: -835.721435546875
          y: -123.37068176269531
        name: NE
        exposedPosition:
          x: 0.0
          y: 230.0
      - type: Add
        id: 87823f4a-0e2e-42bf-bdc3-8e2c01254f0b
        position:
          x: -544.8499755859375
          y: -130.73460388183594
      - type: Add
        id: 01d8c04b-4de3-4c1a-9b32-5b4d9915a052
        position:
          x: -649.2333984375
          y: -183.09100341796875
      - type: Add
        id: d55d1948-576b-41e6-8ec5-359e9690c653
        position:
          x: -649.2291259765625
          y: -80.65864562988281
      - type: Add
        id: 6f013208-b0f5-4f7b-9d9b-072cc944241a
        position:
          x: -420.06640625
          y: -30.768325805664062
      - type: Input
        id: 61080cfc-1996-4205-af9c-cf30827954d7
        position:
          x: -203.6483917236328
          y: 32.773406982421875
        name: Self
        exposedPosition:
          x: 0.0
          y: 260.0
      - type: Crossfade
        id: cdfa4aff-840e-4891-87a5-3d698120b9bb
        position:
          x: -90.0703125
          y: -91.5152587890625
      - type: Patch
        id: 6483fd2d-dbee-4925-b4a9-25e74b63d04d
        position:
          x: -295.4381408691406
          y: -26.846641540527344
        subPatch:
          id: 60def988-5ba4-457a-85c8-d70aee0f6571
          pan:
            x: 0.0
            y: 0.0
          zoom: 1.0
          nodes:
          - type: Input
            id: 608bbca3-3ee4-41f1-a870-440cb5d5e39e
            position:
              x: -369.0
              y: -69.0
            name: Input
            exposedPosition:
              x: 0.0
              y: 20.0
          - type: Output
            id: 70df6179-a1ae-492f-9fd5-aa1f96fd1e8b
            position:
              x: 200.0
              y: 0.0
            name: Output
            exposedPosition:
              x: 88.75
              y: 20.0
          - type: Expr
            id: c2ff5d1f-f82e-4cb8-af55-fc486715d7df
            position:
              x: -220.98858642578125
              y: -14.281244277954102
            expr: '1'
          - type: LessThan
            id: fb7719e2-9cea-4dba-a632-c4c68c7d39c5
            position:
              x: -70.98859405517578
              y: -14.281244277954102
          - type: Expr
            id: ef81ba63-7d4a-4bb2-8dec-70c05d021fca
            position:
              x: -222.1903533935547
              y: -153.83642578125
            expr: '4'
          - type: LessThan
            id: 584daa31-4010-4759-becc-2dac729c57de
            position:
              x: -72.19035339355469
              y: -183.83642578125
          - type: Mult
            id: cc44ec3e-8afe-4bd6-9f6f-83c21c027e43
            position:
              x: 96.98600769042969
              y: -59.43465805053711
          wires:
          - from: cc44ec3e-8afe-4bd6-9f6f-83c21c027e43
            output: 0
            to: 70df6179-a1ae-492f-9fd5-aa1f96fd1e8b
            input: 0
          - from: c2ff5d1f-f82e-4cb8-af55-fc486715d7df
            output: 0
            to: fb7719e2-9cea-4dba-a632-c4c68c7d39c5
            input: 0
          - from: 608bbca3-3ee4-41f1-a870-440cb5d5e39e
            output: 0
            to: fb7719e2-9cea-4dba-a632-c4c68c7d39c5
            input: 1
          - from: 608bbca3-3ee4-41f1-a870-440cb5d5e39e
            output: 0
            to: 584daa31-4010-4759-becc-2dac729c57de
            input: 0
          - from: ef81ba63-7d4a-4bb2-8dec-70c05d021fca
            output: 0
            to: 584daa31-4010-4759-becc-2dac729c57de
            input: 1
          - from: fb7719e2-9cea-4dba-a632-c4c68c7d39c5
            output: 0
            to: cc44ec3e-8afe-4bd6-9f6f-83c21c027e43
            input: 0
          - from: 584daa31-4010-4759-becc-2dac729c57de
            output: 0
            to: cc44ec3e-8afe-4bd6-9f6f-83c21c027e43
            input: 1
      - type: Patch
        id: c04b7db4-9d52-4621-b95e-0916dd7e75d8
        position:
          x: -300.909912109375
          y: -116.73434448242188
        subPatch:
          id: 86f4069d-2276-46ee-bcb6-d371de7304c0
          pan:
            x: 0.0
            y: 0.0
          zoom: 1.0
          nodes:
          - type: Input
            id: 0a03f934-fa7c-4936-b806-9096865cb920
            position:
              x: -300.0
              y: 0.0
            name: Input
            exposedPosition:
              x: 0.0
              y: 20.0
          - type: Output
            id: e8433271-cdee-48ef-adf7-3957784b843d
            position:
              x: 200.0
              y: 0.0
            name: Output
            exposedPosition:
              x: 95.0
              y: 20.0
          - type: Expr
            id: cc18aeb6-94b3-49c4-86f0-d6d094d7aa2b
            position:
              x: -220.98858642578125
              y: -14.281244277954102
            expr: '2'
          - type: LessThan
            id: 350e15be-7a2d-4f72-95e3-d84191d55e90
            position:
              x: -70.98859405517578
              y: -14.281244277954102
          - type: Expr
            id: 38e725f2-cce2-4ac2-a6e3-91f497587952
            position:
              x: -222.1903533935547
              y: -153.83642578125
            expr: '4'
          - type: LessThan
            id: 003ff242-b612-4173-9ce9-2b2ef3975f59
            position:
              x: -72.19035339355469
              y: -183.83642578125
          - type: Mult
            id: 20e86124-a6e4-4025-ab8e-33e9cb952701
            position:
              x: 96.98600769042969
              y: -59.43465805053711
          wires:
          - from: 20e86124-a6e4-4025-ab8e-33e9cb952701
            output: 0
            to: e8433271-cdee-48ef-adf7-3957784b843d
            input: 0
          - from: cc18aeb6-94b3-49c4-86f0-d6d094d7aa2b
            output: 0
            to: 350e15be-7a2d-4f72-95e3-d84191d55e90
            input: 0
          - from: 0a03f934-fa7c-4936-b806-9096865cb920
            output: 0
            to: 350e15be-7a2d-4f72-95e3-d84191d55e90
            input: 1
          - from: 0a03f934-fa7c-4936-b806-9096865cb920
            output: 0
            to: 003ff242-b612-4173-9ce9-2b2ef3975f59
            input: 0
          - from: 38e725f2-cce2-4ac2-a6e3-91f497587952
            output: 0
            to: 003ff242-b612-4173-9ce9-2b2ef3975f59
            input: 1
          - from: 350e15be-7a2d-4f72-95e3-d84191d55e90
            output: 0
            to: 20e86124-a6e4-4025-ab8e-33e9cb952701
            input: 0
          - from: 003ff242-b612-4173-9ce9-2b2ef3975f59
            output: 0
            to: 20e86124-a6e4-4025-ab8e-33e9cb952701
            input: 1
      wires:
      - from: cdfa4aff-840e-4891-87a5-3d698120b9bb
        output: 0
        to: 8be630ad-b6aa-41b6-bf5b-d15073af3c2b
        input: 0
      - from: e6a66361-0ab0-4b26-8864-ccf705186c29
        output: 0
        to: 1f844e25-efe3-44e2-83c2-8c7cecc38eff
        input: 0
      - from: 094896a6-d50c-4753-ac5e-0352bebd4485
        output: 0
        to: 1f844e25-efe3-44e2-83c2-8c7cecc38eff
        input: 1
      - from: fee13ba0-a7df-4cf6-b8f0-5a5cc43c6120
        output: 0
        to: d705fd23-afdf-4183-af68-b59548a81d2e
        input: 0
      - from: 1f844e25-efe3-44e2-83c2-8c7cecc38eff
        output: 0
        to: d705fd23-afdf-4183-af68-b59548a81d2e
        input: 1
      - from: 5e9f5156-ed81-4cc0-b350-35bbde233615
        output: 0
        to: fee13ba0-a7df-4cf6-b8f0-5a5cc43c6120
        input: 0
      - from: bc00e303-25b7-46ba-bf9c-43dc2f266956
        output: 0
        to: fee13ba0-a7df-4cf6-b8f0-5a5cc43c6120
        input: 1
      - from: d55d1948-576b-41e6-8ec5-359e9690c653
        output: 0
        to: 87823f4a-0e2e-42bf-bdc3-8e2c01254f0b
        input: 0
      - from: 01d8c04b-4de3-4c1a-9b32-5b4d9915a052
        output: 0
        to: 87823f4a-0e2e-42bf-bdc3-8e2c01254f0b
        input: 1
      - from: c82b0ec8-8bba-464a-bbdc-e0f3c060376a
        output: 0
        to: 01d8c04b-4de3-4c1a-9b32-5b4d9915a052
        input: 0
      - from: 3a97abe5-c4ab-4df1-b8a5-562eac19fc0c
        output: 0
        to: 01d8c04b-4de3-4c1a-9b32-5b4d9915a052
        input: 1
      - from: 4df4d00c-9a3d-4f66-b83f-8e2698718f2e
        output: 0
        to: d55d1948-576b-41e6-8ec5-359e9690c653
        input: 0
      - from: 74e0a3e7-7e5a-4448-92e1-df02db148973
        output: 0
        to: d55d1948-576b-41e6-8ec5-359e9690c653
        input: 1
      - from: d705fd23-afdf-4183-af68-b59548a81d2e
        output: 0
        to: 6f013208-b0f5-4f7b-9d9b-072cc944241a
        input: 0
      - from: 87823f4a-0e2e-42bf-bdc3-8e2c01254f0b
        output: 0
        to: 6f013208-b0f5-4f7b-9d9b-072cc944241a
        input: 1
      - from: c04b7db4-9d52-4621-b95e-0916dd7e75d8
        output: 0
        to: cdfa4aff-840e-4891-87a5-3d698120b9bb
        input: 0
      - from: 6483fd2d-dbee-4925-b4a9-25e74b63d04d
        output: 0
        to: cdfa4aff-840e-4891-87a5-3d698120b9bb
        input: 1
      - from: 61080cfc-1996-4205-af9c-cf30827954d7
        output: 0
        to: cdfa4aff-840e-4891-87a5-3d698120b9bb
        input: 2
      - from: 6f013208-b0f5-4f7b-9d9b-072cc944241a
        output: 0
        to: 6483fd2d-dbee-4925-b4a9-25e74b63d04d
        input: 0
      - from: 6f013208-b0f5-4f7b-9d9b-072cc944241a
        output: 0
        to: c04b7db4-9d52-4621-b95e-0916dd7e75d8
        input: 0
  - type: Sample & Hold
    id: 45519ddb-72d7-45ca-aa11-92fdbbcd1060
    position:
      x: 178.19683837890625
      y: 147.85882568359375
  - type: Light
    id: b264602f-365b-48a2-9d25-9b95055a2c34
    position:
      x: 583.6455078125
      y: 222.92031860351562
    exposedPosition:
      x: -45.0
      y: 60.0
  - type: Trigger
    id: e1a2806d-f8bf-467b-98d9-01fa757d0344
    position:
      x: -240.7501220703125
      y: 256.52545166015625
    exposedPosition:
      x: -45.0
      y: 60.0
    toggle: false
    state: false
  - type: Add
    id: 755a71db-3c42-4b26-9553-d88e8d64f5a1
    position:
      x: -58.31658935546875
      y: 232.0797882080078
  - type: Expr
    id: 16190133-b20f-464d-b936-7f111ee344fd
    position:
      x: -223.63629150390625
      y: 154.33245849609375
    expr: '1'
  - type: Sub
    id: 254b6976-445e-45b5-9ebd-759c7e5b5d72
    position:
      x: 21.222946166992188
      y: -156.65199279785156
  - type: Crossfade
    id: 942871d1-63f1-4fb8-8d3f-8eeea8c6586f
    position:
      x: -13.68365478515625
      y: -23.358680725097656
  - type: FeedbackDelay
    id: fbb7faad-50e9-4130-bc9c-3b93bbfc80ff
    position:
      x: 366.53289794921875
      y: 0.1832122802734375
  wires:
  - from: fbb7faad-50e9-4130-bc9c-3b93bbfc80ff
    output: 0
    to: 7b00f4c4-e000-4555-9884-78de377b851d
    input: 0
  - from: b064a8da-2852-43bf-9f9c-e3b709afffcf
    output: 0
    to: 43344530-a83c-4044-b4e9-d893f0024871
    input: 0
  - from: 3d4feaa7-2746-4446-8e63-6bf2c94f0cee
    output: 0
    to: 43344530-a83c-4044-b4e9-d893f0024871
    input: 1
  - from: 00f8bbbf-24fb-4d35-b610-ec60491268a1
    output: 0
    to: 43344530-a83c-4044-b4e9-d893f0024871
    input: 2
  - from: 7124decb-098a-468b-ad93-989e5bccfaf8
    output: 0
    to: 43344530-a83c-4044-b4e9-d893f0024871
    input: 3
  - from: 1b7a019a-c902-4b6c-8bd2-3f71c5634da1
    output: 0
    to: 43344530-a83c-4044-b4e9-d893f0024871
    input: 4
  - from: 6f5cc4bd-cd93-4199-8d28-63834b02e1fd
    output: 0
    to: 43344530-a83c-4044-b4e9-d893f0024871
    input: 5
  - from: 933d7e40-0d81-418b-a281-7bfb27b2910d
    output: 0
    to: 43344530-a83c-4044-b4e9-d893f0024871
    input: 6
  - from: 1d77b4d2-9a56-425e-b538-938cee883573
    output: 0
    to: 43344530-a83c-4044-b4e9-d893f0024871
    input: 7
  - from: fbb7faad-50e9-4130-bc9c-3b93bbfc80ff
    output: 0
    to: 43344530-a83c-4044-b4e9-d893f0024871
    input: 8
  - from: 942871d1-63f1-4fb8-8d3f-8eeea8c6586f
    output: 0
    to: 45519ddb-72d7-45ca-aa11-92fdbbcd1060
    input: 0
  - from: 755a71db-3c42-4b26-9553-d88e8d64f5a1
    output: 0
    to: 45519ddb-72d7-45ca-aa11-92fdbbcd1060
    input: 1
  - from: 45519ddb-72d7-45ca-aa11-92fdbbcd1060
    output: 0
    to: b264602f-365b-48a2-9d25-9b95055a2c34
    input: 0
  - from: e1a2806d-f8bf-467b-98d9-01fa757d0344
    output: 0
    to: 755a71db-3c42-4b26-9553-d88e8d64f5a1
    input: 0
  - from: 5b5fe154-af7e-4007-b8ee-a87885030917
    output: 0
    to: 755a71db-3c42-4b26-9553-d88e8d64f5a1
    input: 1
  - from: 16190133-b20f-464d-b936-7f111ee344fd
    output: 0
    to: 254b6976-445e-45b5-9ebd-759c7e5b5d72
    input: 0
  - from: fbb7faad-50e9-4130-bc9c-3b93bbfc80ff
    output: 0
    to: 254b6976-445e-45b5-9ebd-759c7e5b5d72
    input: 1
  - from: 43344530-a83c-4044-b4e9-d893f0024871
    output: 0
    to: 942871d1-63f1-4fb8-8d3f-8eeea8c6586f
    input: 0
  - from: 254b6976-445e-45b5-9ebd-759c7e5b5d72
    output: 0
    to: 942871d1-63f1-4fb8-8d3f-8eeea8c6586f
    input: 1
  - from: e1a2806d-f8bf-467b-98d9-01fa757d0344
    output: 0
    to: 942871d1-63f1-4fb8-8d3f-8eeea8c6586f
    input: 2
  - from: 45519ddb-72d7-45ca-aa11-92fdbbcd1060
    output: 0
    to: fbb7faad-50e9-4130-bc9c-3b93bbfc80ff
    input: 0
YAML

LIGHT_NODE = YAML.load <<YAML
---
type: Light
id: b264602f-365b-48a2-9d25-9b95055a2c34
position:
  x: 0.0
  y: 0.0
YAML
