# frozen_string_literal: true

require "blog/extensions"
require "dry/system/stubs"

module Components
  class ShadowedStub < StandardError; end

  Blog::Extensions.pin(
    self,
    gem: "rspec-mocks",
    version: "3.13.8",
    reason: "the stub guard reads the private RSpec::Mocks::Space#proxies and RootSpace",
    upstream: nil,
  )

  DEPTH = :component_resolve_depth
  private_constant :DEPTH

  module Guard
    def resolve(key, &)
      Components.deeper
      super.tap { Components.refuse_shadowed_stub(key, it) if Components.nested? }
    ensure
      Components.shallower
    end
  end

  def self.deeper = Thread.current[DEPTH] = depth + 1

  def self.depth = Thread.current[DEPTH] || 0

  def self.misses = @misses ||= Hash.new { |containers, container| containers[container] = {} }

  def self.nested? = depth > 1

  def self.owns?(container, key)
    return true if container.registered?(key)
    return false if misses[container].key?(key)

    container.key?(key).tap { misses[container][key] = true unless it }
  end

  def self.refuse_shadowed_stub(key, component)
    return unless shadowed_stub?(component)

    name = key.to_s
    raise ShadowedStub,
          "a spec stubs one #{component.class} and the container just built another for #{name.inspect}. " \
          "Hand the stub to the container with replace_component(#{name.inspect}, ...) so both are one object."
  end

  def self.shadowed_stub?(component)
    space = RSpec::Mocks.space
    return false if space.is_a?(RSpec::Mocks::RootSpace) || component.is_a?(Module) || space.registered?(component)
    unless space.respond_to?(:proxies)
      raise "RSpec::Mocks.space has no proxies, so the stub guard cannot look for a shadowed stub"
    end

    space.proxies.each_value.any? { it.object.instance_of?(component.class) }
  end

  def self.shallower = Thread.current[DEPTH] = depth - 1

  def replace_component(key, value)
    slices.filter_map { holder(it, key) }.each { it.container.stub(key, value) }
  end

  def restore_components
    slices.each do |slice|
      container = slice.container
      container.unstub if container.respond_to?(:unstub)
    end
  end

  private

  def holder(slice, key)
    container = slice.container
    return unless Components.owns?(container, key)

    container.enable_stubs!
    slice[key]
    slice
  end

  def slices = Hanami.app.with_slices.to_a
end

Dry::System::Container.singleton_class.prepend(Components::Guard)

RSpec.configure do |config|
  config.include Components
  config.after { restore_components }
end
