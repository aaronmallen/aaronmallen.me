# frozen_string_literal: true

module Decisions
  module Repos
    class DecisionRepo < Blog::DB::Repo
      TAG_SCOPE = Blog::Types::TagScope["private"]

      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }

      def by_id(id) = decisions.combine(:options, :tags).by_pk(id).one

      def by_id_for_update(id) = decisions.by_pk(id).lock.one

      def count_by_status = decisions.counts_by_status.to_a.to_h { [it.status, it.count] }

      def exist?(id) = decisions.by_pk(id).exist?

      def listed(page, status: nil, tag: nil)
        found = decisions.combine(:options, :tags)
        found = found.with_status(status) if status
        found = found.tagged(tag) if tag

        page.fill(found.newest_first.paged(page).to_a)
      end

      def page_by_status(status, page)
        page.fill(decisions.combine(:options).with_status(status).newest_first.paged(page).to_a)
      end

      def record(decision_id, kind, **) = decision_events.command(:create).call(decision_id:, kind:, **)

      def replace_tags(id, names)
        decision_tags.replace(id, tags.claim(names, scope: TAG_SCOPE).values_at(*names))
      end
    end
  end
end
