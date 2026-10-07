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

      def archived = exclude(archived_on: nil)

      def in_order = order(self[:id].asc)

      def in_public = where(visibility: Blog::Types::ProjectVisibility["public"])

      def linkable = linkables(title: :name, day: self.class.site_day(:created_at))

      def live = where(archived_on: nil)

      def matching(text) = containing(text, :name, :tagline, :repo)

      def newest_archived_first = order(Sequel.desc(:archived_on, nulls: :last), self[:id].desc)

      def tagged(tag) = join(:tags).where(Sequel[:tags][:name] => tag)

      def tracked = exclude(repo: nil)
    end
  end
end
