# frozen_string_literal: true

module Decisions
  module Repos
    class DecisionQueries < DB::Repo
      STATUSES = Blog::Types::DecisionStatus.values.freeze

      def by_id(id) = decisions.combine(:options, :tags).by_pk(id).one

      def by_tag(tag) = decisions.combine(:options, :tags).tagged(tag).newest_first.to_a

      def comment_on_decision?(decision_id, id) = decision_comments.for_decision(decision_id).by_pk(id).exist?

      def comments(decision_id) = decision_comments.for_decision(decision_id).oldest_first.to_a

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

      def option_on_decision(decision_id, id) = decision_options.for_decision(decision_id).by_pk(id).one

      def page_by_status(status, page)
        page.fill(decisions.combine(:comments, :options, :tags).with_status(status).newest_first.paged(page).to_a)
      end

      def timeline(decision_id) = decision_timeline.for_decision(decision_id).oldest_first.to_a

      private

      def count_statuses(found) = found.counts_by_status.to_a.to_h { [it.status, it.count] }

      def narrowed(found, tag:, text:)
        found = found.tagged(tag) if tag
        text ? found.matching(text) : found
      end
    end
  end
end
