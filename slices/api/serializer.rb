# auto_register: false
# frozen_string_literal: true

module API
  class Serializer < Blog::Serializer
    COMPONENTS = "#/components/schemas/"

    def self.component = name.split("::").last

    def self.reference = { "$ref": "#{COMPONENTS}#{component}" }
  end
end
