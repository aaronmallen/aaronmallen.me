# frozen_string_literal: true

require "prism"
require "yaml"

class ContractCodes
  ERRORS = YAML.load_file(Hanami.app.root.join("config/errors.yml")).dig("en", "dry_validation", "errors")

  def self.call(contract) = new(contract).call

  def initialize(contract)
    @contract = contract
    @codes = Hash.new { |hash, key| hash[key] = Set.new }
  end

  def call
    @contract.schema.rules.each { |field, rule| schema_codes(field, rule) }
    @contract.rules.each { |rule| blocks(rule).each { failures(it, rule.keys.first.to_s.split(".").first&.to_sym) } }
    @codes
  end

  private

  def add(field, codes) = @codes[field].merge(codes)

  def blocks(rule) = [*rule.macros.map { |(name)| @contract.macros.resolve(name).block }, rule.block].compact

  def calls(node, name) = walk(node).select { it.is_a?(Prism::CallNode) && it.name == name }

  def constant(name)
    value = @contract.const_get(name)
    value.is_a?(String) ? [value] : []
  end

  def failures(block, field)
    read(*block.source_location)
    calls(@scope, :failure).each do |call|
      target = target_field(call.receiver, field)
      call.arguments.arguments.each { add(target, values(it)) } if target
    end
  end

  def helper(call)
    definition = call.receiver.nil? && walk(@root).find { it.is_a?(Prism::DefNode) && it.name == call.name }
    definition || call
  end

  def local(name)
    walk(@scope).select { it.is_a?(Prism::LocalVariableWriteNode) && it.name == name }.flat_map { values(it.value) }
  end

  def predicate_codes(field, predicate)
    code = ERRORS.dig("rules", field.to_s, predicate.to_s) || ERRORS[predicate.to_s]
    code.is_a?(Hash) ? strings(code) : Array(code)
  end

  def predicates(ast)
    return [] unless ast.is_a?(Array)
    return [ast[1][0]] if ast[0] == :predicate && ast[1][0] != :key?

    ast.flat_map { predicates(it) }
  end

  def read(path, line)
    @root = Prism.parse_file(path).value
    @scope = walk(@root).find { (it.is_a?(Prism::BlockNode) || it.is_a?(Prism::LambdaNode)) && it.location.start_line == line }
  end

  def schema_codes(field, rule) = predicates(rule.to_ast).each { add(field, predicate_codes(field, it)) }

  def strings(tree) = tree.values.flat_map { it.is_a?(Hash) ? strings(it) : [it] }

  def target_field(receiver, field)
    return unless receiver.is_a?(Prism::CallNode) && receiver.name == :key

    symbol = receiver.arguments&.arguments&.first
    symbol.is_a?(Prism::SymbolNode) ? symbol.unescaped.to_sym : field
  end

  def values(node)
    case node
      when Prism::StringNode then [node.unescaped]
      when Prism::ConstantReadNode then constant(node.name)
      when Prism::LocalVariableReadNode then local(node.name)
      when Prism::CallNode then helper(node).compact_child_nodes.flat_map { values(it) }
      else node.compact_child_nodes.flat_map { values(it) }
    end
  end

  def walk(node) = [node, *node.compact_child_nodes.flat_map { walk(it) }]
end
