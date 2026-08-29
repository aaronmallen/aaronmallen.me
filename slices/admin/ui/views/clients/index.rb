# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Clients
        class Index < View
          def initialize(clients:)
            super()
            @clients = clients
          end

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @clients.size))

            Card(title: t(".connected")) do
              next Empty { t(".empty") } if @clients.empty?

              @clients.each { ClientRow(client: it) }
            end
          end
        end
      end
    end
  end
end
