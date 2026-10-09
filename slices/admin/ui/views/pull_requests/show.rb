# frozen_string_literal: true

module Admin
  module UI
    module Views
      module PullRequests
        class Show < View
          prop :pull_request, Blog::Types::Instance(ROM::Struct)
          prop :body_html, Blog::Types::String.optional

          def view_template
            PageHead(
              title: @pull_request.title, kicker: t(".kicker", number: @pull_request.number), sub: @pull_request.repo,
              sub_icon: "fa-solid fa-code-pull-request",
            ) do
              BackLink(href: path(:admin_activity)) { t(".back") }
              github_link
            end

            Card(label: t(".label"), title: t(".title")) { body }
          end

          private

          def body
            description
            div(class: "commit-stats") { stats }
          end

          def description
            return Empty { t(".no_body") } unless @body_html

            div(class: "commit-body post-body") { raw(safe(@body_html)) }
          end

          def ended
            if @pull_request.merged_at
              Stat(key: t(".merged"), value: stamp(@pull_request.merged_at))
            elsif @pull_request.closed_at
              Stat(key: t(".closed"), value: stamp(@pull_request.closed_at))
            end
          end

          def github_link
            Button(
              href: @pull_request.url, target: "_blank", rel: "noopener noreferrer", variant: :gh,
              icon: "fa-brands fa-github",
            ) do
              t(".github")
            end
          end

          def stamp(time) = l(Blog::TimeZone.local(time), format: :medium)

          def state
            if @pull_request.merged_at then t(".states.merged")
            elsif @pull_request.closed_at then t(".states.closed")
            elsif @pull_request.ready_at then t(".states.open")
            else
              t(".states.draft")
            end
          end

          def stats
            Stat(key: t(".state"), value: state)
            Stat(key: t(".opened"), value: stamp(@pull_request.ready_at)) if @pull_request.ready_at
            ended
          end
        end
      end
    end
  end
end
