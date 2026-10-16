# frozen_string_literal: true

module MCP
  module Tools
    class ListTags < Base
      description "List the tags in one scope by name with their colour, description, how many records carry " \
                  "each, and that count split by kind. #{TAG_KINDS}. A tag nothing carries counts zero. Give query " \
                  "to keep only the tags whose name holds it; count holds how many tags match. " \
                  "#{API::Helpers::Paging::USAGE}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
