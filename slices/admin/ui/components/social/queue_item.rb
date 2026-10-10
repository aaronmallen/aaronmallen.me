# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class QueueItem < Component
          POSTED = Blog::Types::SocialPostStatus["posted"]

          prop :social_post, Blog::Types::Instance(ROM::Struct)
          prop :accounts, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }
          prop :filter, Blog::Types::String
          prop :now, Blog::Types::Time
          prop :suggestions, Blog::Types::Integer, default: 0

          def view_template
            article(class: "sq-item", data: { social_item: @social_post.id, key_row: true }) do
              div(class: "sq-body") do
                div(class: "sq-text") { @social_post.parts.each { |part| p(class: "sq-part") { part.body } } }
                failures
                QueueMeta(social_post: @social_post, accounts: @accounts, now: @now, suggestions: @suggestions)
              end
              actions
            end
          end

          private

          def actions
            return if @social_post.status == POSTED || @social_post.deliveries.any?

            div(class: "sq-actions") do
              edit_link
              remove_form
            end
          end

          def edit_link
            Button(
              href: path(:admin_social, filter: @filter, edit: @social_post.id), small: true,
              label: t(".edit"), icon: "fa-regular fa-pen-to-square",
              data: { social_edit: "", key_open: true },
            )
          end

          def failure_text(delivery)
            error = delivery.error.to_s.strip
            detail = delivery.failed ? error : t(".retry_queued", error:)

            t(".failure", network: t(Structs::Network::LABELS.fetch(delivery.network)), detail:)
          end

          def failures
            @social_post.deliveries.each do |delivery|
              next unless written?(delivery.error)

              p(class: "sq-fail") { failure_text(delivery) }
            end
          end

          def remove_form
            Form(action: path(:admin_delete_social_post, id: @social_post.id)) do
              input(type: "hidden", name: "filter", value: @filter)
              Button(
                type: "submit", variant: :warn, small: true, label: t(".remove"),
                icon: "fa-regular fa-trash-can", data: { social_remove_item: "" },
              )
            end
          end
        end
      end
    end
  end
end
