# frozen_string_literal: true

require "dry/monads"
require "json"

module MCP
  module Tools
    class Base < Tool
      TAG_SCOPE = {
        type: "string",
        enum: Blog::Types::TagScope.values,
        description: "public holds the tags on posts and projects; private holds those on journal entries and tasks",
      }.freeze
      TEXT = "text"

      extend Dry::Monads[:result]

      class << self
        attr_reader :scope_value

        def scope(value) = @scope_value = value

        private

        def accept_suggestion_edits(server_context) = server_context.fetch(:accept_suggestion_edits)

        def add_work_entry(server_context) = server_context.fetch(:add_work_entry)

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

        def delete_post(server_context) = server_context.fetch(:delete_post)

        def delete_social_post(server_context) = server_context.fetch(:delete_social_post)

        def delete_work_entry(server_context) = server_context.fetch(:delete_work_entry)

        def devices_between(server_context) = server_context.fetch(:devices_between)

        def editable_social_post(server_context) = server_context.fetch(:editable_social_post)

        def every_tag(server_context)
          Blog::Types::TagScope.values.flat_map { all_tags(server_context).call(scope: it) }.sort_by(&:name)
        end

        def every_tag_usage(server_context)
          Blog::Types::TagScope.values.map { tag_usage(server_context).call(scope: it) }.reduce(:merge)
        end

        def hand_over(endpoint, input, server_context, &shape)
          case server_context.fetch(endpoint).call(input)
          in Success(payload) then answer(shape ? yield(payload) : payload)
          in Failure(refusal) then refuse(refusal.message)
          end
        end

        def hourly_between(server_context) = server_context.fetch(:hourly_between)

        def live_projects(server_context) = server_context.fetch(:live_projects)

        def mark_message(server_context) = server_context.fetch(:mark_message)

        def matching_tags(server_context) = server_context.fetch(:matching_tags)

        def message_by_id(server_context) = server_context.fetch(:message_by_id)

        def messages_between(server_context) = server_context.fetch(:messages_between)

        def moderate_webmention(server_context) = server_context.fetch(:moderate_webmention)

        def move_project(server_context) = server_context.fetch(:move_project)

        def navigation_between(server_context) = server_context.fetch(:navigation_between)

        def page(number, server_context) = Blog::Page.new(number:, size: server_context.fetch(:page_size))

        def page_between(server_context) = server_context.fetch(:page_between)

        def post_by_id(server_context) = server_context.fetch(:post_by_id)

        def project_by_id(server_context) = server_context.fetch(:project_by_id)

        def published_post_by_slug(server_context) = server_context.fetch(:published_post_by_slug)

        def queue_commit_import(server_context) = server_context.fetch(:queue_commit_import)

        def reach_between(server_context) = server_context.fetch(:reach_between)

        def read_spread_between(server_context) = server_context.fetch(:read_spread_between)

        def read_throughs_between(server_context) = server_context.fetch(:read_throughs_between)

        def record_links(kind, id, server_context)
          server_context.fetch(:list_links).call(kind:, id:).value!.fetch(:links)
        end

        def refuse(message) = Tool::Response.new([{ type: TEXT, text: message }], error: true)

        def refuse_long_range = refuse(Blog::DayWindow::TOO_LONG)

        def reject_edits(server_context) = server_context.fetch(:reject_edits)

        def remove_tag(server_context) = server_context.fetch(:remove_tag)

        def replace_post_edits(server_context) = server_context.fetch(:replace_post_edits)

        def replace_social_post_edits(server_context) = server_context.fetch(:replace_social_post_edits)

        def restore_project(server_context) = server_context.fetch(:restore_project)

        def save_post(server_context) = server_context.fetch(:save_post)

        def save_post_seo(server_context) = server_context.fetch(:save_post_seo)

        def save_project(server_context) = server_context.fetch(:save_project)

        def save_tag(server_context) = server_context.fetch(:save_tag)

        def scroll_depths_between(server_context) = server_context.fetch(:scroll_depths_between)

        def social_posts_dated_between(server_context) = server_context.fetch(:social_posts_dated_between)

        def sources_between(server_context) = server_context.fetch(:sources_between)

        def suggestion_by_id(server_context) = server_context.fetch(:suggestion_by_id)

        def suggestions_between(server_context) = server_context.fetch(:suggestions_between)

        def sync_failures(server_context) = server_context.fetch(:sync_failures)

        def tag_by_id(server_context) = server_context.fetch(:tag_by_id)

        def tag_usage(server_context) = server_context.fetch(:tag_usage)

        def too_long?(first, last) = Blog::DayWindow.too_long?(first, last)

        def unsent_social_posts(server_context) = server_context.fetch(:unsent_social_posts)

        def update_webmention_settings(server_context) = server_context.fetch(:update_webmention_settings)

        def webmention_settings(server_context) = server_context.fetch(:webmention_settings)

        def weekday_hours(server_context) = server_context.fetch(:weekday_hours)

        def work_entries_between(server_context) = server_context.fetch(:work_entries_between)
      end
    end
  end
end
