# frozen_string_literal: true

require "commonmarker"
require "sanitize"

module Tasks
  module Markdown
    ARIA_LABEL = "aria-label"
    BOX = "input[type='checkbox']"
    CHECKBOX = "checkbox"
    DROPPED_ATTRIBUTES = %w[class id style tabindex].freeze
    IMG = "img"
    INPUT = "input"
    OPTIONS = { extension: { header_ids: nil, tagfilter: false }, render: { hardbreaks: false, unsafe: true } }.freeze
    ITEM_TEXT = "node()[not(self::ul or self::ol)]"
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
        label_boxes(Sanitize.fragment(Commonmarker.to_html(markdown, options: OPTIONS, plugins: PLUGINS), SANITIZE))
      end

      private

      def item_text(box) = box.parent.xpath(ITEM_TEXT).map(&:text).join.split.join(" ")

      def label_boxes(html)
        fragment = Nokogiri::HTML5.fragment(html)
        boxes = fragment.css(BOX)
        return html if boxes.empty?

        boxes.each do |box|
          text = item_text(box)
          box[ARIA_LABEL] = text unless text.empty?
        end
        fragment.to_html
      end
    end
  end
end
