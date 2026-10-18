# frozen_string_literal: true

require "zeitwerk"

module Issues
  Zeitwerk::Loader.new.tap do |loader|
    loader.push_dir("#{__dir__}/issues", namespace: self)
    loader.setup
  end

  GITHUB_URL = %r{\Ahttps://github\.com/(?<repo>[^/]+/[^/]+)/issues/(?<number>\d+)\z}
  LINEAR_URL = %r{\Ahttps://linear\.app/(?<workspace>[^/]+)/issue/(?<team>[^/]+)-\d+(?:/|\z)}
end
