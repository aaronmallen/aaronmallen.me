# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class NetworkLabel < Component
          OUTBOUND = { target: "_blank", rel: "noopener noreferrer" }.freeze

          prop :network, Blog::Types::NetworkName
          prop :text, Blog::Types::String
          prop :failing, Blog::Types::Bool, default: false
          prop :url, Blog::Types::String.optional, default: nil

          def view_template
            classes = ["sq-network", @network, ("bad" if @failing)]

            @url ? a(class: classes, href: @url, **OUTBOUND) { content } : span(class: classes) { content }
          end

          private

          def content
            IconLabel(icon: QueueItem::NETWORK_ICONS.fetch(@network)) do
              @failing ? t(".failed", network: @text) : @text
            end
          end
        end
      end
    end
  end
end
