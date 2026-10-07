# frozen_string_literal: true

module Security
  module Relations
    class SignIns < Blog::DB::Relation
      schema :sign_ins, infer: true
    end
  end
end
