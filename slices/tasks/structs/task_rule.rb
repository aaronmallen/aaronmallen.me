# frozen_string_literal: true

module Tasks
  module Structs
    class TaskRule < Blog::DB::Struct
      ANY_REPO = "*"

      attribute?(:projects, ROM::Types::Array.default { [] })

      def matches?(repo)
        owner, name = pattern.split("/", 2)

        name == ANY_REPO ? repo.start_with?("#{owner}/") : repo == pattern
      end
    end
  end
end
