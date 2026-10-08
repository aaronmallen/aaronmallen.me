# frozen_string_literal: true

module Admin
  module Helpers
    module Credits
      AGENT = "credits.agent"
      OWNER = "credits.owner"
      OWNER_KIND = Blog::Types::ContributorKind["owner"]
      SEPARATOR = ", "

      module_function

      def word(fields)
        return yield(OWNER) if fields["kind"] == OWNER_KIND

        yield(AGENT, agent: fields["agent"], model: fields["model"])
      end

      def words(contributors, &) = Array(contributors).map { word(it.transform_keys(&:to_s), &) }.join(SEPARATOR)
    end
  end
end
