# frozen_string_literal: true

require "graphql"
require "zlib"

RSpec.describe "GraphQL queries", type: :app do
  def holders(namespace)
    modules = namespace.constants(false).map { namespace.const_get(it) }
    modules.select { it.is_a?(Module) && it.const_defined?(:Queries, false) }.map { it.const_get(:Queries) }
  end

  def queries(namespace)
    holders(namespace).flat_map do |queries|
      texts = queries.constants(false).map { ["#{queries}::#{it}", queries.const_get(it)] }
      texts.select { |_, text| text.to_s.match?(/\A\s*(query|mutation)\b/) }
    end.to_h
  end

  def schema(name)
    GraphQL::Schema.from_definition(
      Zlib::GzipReader.open(Hanami.app.root.join(".config/graphql/#{name}.graphql.gz"), &:read),
    )
  end

  { GitHub => "github", Linear => "linear" }.each do |namespace, name|
    it "checks every #{namespace} query against the #{name} schema", :aggregate_failures do
      checked = schema(name)
      found = queries(namespace)

      expect(found).not_to be_empty
      expect(found.transform_values { checked.validate(it).map(&:message) }.reject { _2.empty? }).to eq({})
    end
  end
end
