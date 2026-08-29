# frozen_string_literal: true

require "socket"

module Resolver
  PUBLIC = "93.184.216.34"

  def resolves(host, *addresses) = answers(host).and_return(addresses.map { Addrinfo.ip(it) })

  def resolves_publicly(*hosts) = hosts.each { resolves(it, PUBLIC) }

  def resolves_raw(host, *addresses)
    answers(host).and_return(addresses.map { instance_double(Addrinfo, ip_address: it) })
  end

  def unresolvable(host) = answers(host).and_raise(SocketError)

  private

  def answers(host)
    @resolver ||= allow(Addrinfo).to receive(:getaddrinfo).and_call_original

    allow(Addrinfo).to receive(:getaddrinfo).with(host, any_args)
  end
end

RSpec.configure do |config|
  config.include Resolver
end
