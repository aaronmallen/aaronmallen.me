# frozen_string_literal: true

module Tasks
  module Structs
    class TaskRule < Blog::DB::Struct
      ANY_REPO = "*"
      PROJECT_TAG = Blog::Types::TagScope["project"]

      attribute?(:projects, ROM::Types::Array.default { [] })

      def matches?(repo)
        owner, name = pattern.split("/", 2)

        name == ANY_REPO ? repo.start_with?("#{owner}/") : repo == pattern
      end

      def project_key_for(tag)
        projects.first&.key if tag.scope == PROJECT_TAG
      end
    end
  end
end
