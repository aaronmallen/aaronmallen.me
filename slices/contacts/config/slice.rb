# frozen_string_literal: true

module Contacts
  class Slice < Hanami::Slice
    export %w[operations.delete_person operations.save_person repos.person_queries]
  end
end
