# frozen_string_literal: true

require "alba"

module Blog
  class Serializer
    include Alba::Resource

    private

    def day(date) = date&.iso8601

    def stamp(time) = time&.utc&.iso8601
  end
end
