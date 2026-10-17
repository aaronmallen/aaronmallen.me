# frozen_string_literal: true

module Shares
  module Repos
    class ShortCodeQueries < Blog::DB::Repo
      def free_code(length = Helpers::Code::MIN_LENGTH)
        alphabet = Helpers::Code::ALPHABET
        codes = short_codes.where(Sequel.char_length(:code) => length).where(code: /^[#{alphabet.join}]+$/)
        return free_code(length + 1) if codes.count >= alphabet.size**length

        Helpers::Code.pick(length, codes.pluck(:code))
      end
    end
  end
end
