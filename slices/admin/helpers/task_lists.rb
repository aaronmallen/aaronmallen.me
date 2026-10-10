# frozen_string_literal: true

module Admin
  module Helpers
    module TaskLists
      NAMES = Blog::Types::TaskFilter.values.to_h { [it, "task_lists.names.#{it}"] }.freeze
      TITLES = Blog::Types::TaskFilter.values.to_h { [it, "task_lists.titles.#{it}"] }.freeze

      module_function

      def name(list) = NAMES.fetch(list)

      def title(list) = TITLES.fetch(list)
    end
  end
end
