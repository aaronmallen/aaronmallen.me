# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class ReposCard < Component
          prop :commits, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Hash)

          def view_template
            Card(title: t(".title"), id: "review-commits") do
              next Empty { t(".empty") } if @commits.empty?

              @commits.each { |repo, totals| ListItem(title: repo, sub: t(".totals", **counts(totals))) }
            end
          end

          private

          def counts(totals)
            {
              commits: t(".commits", count: totals[:commits]),
              additions: Blog::Figures.count(totals[:additions]),
              deletions: Blog::Figures.count(totals[:deletions]),
            }
          end
        end
      end
    end
  end
end
