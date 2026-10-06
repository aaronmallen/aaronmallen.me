# auto_register: false
# frozen_string_literal: true

module API
  class Serializer < Blog::Serializer
    COMPONENTS = "#/components/schemas/"
    TIME_FORMAT = "%H:%M"

    def self.component = name.split("::").last

    def self.reference = { "$ref": "#{COMPONENTS}#{component}" }

    def self.schema_attributes = attributes(*self::SCHEMA.fetch(:properties).keys)

    def self.stamps(*names, **sources)
      names.to_h { [it, it] }.merge(sources).each do |name, source|
        define_method(name) { |record| stamp(record.public_send(source)) }
      end
    end

    def self.tag_names = define_method(:tags) { |record| tag_names(record) }

    private

    def clock(time) = time.strftime(TIME_FORMAT)

    def tag_names(record) = record.tags.map(&:name)
  end
end
