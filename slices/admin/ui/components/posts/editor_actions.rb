# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class EditorActions < Component
          DRAFT = Blog::Types::PostIntent["draft"]
          PUBLISH = Blog::Types::PostIntent["publish"]
          SAVE = Blog::Types::PostIntent["save"]

          prop :post, Blog::Types::Instance(ROM::Struct).optional
          prop :published, Blog::Types::Bool
          prop :scheduling, Blog::Types::Bool

          def view_template
            details_button
            analytics_link if @published
            @published ? save_button : draft_and_publish_buttons
          end

          private

          def analytics_link
            Button(href: path(:admin_post_analytics, id: @post.id), icon: "fa-solid fa-chart-simple") do
              t(".analytics")
            end
          end

          def details_button
            Button(
              icon: "fa-solid fa-sliders", command: "show-modal", commandfor: Details::ID,
              data: { dialog_open: Details::ID },
            ) { t(".details") }
          end

          def draft_and_publish_buttons
            Button(type: "submit", name: "intent", value: DRAFT, icon: "fa-regular fa-floppy-disk") do
              t(".save_draft")
            end
            publish_button
          end

          def publish_button
            Button(variant: :pri, type: "submit", name: "intent", value: PUBLISH) do
              span(class: "bt-label", data: { editor_now: "" }, hidden: @scheduling) do
                IconLabel(icon: "fa-solid fa-arrow-up-right-from-square") { t(".publish") }
              end
              span(class: "bt-label", data: { editor_later: "" }, hidden: !@scheduling) do
                IconLabel(icon: "fa-regular fa-clock") { t(".schedule") }
              end
            end
          end

          def save_button
            Button(variant: :pri, type: "submit", name: "intent", value: SAVE, icon: "fa-regular fa-floppy-disk") do
              t(".save")
            end
          end
        end
      end
    end
  end
end
