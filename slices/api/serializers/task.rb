# frozen_string_literal: true

module API
  module Serializers
    class Task < Serializer
      attributes :id, :title, :note, :status, :list, :sprint_on, :tags, :links
      attribute :blocked, &:blocked?
      attributes :carried_count, :created_at, :completed_at

      def completed_at(task) = stamp(task.completed_at)

      def created_at(task) = stamp(task.created_at)

      def links(task)
        task.links.map { { label: it.label, id: it.task.id, title: it.task.title, status: it.task.status } }
      end

      def sprint_on(task) = day(params.fetch(:sprint_on) { task.sprint&.sprint_date })

      def tags(task) = task.tags.map(&:name)
    end
  end
end
