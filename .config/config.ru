# frozen_string_literal: true

require "hanami/boot"
require "blog/maintenance"
require "blog/strict_transport"
require "honeybadger/rack/error_notifier"

use Blog::StrictTransport if Hanami.env?(:production)
use Blog::Maintenance, Hanami.app.settings.maintenance[:flag_path]
use Shares::Host, Hanami.app.settings.share_host, Honeybadger::Rack::ErrorNotifier.new(Shares::Slice["server"])

run Hanami.app
