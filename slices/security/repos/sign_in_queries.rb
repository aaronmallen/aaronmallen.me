# frozen_string_literal: true

module Security
  module Repos
    class SignInQueries < Blog::DB::Repo
      def failure_count = sign_ins.open_failures(failures_since).count

      def page(page) = page.fill(sign_ins.listed(failures_since).newest_first.paged(page).to_a)

      private

      def failures_since = Time.now - (7 * 24 * 60 * 60)
    end
  end
end
