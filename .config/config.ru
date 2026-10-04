# frozen_string_literal: true

require "hanami/boot"
require "blog/strict_transport"

use Blog::StrictTransport if Hanami.env?(:production)

run Hanami.app
