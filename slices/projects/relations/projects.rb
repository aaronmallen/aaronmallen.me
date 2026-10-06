# frozen_string_literal: true

module Projects
  module Relations
    class Projects < Blog::DB::Relation
      schema :projects, infer: true do
        associations do
          has_many :project_tags
          has_many :tags, through: :project_tags, view: :in_name_order
        end
      end

      def archived = with_status(Blog::Types::ProjectStatus["archived"])

      def featured_first = order(self[:featured].desc, self[:position].asc, self[:id].asc)

      def in_order = order(self[:position].asc, self[:id].asc)

      def last_position = unordered.max(:position).to_i

      def linkable = linkables(title: :name, day: self.class.site_day(:created_at))

      def live = exclude(status: Blog::Types::ProjectStatus["archived"])

      def matching(text) = containing(text, :name, :tagline, :repo)

      def newest_archived_first = order(Sequel.desc(:archived_on, nulls: :last), self[:id].desc)

      def tagged(tag) = join(:tags).where(Sequel[:tags][:name] => tag)

      def tracked = exclude(repo: nil)

      def with_status(status) = where(status:)
    end
  end
end
