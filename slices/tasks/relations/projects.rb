# frozen_string_literal: true

module Tasks
  module Relations
    class Projects < Blog::DB::Relation
      SLUG = Blog::Types::Normalized::Slug

      schema :projects, infer: true

      def in_name_order = order(self[:name].asc, self[:id].asc)

      def slugged(slugs)
        dataset.unordered.select_map(%i[id name]).filter_map { |id, name| id if slugs.include?(slug(name)) }
      end

      private

      def slug(name) = SLUG.call(name) { nil }
    end
  end
end
