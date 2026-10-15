# frozen_string_literal: true

module Blog
  class TagOperation < Operation
    def call(id, name)
      transaction do
        step found(mutations.by_id_for_update(id))
        change(id, name)
        queries.by_id(id)
      end
    end
  end
end
