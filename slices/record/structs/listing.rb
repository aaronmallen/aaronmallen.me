# frozen_string_literal: true

module Record
  module Structs
    Listing = Data.define(:items, :cut_short) { def cut_short? = cut_short }
  end
end
