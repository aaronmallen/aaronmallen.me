# frozen_string_literal: true

module Social
  module Structs
    class Webmention < Blog::DB::Struct
      NAMED = /\S/

      def author_label = [author_name, author_domain, source_url].find { it.to_s.match?(NAMED) }
    end
  end
end
