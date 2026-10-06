# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Commits
        class Show < View
          SHA_LENGTH = 7

          prop :commit, Blog::Types::Instance(ROM::Struct)
          prop :body_html, Blog::Types::String.optional
          prop :records, Blog::Types::Hash

          def view_template
            PageHead(title: subject, sub:, sub_icon: "fa-solid fa-code-commit") { github_link }

            Grid(columns: 3) { stats }

            Card(label: t(".label"), title: t(".title")) { message }

            linked
          end

          private

          def clock = l(@commit.commit_time, format: :clock)

          def day = l(@commit.commit_date, format: :medium)

          def github_link
            Button(
              href: github_url, target: "_blank", rel: "noopener noreferrer", variant: :gh, icon: "fa-brands fa-github",
            ) do
              t(".github")
            end
          end

          def github_url = format(Blog::Constants::GITHUB_COMMIT_URL, @commit.repo, @commit.sha)

          def linked
            id = @commit.id

            RecordLinks::Section(
              records: @records, kind: "commit", id:, find_path: path(:admin_commit, id:),
            )
          end

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
