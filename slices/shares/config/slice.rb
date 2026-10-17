# frozen_string_literal: true

module Shares
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/shares"), namespace: Shares)

    config.shared_app_component_keys += %w[honeybadger.agent page_fetcher.link_title share_store.client]

    export %w[
      operations.add_share_group_files operations.add_shares_to_group operations.check_short_links
      operations.create_short_link operations.delete_share operations.delete_share_group operations.delete_short_link
      operations.group_shares operations.name_share_group operations.queue_short_link_check
      operations.remove_share_group_file operations.rename_share_file operations.save_share operations.save_share_group
      operations.save_short_link operations.shorten_link operations.ungroup_share_file operations.upload_share
      operations.upload_share_group
      repos.share_group_queries repos.share_queries repos.short_link_queries
    ]
  end
end
