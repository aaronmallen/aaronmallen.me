# frozen_string_literal: true

module Shares
  module ContentType
    IMAGE = %r{\Aimage/}

    def self.image?(content_type) = IMAGE.match?(content_type)
  end
end
