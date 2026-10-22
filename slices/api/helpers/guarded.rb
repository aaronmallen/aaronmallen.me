# frozen_string_literal: true

module API
  module Helpers
    module Guarded
      LINK_GROUPS = %w[links record_links].freeze

      module_function

      def row?(row, kinds) = row.is_a?(Hash) && kinds.include?((row[:kind] || row["kind"]).to_s)

      def without(value, kinds, groups: false)
        case value
          when Hash
            kept = groups ? value.except(*kinds & Blog::Types::RecordKind.values) : value
            kept.to_h { |key, item| [key, without(item, kinds, groups: LINK_GROUPS.include?(key.to_s))] }
          when Array then value.reject { row?(it, kinds) }.map { without(it, kinds) }
          else value
        end
      end
    end
  end
end
