# frozen_string_literal: true

module Tags
  class Slice < Hanami::Slice
    export %w[
      operations.remove_tag operations.save_tag queries.all queries.by_id queries.matching queries.matching_count
      queries.usage
    ]
  end
end
