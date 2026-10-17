# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [::Social::Contracts::ComposeSocialPostContract, ::Social::Contracts::SocialPostContract].freeze
          SCOPE = "social"
          UNSHOWN = %i[connection_ids mode post_id status].freeze
        end
      end
    end
  end
end
