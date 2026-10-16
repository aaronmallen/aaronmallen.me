# frozen_string_literal: true

module Admin
  module UI
    module Components
      module ShareIds
        def delete_id(record) = "#{scope(record)}-delete"

        def form_id(record) = "#{scope(record)}-form"

        def scope(record) = "#{self::SCOPE}-#{record.id}"
      end
    end
  end
end
