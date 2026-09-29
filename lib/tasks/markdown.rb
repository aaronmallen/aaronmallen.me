# frozen_string_literal: true

require "commonmarker"
require "sanitize"

module Tasks
  module Markdown
    CHECKBOX = "checkbox"
    DROPPED_ATTRIBUTES = %w[class id style tabindex].freeze
    IMG = "img"
    INPUT = "input"
    OPTIONS = { extension: { header_ids: nil, tagfilter: false }, render: { hardbreaks: false, unsafe: true } }.freeze
    PLUGINS = { syntax_highlighter: nil }.freeze
    RELAXED = Sanitize::Config::RELAXED

    TASK_BOX = lambda do |env|
      node = env[:node]
      next unless env[:node_name] == INPUT && node["type"] == CHECKBOX && node.key?("disabled")

      { node_allowlist: [node] }
    end

    SANITIZE = Sanitize::Config.freeze_config(
      Sanitize::Config.merge(
        RELAXED,
        elements: RELAXED[:elements] - %w[style] + %w[details],
        transformers: [TASK_BOX],
      ).tap do |config|
        config[:attributes] = config[:attributes].except("style").merge(
          all: RELAXED[:attributes][:all] - DROPPED_ATTRIBUTES,
          IMG => RELAXED[:attributes][IMG] - %w[srcset],
          INPUT => %w[checked disabled type],
        )
      end,
    )

    class << self
      def to_html(markdown)
        Sanitize.fragment(Commonmarker.to_html(markdown, options: OPTIONS, plugins: PLUGINS), SANITIZE)
      end
    end
  end
end
