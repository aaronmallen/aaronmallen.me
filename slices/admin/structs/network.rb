# frozen_string_literal: true

module Admin
  module Structs
    class Network < Data.define(:configured, :label, :limit, :max_bytes, :name, :reserved_per_url, :selected,
                                :tagged_host)
      LABELS = Blog::Types::NetworkName.values.to_h { [it, "social.networks.#{it}"] }.freeze
      SEPARATOR = " + "

      def value = name
    end
  end
end
