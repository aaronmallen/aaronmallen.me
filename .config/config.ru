# frozen_string_literal: true

require "hanami/boot"
require "blog/share_host"
require "blog/strict_transport"
require "honeybadger/rack/error_notifier"

use Blog::StrictTransport if Hanami.env?(:production)
use Blog::ShareHost, Hanami.app.settings.share_host, Honeybadger::Rack::ErrorNotifier.new(Shares::Slice["server"])

run Hanami.app
