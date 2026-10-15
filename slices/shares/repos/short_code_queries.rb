# frozen_string_literal: true

module Shares
  module Repos
    class ShortCodeQueries < Blog::DB::Repo
      def free_code(length = Code::MIN_LENGTH)
        codes = short_codes.where(Sequel.char_length(:code) => length).where(code: /^[#{Code::ALPHABET.join}]+$/)
        return free_code(length + 1) if codes.count >= Code::ALPHABET.size**length

        Code.pick(length, codes.pluck(:code))
      end
    end
  end
end
