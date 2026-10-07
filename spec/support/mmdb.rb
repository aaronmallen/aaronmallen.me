# frozen_string_literal: true

require "ipaddr"

class Mmdb
  Leaf = Struct.new(:offset)

  BITS = 128
  BUILD_EPOCH = 1_789_000_000
  MAP = 7
  MARKER = "#{"\xAB\xCD\xEF".b}MaxMind.com".b
  RECORD_SIZE = 32
  SEPARATOR = ("\x00".b * 16)
  STRING = 2
  UINT32 = 6
  V4_PREFIX = 96
  VECTOR = 11

  def initialize(database_type: "GeoLite2-City")
    @data = {}
    @database_type = database_type
    @nodes = [[nil, nil]]
    @section = +"".b
  end

  def add(network, record)
    node = 0
    path = bits(network)

    path.each_with_index do |bit, depth|
      if depth == path.size - 1
        @nodes[node][bit] = Leaf.new(store(record))
      else
        node = child(node, bit)
      end
    end

    self
  end

  def to_s = tree + SEPARATOR + @section + MARKER + encode(metadata)

  private

  def bits(network)
    address = IPAddr.new(network)
    width = address.ipv4? ? 32 : BITS
    leading = address.ipv4? ? Array.new(V4_PREFIX, 0) : []

    leading + Array.new(address.prefix) { (address.to_i >> (width - 1 - it)) & 1 }
  end

  def child(node, bit)
    @nodes[node][bit] ||= @nodes.size.tap { @nodes << [nil, nil] }
  end

  def control(type, size)
    marker, extra = size_marker(size)
    head = type < 8 ? [(type << 5) | marker] : [marker, type - 7]

    head.pack("C*") + extra
  end

  def encode(value)
    case value
      when Hash then encode_map(value)
      when Array then encode_array(value)
      when Integer then control(UINT32, 4) + [value].pack("N")
      else encode_string(value.to_s)
    end
  end

  def encode_array(values) = control(VECTOR, values.size) + values.map { encode(it) }.join

  def encode_map(pairs) = control(MAP, pairs.size) + pairs.flat_map { |key, value| [encode(key), encode(value)] }.join

  def encode_string(value) = control(STRING, value.bytesize) + value.b

  def metadata
    {
      "binary_format_major_version" => 2, "binary_format_minor_version" => 0,
      "build_epoch" => BUILD_EPOCH, "database_type" => @database_type,
      "description" => { "en" => "A database built for the specs" },
      "ip_version" => 6, "languages" => %w[en],
      "node_count" => @nodes.size, "record_size" => RECORD_SIZE,
    }
  end

  def record(entry)
    case entry
      when Leaf then @nodes.size + SEPARATOR.bytesize + entry.offset
      when Integer then entry
      else @nodes.size
    end
  end

  def size_marker(size)
    return [size, ""] if size < 29
    return [29, [size - 29].pack("C")] if size < 285

    [30, [size - 285].pack("n")]
  end

  def store(record)
    @data[record] ||= @section.bytesize.tap { @section << encode(record) }
  end

  def tree = @nodes.flatten(1).map { record(it) }.pack("N*")
end
