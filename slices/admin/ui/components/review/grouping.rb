# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        module Grouping
          module_function

          def by(items)
            groups = Hash.new { |found, key| found[key] = [] }
            items.each do |item|
              keys = Array(yield(item))
              (keys.empty? ? [nil] : keys).each { groups[it] << item }
            end
            groups.sort_by { |key, members| [-members.size, key.nil? ? 1 : 0, key.to_s] }
          end
        end
      end
    end
  end
end
