defmodule IrcBot.Plugins.UrlCounter.StoreTest do
  use IrcBot.DataCase, async: false

  alias IrcBot.Plugins.UrlCounter.Store

  describe "record_url/4" do
    test "inserts a URL entry" do
      {:ok, entry} = Store.record_url("https://example.com", "example.com", "alice", "#test")
      assert entry.url == "https://example.com"
      assert entry.domain == "example.com"
      assert entry.nick == "alice"
      assert entry.channel == "#test"
    end
  end

  describe "recent_urls/1" do
    test "returns empty list when no URLs" do
      assert [] = Store.recent_urls()
    end

    test "returns URLs ordered by most recent first" do
      Store.record_url("https://first.com", "first.com", "alice", "#test")
      Store.record_url("https://second.com", "second.com", "bob", "#test")

      urls = Store.recent_urls()
      assert [%{url: "https://second.com"}, %{url: "https://first.com"}] = urls
    end

    test "respects limit" do
      Store.record_url("https://a.com", "a.com", "alice", "#test")
      Store.record_url("https://b.com", "b.com", "bob", "#test")
      Store.record_url("https://c.com", "c.com", "charlie", "#test")

      urls = Store.recent_urls(2)
      assert length(urls) == 2
    end
  end

  describe "top_domains/1" do
    test "returns empty list when no URLs" do
      assert [] = Store.top_domains()
    end

    test "returns domains ordered by count descending" do
      Store.record_url("https://example.com/1", "example.com", "alice", "#test")
      Store.record_url("https://example.com/2", "example.com", "bob", "#test")
      Store.record_url("https://other.com", "other.com", "alice", "#test")

      domains = Store.top_domains()
      assert [{"example.com", 2}, {"other.com", 1}] = domains
    end

    test "respects limit" do
      Store.record_url("https://a.com", "a.com", "alice", "#test")
      Store.record_url("https://b.com", "b.com", "bob", "#test")
      Store.record_url("https://c.com", "c.com", "charlie", "#test")

      domains = Store.top_domains(2)
      assert length(domains) == 2
    end
  end

  describe "total_count/0" do
    test "returns 0 when no URLs" do
      assert 0 = Store.total_count()
    end

    test "returns total number of URLs" do
      Store.record_url("https://a.com", "a.com", "alice", "#test")
      Store.record_url("https://b.com", "b.com", "bob", "#test")

      assert 2 = Store.total_count()
    end
  end
end
