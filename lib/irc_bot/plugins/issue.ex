defmodule IrcBot.Plugins.Issue do
  @moduledoc """
  Creates GitHub issues from IRC using the local Claude CLI.

  Usage: `,issue <description>`
  The bot invokes `claude -p` to generate a well-formatted issue and create it
  on GitHub via `gh issue create`.
  """

  @behaviour IrcBot.Plugin

  alias IrcBot.IRC.Message

  @repo "m1dnight-ai/irc-bot"
  @claude_path "/home/christophe/.local/bin/claude"

  @impl true
  def name, do: "issue"

  @impl true
  def description, do: "Create GitHub issues with ,issue <description>"

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handles?(%{type: :privmsg, text: ",issue " <> _}), do: true
  def handles?(_), do: false

  @impl true
  def handle_message(%{nick: nick, channel: channel, text: ",issue " <> desc}, state) do
    desc = String.trim(desc)

    if desc == "" do
      {:reply, [{channel, "#{nick}: Usage: ,issue <description>"}], state}
    else
      spawn_issue_task(nick, channel, desc)
      {:reply, [{channel, "#{nick}: Creating GitHub issue..."}], state}
    end
  end

  defp spawn_issue_task(nick, channel, description) do
    Task.start(fn ->
      prompt = """
      Create a GitHub issue on #{@repo}.
      This is a feature request from IRC user "#{nick}":

      #{description}

      Use `gh issue create` to create it. Write a concise title and a clear body.
      Add the label "from-irc" if it exists, but don't fail if it doesn't.
      After creating the issue, output ONLY the issue URL on the last line.
      """

      case System.cmd(
             @claude_path,
             [
               "-p",
               "--allowedTools",
               "Bash(gh:*)",
               "--max-turns",
               "5",
               prompt
             ],
             stderr_to_stdout: true,
             cd: System.user_home!(),
             env: [
               {"LANG", "en_US.UTF-8"},
               {"HOME", System.user_home!()},
               {"PATH", "#{System.user_home!()}/.local/bin:/usr/local/bin:/usr/bin:/bin"}
             ]
           ) do
        {output, 0} ->
          url = extract_issue_url(output)
          reply = if url, do: "#{nick}: Issue created: #{url}", else: "#{nick}: Issue created."
          send_async_reply(channel, reply)

        {output, _code} ->
          send_async_reply(channel, "#{nick}: Failed to create issue. #{String.slice(output, 0, 100)}")
      end
    end)
  end

  defp extract_issue_url(output) do
    output
    |> String.split("\n")
    |> Enum.reverse()
    |> Enum.find_value(fn line ->
      case Regex.run(~r{https://github\.com/\S+/issues/\d+}, line) do
        [url] -> url
        _ -> nil
      end
    end)
  end

  defp send_async_reply(channel, text) do
    IrcBot.IRC.Client.send_message(channel, text)

    bot_nick = Application.get_env(:irc_bot, :irc, []) |> Keyword.get(:nick, "elixir_bot")

    message =
      Message.new(
        type: :privmsg,
        nick: bot_nick,
        channel: channel,
        text: text
      )

    IrcBot.IRC.MessageBuffer.push(message)

    Phoenix.PubSub.broadcast(IrcBot.PubSub, "irc:events", %{
      event: :message,
      data: message
    })
  end
end
