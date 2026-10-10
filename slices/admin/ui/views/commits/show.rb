# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Commits
        class Show < View
          GITHUB_URL = "https://github.com/%s/commit/%s"

          prop :commit, Blog::Types::Instance(ROM::Struct)
          prop :body_html, Blog::Types::String.optional
          prop :records, Blog::Types::Hash

          def view_template
            PageHead(title: subject, kicker: t(".kicker", sha: short_sha), sub:, sub_icon: "fa-solid fa-code-commit") do
              BackLink(href: path(:admin_activity)) { t(".back") }
              github_link
            end

            GitHubRecord(
              body_html: @body_html, label: t(".label"), title: t(".title"), records: @records, kind: "commit",
              id: @commit.id, find_path: path(:admin_commit, id: @commit.id),
            ) { stats }
          end

          private

          def clock = l(@commit.commit_time, format: :clock)

          def day = l(@commit.commit_date, format: :medium)

          def github_link
            Button(
              href: github_url, **Blog::UI::Component::OUTBOUND, variant: :gh, icon: "fa-brands fa-github",
            ) do
              t(".github")
            end
          end

          def github_url = format(GITHUB_URL, @commit.repo, @commit.sha)

          def short_sha = Admin::Short.sha(@commit.sha)

          def stats
            Stat(key: t(".added"), value: "+#{@commit.additions}")
            Stat(key: t(".removed"), value: "−#{@commit.deletions}")
            Stat(key: t(".sha"), value: short_sha)
          end

          def sub = t(".sub", repo: @commit.repo, branch: @commit.branch, day:, clock:)

          def subject = Helpers::CommitMessage.subject(@commit.message)
        end
      end
    end
  end
end
