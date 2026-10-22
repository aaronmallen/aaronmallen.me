# frozen_string_literal: true

module Contacts
  class Slice < Hanami::Slice
    config.shared_app_component_keys += %w[honeybadger.agent]

    import keys: %w[repos.connection_queries], from: :services

    export %w[operations.delete_person operations.queue_contact_sync operations.save_person repos.person_queries]
  end
end
