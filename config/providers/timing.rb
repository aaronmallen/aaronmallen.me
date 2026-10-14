# frozen_string_literal: true

Hanami.app.register_provider :timing do
  start do
    notifications = target["notifications"]
    notifications.register_event(:sql)
    notifications.subscribe(:sql) { Blog::Timer.count(it[:time]) }
  end
end
