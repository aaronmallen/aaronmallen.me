# frozen_string_literal: true

module Tags
  module Repos
    class TagRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }
      commands delete: :by_pk

      def all_in(scope) = tags.in_scope(scope).in_name_order.to_a

      def count_matching(scope, text) = matching(scope, text).count

      def find_in(scope, id) = tags.in_scope(scope).by_pk(id).one

      def next_color(scope:) = tags.next_color(scope:)

      def page_matching(scope, text, page) = page.fill(matching(scope, text).in_name_order.paged(page).to_a)

      def usage(scope:)
        by_kind = tags.counts_by_kind(scope)

        by_kind.values.flat_map(&:keys).uniq.to_h do |id|
          [id, by_kind.filter_map { |kind, counts| [kind, counts[id]] if counts[id] }.to_h]
        end
      end

      private

      def matching(scope, text) = tags.in_scope(scope).naming(text)
    end
  end
end
