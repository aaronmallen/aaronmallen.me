# frozen_string_literal: true

module Tasks
  module History
    BLANK = {
      from_list: nil, from_sprint_on: nil, from_status: nil, tag_name: nil, to_list: nil, to_sprint_on: nil,
      to_status: nil,
    }.freeze
    PLACE = %i[list sprint_on].freeze

    module_function

    def between(was, now) = [*moved(was, now), *restated(was, now), *retagged(was, now)]

    def changes(before, after, at)
      after.flat_map do |id, now|
        between(before.fetch(id), now).map { { **BLANK, **it, task_id: id, occurred_at: at } }
      end
    end

    def moved(was, now)
      return Blog::Constants::EMPTY_ARRAY if was.slice(*PLACE) == now.slice(*PLACE)

      [{
        kind: "moved",
        from_list: was[:list],
        from_sprint_on: was[:sprint_on],
        to_list: now[:list],
        to_sprint_on: now[:sprint_on],
      }]
    end

    def restated(was, now)
      return Blog::Constants::EMPTY_ARRAY if was[:status] == now[:status]

      [{ kind: "status_changed", from_status: was[:status], to_status: now[:status] }]
    end

    def retagged(was, now)
      [
        *(now[:tags] - was[:tags]).map { { kind: "tagged", tag_name: it } },
        *(was[:tags] - now[:tags]).map { { kind: "untagged", tag_name: it } },
      ]
    end
  end
end
