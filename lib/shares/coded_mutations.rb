# frozen_string_literal: true

module Shares
  module CodedMutations
    def change_code(short_code_id, code)
      short_codes.by_pk(short_code_id).command(:update).call(code:, updated_at: Time.now)
    end

    def create(code:, **fields)
      transaction do
        short_code = short_codes.command(:create).call(code:)
        root.command(:create).call(short_code_id: short_code.id, **fields).id
      end
    end

    def delete(short_code_id) = short_codes.by_pk(short_code_id).delete
  end
end
