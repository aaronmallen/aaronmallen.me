# frozen_string_literal: true

module Analytics
  module Operations
    class FindPlace
      include Deps["geo.countries"]

      def call(address) = countries.place(address)
    end
  end
end
