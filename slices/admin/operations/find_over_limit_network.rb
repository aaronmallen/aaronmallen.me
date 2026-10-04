# frozen_string_literal: true

module Admin
  module Operations
    class FindOverLimitNetwork
      include Deps[
        link_tagger: "social.links.tagger",
        list_networks: "operations.list_networks",
        mention_directory: "social.queries.mention_directory",
        networks: "social.networks.all",
      ]

      def call(social_post, edit)
        body = part_body(social_post, edit)
        return nil unless body && edit.applies_to?(body)

        over_limit(edit.apply_to(body), social_post.targets.to_a)
      end

      private

      def over_limit(body, targets)
        directory = mention_directory.call([body])

        list_networks.call(selected: targets).find do |network|
          targets.include?(network.name) &&
            !networks.fetch(network.name).within_limit?(sent(directory, body, network.name))
        end
      end

      def part_body(social_post, edit) = social_post.parts.map(&:body)[edit.part_number - 1]

      def sent(directory, body, name) = directory.expand(link_tagger.call(body, name), name).text
    end
  end
end
