# frozen_string_literal: true

module Admin
  module UI
    module Components
      extend Phlex::Kit

      # Loaded up front so its kit method shadows the kernel PageHead it wraps.
      PageHead
    end
  end
end
