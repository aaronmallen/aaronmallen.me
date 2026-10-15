# frozen_string_literal: true

module Posts
  module Jobs
    class CheckPostLinks < Blog::ScheduledJob
      include Deps[
        check_post_links: "operations.check_post_links", check_short_links: "shares.operations.check_short_links",
        run_mutations: "repos.link_check_run_mutations",
      ]

      def perform
        checked = 0
        checks = [check_post_links, check_short_links]
        run = run_mutations.start(links_due: checks.sum(&:due))
        checks.each { it.call { checked += 1 } }
      ensure
        run_mutations.finish(run, links_checked: checked) if run
      end
    end
  end
end
