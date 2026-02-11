defmodule IrcBot.Plugins.UrlCounter.ParserTest do
  use ExUnit.Case, async: true

  alias IrcBot.Plugins.UrlCounter.Parser

  describe "extract_urls/1" do
    test "extracts a single HTTP URL" do
      assert ["http://example.com"] = Parser.extract_urls("check http://example.com out")
    end

    test "extracts a single HTTPS URL" do
      assert ["https://example.com"] = Parser.extract_urls("visit https://example.com")
    end

    test "extracts multiple URLs" do
      text = "see https://foo.com and http://bar.com"
      assert ["https://foo.com", "http://bar.com"] = Parser.extract_urls(text)
    end

    test "extracts URLs with paths and query strings" do
      url = "https://example.com/path?q=hello&lang=en"
      assert [^url] = Parser.extract_urls("link: #{url}")
    end

    test "returns empty list when no URLs" do
      assert [] = Parser.extract_urls("just some text")
    end

    test "ignores non-http protocols" do
      assert [] = Parser.extract_urls("ftp://example.com")
    end

    test "handles URL at start of message" do
      assert ["https://example.com"] = Parser.extract_urls("https://example.com is cool")
    end

    test "handles URL at end of message" do
      assert ["https://example.com"] = Parser.extract_urls("check this https://example.com")
    end
  end

  describe "extract_domain/1" do
    test "extracts domain from HTTPS URL" do
      assert "example.com" = Parser.extract_domain("https://example.com/path")
    end

    test "extracts domain from HTTP URL" do
      assert "example.com" = Parser.extract_domain("http://example.com")
    end

    test "downcases domain" do
      assert "example.com" = Parser.extract_domain("https://EXAMPLE.COM/path")
    end

    test "extracts subdomain" do
      assert "sub.example.com" = Parser.extract_domain("https://sub.example.com")
    end

    test "returns nil for invalid URL" do
      assert nil == Parser.extract_domain("not a url")
    end
  end
end
