# frozen_string_literal: true

module Shares
  module Contracts
    class UploadContract < Blog::Contract
      schema do
        required(:file).filled
        required(:filename).filled(Blog::Types::TrimmedText)
        required(:content_type).filled(Blog::Types::Normalized::MediaType)
      end

      rule(:filename).validate(:without_controls)
    end
  end
end
