# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class ReposCard < Component
          OWNER_SEPARATOR = "/"

          prop :commits, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Hash)

          def view_template
            Card(title: dotted(t(".title"), Blog::Helpers::Figures.count(total)), id: "review-commits") do
              next Empty { t(".empty") } if @commits.empty?

              Capped(items: repos) { |repo, totals| row(repo, totals) }
            end
          end

          private

          def repos = @commits.sort_by { |repo, totals| [-totals[:commits], repo] }

          def row(repo, totals)
            div(class: "review-bar", title: repo) do
              span(class: "review-bar-name") { repo.split(OWNER_SEPARATOR).last }
              span(class: "review-bar-value") do
                plain "#{t('.commits', count: totals[:commits])} · "
                span(class: "commit-added") { "+#{Blog::Helpers::Figures.count(totals[:additions])}" }
                whitespace
                span(class: "commit-removed") { "−#{Blog::Helpers::Figures.count(totals[:deletions])}" }
              end
            end
          end

          def total = @commits.values.sum { it[:commits] }
        end
      end
    end
  end
end
