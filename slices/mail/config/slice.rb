# frozen_string_literal: true

module Mail
  class Slice < Hanami::Slice
    config.shared_app_component_keys += %w[honeybadger.agent]

    autoloader.push_dir(Hanami.app.root.join("lib/mail"), namespace: Mail)

    export %w[
      operations.act_on_messages operations.change_thread operations.create_message operations.delete_message
      operations.download_attachment operations.save_draft
      operations.send_mail operations.snooze_messages operations.update_mail_settings operations.wake_message
      repos.message_queries repos.thread_queries
    ]
  end
end
