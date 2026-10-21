# frozen_string_literal: true

module Shares
  module CodedMutations
    def change_code(short_code_id, code)
      short_codes.by_pk(short_code_id).command(:update).call(code:, updated_at: Time.now)
      code
    end

    def create(code: nil, **fields)
      transaction { root.command(:create).call(short_code_id: new_short_code(code), **fields).id }
    end

    def delete(short_code_id) = short_codes.by_pk(short_code_id).delete

    # A generated code is its row's id in base 36, so the id comes first.
    def new_short_code(code = nil)
      id = short_codes.dataset.db.get(Sequel.function(:nextval, "short_codes_id_seq"))
      short_codes.command(:create).call(id:, code: code || id.to_s(36)).id
    end
  end
end
