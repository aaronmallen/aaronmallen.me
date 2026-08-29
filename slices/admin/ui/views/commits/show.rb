# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Commits
        class Show < View
          SHA_LENGTH = 7

          def initialize(commit:, body_html:)
            super()
            @commit = commit
            @body_html = body_html
          end

          def view_template
            PageHead(title: subject, sub:, sub_icon: "fa-solid fa-code-commit") { github_link }

            Grid(columns: 3) { stats }

            Card(label: t(".label"), title: t(".title")) { message }
          end

          private

          def clock = l(@commit.commit_time, format: :clock)

          def day = l(@commit.commit_date, format: :medium)

          def github_link
            a(class: "btn gh", href: github_url, target: "_blank", rel: "noopener noreferrer") do
              i(class: "fa-brands fa-github", aria: { hidden: "true" })
              plain t(".github")
            end
          end

          def github_url = format(Blog::Constants::GITHUB_COMMIT_URL, @commit.repo, @commit.sha)

          def message
            return Empty { t(".no_body") } unless @body_html

            div(class: "commit-body post-body") { raw(safe(@body_html)) }
          end

          def short_sha = @commit.sha[0, SHA_LENGTH]

          def stats
            Stat(key: t(".sha"), value: short_sha)
            Stat(key: t(".added"), value: "+#{@commit.additions}")
            Stat(key: t(".removed"), value: "−#{@commit.deletions}")
          end

          def sub = t(".sub", repo: @commit.repo, branch: @commit.branch, day:, clock:)

          def subject = CommitMessage.subject(@commit.message)
        end
      end
    end
  end
end
