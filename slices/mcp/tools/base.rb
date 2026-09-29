# frozen_string_literal: true

require "dry/monads"
require "json"

module MCP
  module Tools
    class Base < Tool
      TEXT = "text"

      extend Dry::Monads[:result]

      class << self
        attr_reader :scope_value

        def scope(value) = @scope_value = value

        private

        def accept_suggestion_edits(server_context) = server_context.fetch(:accept_suggestion_edits)

        def activity_between(server_context) = server_context.fetch(:activity_between)

        def activity_commit_totals(server_context) = server_context.fetch(:activity_commit_totals)

        def activity_counts(server_context) = server_context.fetch(:activity_counts)

        def activity_counts_by_month(server_context) = server_context.fetch(:activity_counts_by_month)

        def add_work_entry(server_context) = server_context.fetch(:add_work_entry)

        def all_posts(server_context) = server_context.fetch(:all_posts)

        def all_tags(server_context) = server_context.fetch(:all_tags)

        def analytics_between(server_context) = server_context.fetch(:analytics_between)

        def answer(payload) = Tool::Response.new([{ type: TEXT, text: JSON.generate(payload) }])

        def archive_project(server_context) = server_context.fetch(:archive_project)

        def archived_projects(server_context) = server_context.fetch(:archived_projects)

        def commits_between(server_context) = server_context.fetch(:commits_between)

        def commits_last_synced_at(server_context) = server_context.fetch(:commits_last_synced_at)

        def compose_announcement(server_context) = server_context.fetch(:compose_announcement)

        def compose_social_post(server_context) = server_context.fetch(:compose_social_post)

        def dated_posts(server_context) = server_context.fetch(:dated_posts)

        def days(from, to)
          first = Blog::TimeZone.parse_day(from)
          last = Blog::TimeZone.parse_day(to)
          return Failure("give from and to as days, such as 2026-01-01") unless first && last
          return Failure("from comes after to") if first > last

          Success(first..last)
        end

        def delete_journal_entry(server_context) = server_context.fetch(:delete_journal_entry)

        def delete_post(server_context) = server_context.fetch(:delete_post)

        def delete_social_post(server_context) = server_context.fetch(:delete_social_post)

        def delete_work_entry(server_context) = server_context.fetch(:delete_work_entry)

        def editable_social_post(server_context) = server_context.fetch(:editable_social_post)

        def every_tag(server_context)
          Blog::Types::TagScope.values.flat_map { all_tags(server_context).call(scope: it) }.sort_by(&:name)
        end

        def every_tag_usage(server_context)
          Blog::Types::TagScope.values.map { tag_usage(server_context).call(scope: it) }.reduce(:merge)
        end

        def journal_entries_between(server_context) = server_context.fetch(:journal_entries_between)

        def journal_entry_by_id(server_context) = server_context.fetch(:journal_entry_by_id)

        def live_projects(server_context) = server_context.fetch(:live_projects)

        def mark_message(server_context) = server_context.fetch(:mark_message)

        def message_by_id(server_context) = server_context.fetch(:message_by_id)

        def messages_between(server_context) = server_context.fetch(:messages_between)

        def moderate_webmention(server_context) = server_context.fetch(:moderate_webmention)

        def move_project(server_context) = server_context.fetch(:move_project)

        def post_by_id(server_context) = server_context.fetch(:post_by_id)

        def project_by_id(server_context) = server_context.fetch(:project_by_id)

        def queue_commit_import(server_context) = server_context.fetch(:queue_commit_import)

        def refuse(message) = Tool::Response.new([{ type: TEXT, text: message }], error: true)

        def reject_edits(server_context) = server_context.fetch(:reject_edits)

        def remove_tag(server_context) = server_context.fetch(:remove_tag)

        def replace_post_edits(server_context) = server_context.fetch(:replace_post_edits)

        def replace_social_post_edits(server_context) = server_context.fetch(:replace_social_post_edits)

        def restore_project(server_context) = server_context.fetch(:restore_project)

        def save_journal_entry(server_context) = server_context.fetch(:save_journal_entry)

        def save_post(server_context) = server_context.fetch(:save_post)

        def save_post_seo(server_context) = server_context.fetch(:save_post_seo)

        def save_project(server_context) = server_context.fetch(:save_project)

        def save_tag(server_context) = server_context.fetch(:save_tag)

        def social_posts_dated_between(server_context) = server_context.fetch(:social_posts_dated_between)

        def suggestion_by_id(server_context) = server_context.fetch(:suggestion_by_id)

        def suggestions_between(server_context) = server_context.fetch(:suggestions_between)

        def sync_failures(server_context) = server_context.fetch(:sync_failures)

        def tag_usage(server_context) = server_context.fetch(:tag_usage)

        def unsent_social_posts(server_context) = server_context.fetch(:unsent_social_posts)

        def update_journal_entry(server_context) = server_context.fetch(:update_journal_entry)

        def update_webmention_settings(server_context) = server_context.fetch(:update_webmention_settings)

        def webmention_settings(server_context) = server_context.fetch(:webmention_settings)

        def webmentions_received_in(server_context) = server_context.fetch(:webmentions_received_in)

        def work_entries_between(server_context) = server_context.fetch(:work_entries_between)
      end
    end
  end
end
