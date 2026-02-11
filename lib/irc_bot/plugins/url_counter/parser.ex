defmodule IrcBot.Plugins.UrlCounter.Parser do
  @moduledoc """
  Extracts URLs from IRC message text.

  Supports http and https URLs.
  """

  @url_regex ~r{https?://[^\s<>"]+}i

  @doc "Extracts all URLs from the given text."
  @spec extract_urls(String.t()) :: [String.t()]
  def extract_urls(text) do
    @url_regex
    |> Regex.scan(text)
    |> List.flatten()
  end

  @doc "Extracts the domain (host) from a URL. Returns nil if parsing fails."
  @spec extract_domain(String.t()) :: String.t() | nil
  def extract_domain(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) and host != "" ->
        host
        |> String.downcase()

      _ ->
        nil
    end
  end
end
