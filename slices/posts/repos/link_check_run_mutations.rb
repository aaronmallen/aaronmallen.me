# frozen_string_literal: true

module Posts
  module Repos
    class LinkCheckRunMutations < Blog::DB::Repo
      root :link_check_runs

      def finish(id, links_checked:, at: Time.now) = link_check_runs.by_pk(id).update(links_checked:, finished_at: at)

      def start(links_due:, at: Time.now) = link_check_runs.insert(links_due:, started_at: at)
    end
  end
end
