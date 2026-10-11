# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Health
        class AgentsCard < Component
          ROWS = Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          prop :clients, ROWS
          prop :tokens, ROWS

          def view_template
            Card(title: t(".title")) do
              p(class: "para") { t(".about") }
              next Empty { t(".empty") } if @clients.empty? && @tokens.empty?

              @clients.each { ListItem(title: client_name(it), sub: t(".client"), icon: "fa-solid fa-plug") }
              @tokens.each { ListItem(title: it.name, sub: t(".token"), icon: "fa-solid fa-key") }
            end
          end

          private

          def client_name(client) = client.client_name.to_s.strip.then { it.empty? ? client.client_id : it }
        end
      end
    end
  end
end
