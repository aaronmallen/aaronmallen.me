# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Jobs
        class Set < Component
          KEYS = Blog::Types::JobSetName.values.to_h do |name|
            [name, { empty: ".empty.#{name}", hint: ".hints.#{name}", title: ".titles.#{name}" }.freeze]
          end.freeze
          PRIMARY = { "retries" => "retry", "dead" => "retry", "scheduled" => "run" }.transform_values do |act|
            { act:, label: ".acts.#{act}" }.freeze
          end.freeze
          SOONEST_FIRST = %w[retries scheduled].freeze

          def self.id(name) = "jobs-#{name}"

          prop :set, Blog::Types::Instance(Data)

          def view_template
            Card(**head, empty:, id:) do |card|
              card.side { fewer } if @set.all?
              @set.jobs.rows.each { job(it) }
              more
            end
          end

          private

          def count(number) = Blog::Helpers::Figures.count(number)

          def drawer_path(found)
            query = @set.all? ? { set: name, **@set.jobs.query } : {}

            jobs_path(**query, open: name, jid: found.jid)
          end

          def empty = (t(keys[:empty]) unless @set.size.positive?)

          def error(found)
            p(class: "jobs-error") do
              b { found.error_class }
              plain " #{found.error_message}" if found.error_message
            end
          end

          def fewer = a(class: "settings-link", href: jobs_path) { t(".fewer") }

          def head = { title: t(keys[:title]), note: count(@set.size), blurb: t(keys[:hint]) }

          def id = self.class.id(name)

          def job(found)
            data = { menu: path(:admin_set_job_menu, set: name, jid: found.jid) }

            ListItem(title: found.name, href: drawer_path(found), sub: nil, hover: true, data:) do |item|
              item.meta { job_meta(found) }
              primary(found)
            end
          end

          def job_meta(found)
            p(class: "jobs-args", title: found.arguments) { found.arguments }
            error(found) if found.error?
            p(class: "li-sub jobs-meta") do
              times(found)
              span { found.queue }
            end
          end

          def jobs_path(**query) = "#{path(:admin_settings_jobs, **query)}##{id}"

          def keys = KEYS.fetch(name)

          def labels = SOONEST_FIRST.include?(name) ? { newer: t(".sooner"), older: t(".later") } : {}

          def more
            return Pager(page: @set.jobs, href: ->(query) { jobs_path(set: name, **query) }, **labels) if @set.all?
            return unless @set.size > @set.jobs.rows.size

            a(class: "jobs-all", href: jobs_path(set: name)) do
              IconLabel(icon: %w[fa-solid fa-arrow-down]) { t(".all", formatted: count(@set.size)) }
            end
          end

          def name = @set.name

          def primary(found)
            act, label = PRIMARY.fetch(name).values_at(:act, :label)

            ButtonForm(
              action: path(:admin_act_on_set_job, set: name, jid: found.jid, act:), label: t(label, name: found.name),
              icon: SetActs::ICONS.fetch(act), icon_only: true, morph: true, hidden: { return_to: request.fullpath },
            )
          end

          def retries(found) = t(".retries", count: found.retries, max: found.max_retries)

          def retry_times(found)
            span(class: "jobs-retrying") { retries(found) }
            stamp(".failed", found.last_failed_at) if found.last_failed_at
            stamp(".next", found.at)
          end

          def stamp(key, at, tone = nil)
            span(class: tone) { Stamped(text: t(key, at: Stamped::MARK), at:, format: :short) }
          end

          def times(found)
            case name
              when "retries" then retry_times(found)
              when "dead"
                stamp(".died", found.at, "jobs-failed")
                span { retries(found) } if found.retries
              else stamp(".runs", found.at)
            end
          end
        end
      end
    end
  end
end
