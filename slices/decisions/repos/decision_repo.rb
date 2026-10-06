# frozen_string_literal: true

module Decisions
  module Repos
    class DecisionRepo < Blog::DB::Repo
      STATUSES = Blog::Types::DecisionStatus.values.freeze
      TAG_SCOPE = Blog::Types::TagScope["private"]

      stamped_commands :create, :update

      def by_id(id) = decisions.combine(:options, :tags).by_pk(id).one

      def by_id_for_update(id) = decisions.by_pk(id).lock.one

      def by_tag(tag) = decisions.combine(:options, :tags).tagged(tag).newest_first.to_a

      def count_by_status = count_statuses(decisions)

      def count_found(tag: nil, text: nil)
        counted = count_statuses(narrowed(decisions, tag:, text:))

        STATUSES.to_h { [it, counted.fetch(it, 0)] }
      end

      def exist?(id) = decisions.by_pk(id).exist?

      def listed(page, status: nil, tag: nil, text: nil)
        found = narrowed(decisions.combine(:options, :tags), tag:, text:)
        found = found.with_status(status) if status

        page.fill(found.newest_first.paged(page).to_a)
      end

      def page_by_status(status, page)
        page.fill(decisions.combine(:options).with_status(status).newest_first.paged(page).to_a)
      end

      def record(decision_id, kind, **) = decision_events.command(:create).call(decision_id:, kind:, **)

      def replace_tags(id, names)
        decision_tags.replace(id, tags.claim(names, scope: TAG_SCOPE).values_at(*names))
      end

      private

      def count_statuses(found) = found.counts_by_status.to_a.to_h { [it.status, it.count] }

      def narrowed(found, tag:, text:)
        found = found.tagged(tag) if tag
        text ? found.matching(text) : found
      end
    end
  end
end
