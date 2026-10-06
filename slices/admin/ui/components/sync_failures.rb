# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SyncFailures < Component
        prop :failures, Blog::Types::Array.of(Blog::Types::Hash)

        def view_template
          return if @failures.empty?

          div(class: "sync-failures") { @failures.each { failure_line(it) } }
        end

        private

        def failure_line(failure)
          p(class: "sync-failure") do
            Icon("fa-solid fa-triangle-exclamation sync-failure-icon")
            plain line(failure)
          end
        end

        def line(failure) = with_message(failure, reason_line(failure))

        def line_key(failure)
          return failure[:repo] ? ".repo_repeat_line" : ".repeat_line" if repeating?(failure)

          failure[:repo] ? ".repo_line" : ".line"
        end

        def named(key, value) = t(key).fetch(value.to_sym, value.to_s)

        def reason(failure) = named(".reasons", failure[:reason])

        def reason_line(failure)
          return t(".state_line", reason: reason(failure), sync: sync(failure)) unless failure[:at]

          at = l(Blog::TimeZone.local(failure[:at]), format: :medium)
          since = failure[:since] && l(Blog::TimeZone.today(failure[:since]), format: :medium)

          t(line_key(failure), at:, reason: reason(failure), repo: failure[:repo], since:, sync: sync(failure))
        end

        def repeating?(failure) = failure[:count].to_i > 1 && !failure[:since].nil?

        def sync(failure) = named(".syncs", failure[:sync])

        def with_message(failure, line)
          message = failure[:message].to_s
          return line if message.empty?

          t(".message_line", line:, message:)
        end
      end
    end
  end
end
