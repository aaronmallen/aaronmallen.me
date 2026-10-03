# frozen_string_literal: true

module Decisions
  module Repos
    class DecisionRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }

      def by_id(id) = decisions.combine(:options).by_pk(id).one

      def by_id_for_update(id) = decisions.by_pk(id).lock.one

      def count_by_status = decisions.counts_by_status.to_a.to_h { [it.status, it.count] }

      def exist?(id) = decisions.by_pk(id).exist?

      def page_by_status(status, page)
        page.fill(decisions.combine(:options).with_status(status).newest_first.paged(page).to_a)
      end

      def record(decision_id, kind, **) = decision_events.command(:create).call(decision_id:, kind:, **)
    end
  end
end
