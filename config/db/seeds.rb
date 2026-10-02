# frozen_string_literal: true

Dir.glob(File.expand_path("seeds/#{Hanami.env}/**/*.rb", __dir__)).each { |seed| load seed }
