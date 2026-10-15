# frozen_string_literal: true

RSpec.describe Shares::Transfers do
  def places(...)
    open = transfers(...)
    Array.new(10) { open.call { [200, {}, []] }.first }.count(200)
  end

  def transfers(cap: nil, web_threads: 5)
    values = { share_site: { transfers: cap, url: "https://aa.cool" }, web_threads: }
    store = Hanami::Settings::CompositeStore.new(values, Hanami.app.config.settings_store)
    described_class.new(Blog::Settings.new(store))
  end

  it "leaves two threads free when unset" do
    expect(places).to eq(3)
  end

  it "keeps one place when the threads leave none" do
    expect(places(web_threads: 2)).to eq(1)
  end

  it "takes the setting when set" do
    expect(places(cap: 4)).to eq(4)
  end

  it "frees a place when the body closes" do
    open = transfers(cap: 1)
    open.call { [200, {}, []] }.last.close

    expect(open.call { [200, {}, []] }.first).to eq(200)
  end

  it "frees a place when the response raises", :aggregate_failures do
    open = transfers(cap: 1)

    expect { open.call { raise "store down" } }.to raise_error("store down")
    expect(open.call { [200, {}, []] }.first).to eq(200)
  end
end
