# frozen_string_literal: true

module Tags
  module Repos
    class TagRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }
      commands delete: :by_pk

      def all = tags.in_name_order.to_a

      def by_id(id) = tags.by_pk(id).one

      def next_color(scope:) = tags.next_color(scope:)

      def usage
        by_kind = tags.counts_by_kind

        by_kind.values.flat_map(&:keys).uniq.to_h do |id|
          [id, by_kind.filter_map { |kind, counts| [kind, counts[id]] if counts[id] }.to_h]
        end
      end
    end
  end
end
