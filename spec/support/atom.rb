# frozen_string_literal: true

require "nokogiri"

module Spec
  module Atom
    NAMESPACES = { "atom" => "http://www.w3.org/2005/Atom" }.freeze
    SCHEMA = Nokogiri::XML::RelaxNG(File.read(File.join(File.dirname(__FILE__), "schemas", "atom.rng")))
    TIMESTAMP = /(Z|[+-]\d{2}:\d{2})\z/

    AUTHORLESS_ENTRIES = "/atom:feed[not(atom:author)]/atom:entry[not(atom:author)]"
    DATES = "//atom:updated | //atom:published"
    ENTRIES_WITHOUT_LINK_OR_CONTENT = "//atom:entry[not(atom:link[@rel='alternate' or not(@rel)] or atom:content)]"
    IDS = "//atom:id"

    RULES = {
      "an atom:feed has an atom:author unless every atom:entry has one" =>
        ->(doc) { doc.xpath(AUTHORLESS_ENTRIES, NAMESPACES).empty? },
      "every atom:entry has an alternate atom:link or an atom:content" =>
        ->(doc) { doc.xpath(ENTRIES_WITHOUT_LINK_OR_CONTENT, NAMESPACES).empty? },
      "every atom:id is an absolute IRI" =>
        ->(doc) { doc.xpath(IDS, NAMESPACES).all? { URI(it.text).absolute? } },
      "every date has a time zone" =>
        ->(doc) { doc.xpath(DATES, NAMESPACES).all? { TIMESTAMP.match?(it.text) } },
    }.freeze

    def self.errors(xml)
      doc = Nokogiri::XML(xml, &:strict)
      SCHEMA.validate(doc).map(&:message) + RULES.reject { |_, rule| rule.call(doc) }.keys
    rescue Nokogiri::XML::SyntaxError => e
      [e.message]
    end
  end
end

RSpec::Matchers.define :be_valid_atom do
  match { |xml| Spec::Atom.errors(xml).empty? }

  failure_message { |xml| "expected valid Atom, got:\n#{Spec::Atom.errors(xml).join("\n")}" }
end
