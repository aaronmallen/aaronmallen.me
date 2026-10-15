# frozen_string_literal: true

module Social
  module Operations
    class FindOverLimitNetwork
      include Deps[measure_parts: "operations.measure_parts"]

      def call(social_post, edit)
        bodies = social_post.parts.map(&:body)
        index = edit.part_number - 1
        body = bodies[index]
        return nil unless body && edit.applies_to?(body)

        bodies[index] = edit.apply_to(body)
        measure_parts.call(bodies, targets(social_post)).fetch(index).values.find(&:over)
      end

      private

      def targets(social_post) = Blog::Types::NetworkName.values & social_post.targets.to_a
    end
  end
end
