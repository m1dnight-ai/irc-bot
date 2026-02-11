defmodule IrcBot.Integration.IrcSmokeTest do
  @moduledoc """
  Integration test that connects to the real ngircd + bot.
  Only runs when ngircd is available on localhost:6667.
  Tag: :integration
  """
  use ExUnit.Case, async: false

  @moduletag :integration

  @host ~c"localhost"
  @port 6667
  @channel "#general"

  setup do
    case :gen_tcp.connect(@host, @port, [:binary, active: false, packet: :line], 2_000) do
      {:ok, sock} ->
        nick = "test#{:rand.uniform(9999)}"
        send_raw(sock, "NICK #{nick}")
        send_raw(sock, "USER #{nick} 0 * :#{nick}")
        assert_welcome(sock)
        send_raw(sock, "JOIN #{@channel}")
        drain_until(sock, "366")
        {:ok, sock: sock, nick: nick}

      {:error, _} ->
        {:ok, skip: true}
    end
  end

  test "echo plugin replies with sender: text", ctx do
    if ctx[:skip], do: flunk("ngircd not running, skipping")

    sock = ctx.sock
    send_raw(sock, "PRIVMSG #{@channel} :,echo integration test")

    reply = recv_privmsg_from(sock, "elixir_bot", 5_000)
    assert reply != nil, "Expected a reply from elixir_bot but got none"
    assert reply =~ "#{ctx.nick}: integration test"
  end

  test "karma plugin prevents self-karma", ctx do
    if ctx[:skip], do: flunk("ngircd not running, skipping")

    sock = ctx.sock
    send_raw(sock, "PRIVMSG #{@channel} :#{ctx.nick}++")

    reply = recv_privmsg_from(sock, "elixir_bot", 5_000)
    assert reply != nil, "Expected a reply from elixir_bot but got none"
    assert reply =~ "can't change your own karma"
  end

  test "karma plugin increments and queries", ctx do
    if ctx[:skip], do: flunk("ngircd not running, skipping")

    sock = ctx.sock

    # Increment someone else's karma
    send_raw(sock, "PRIVMSG #{@channel} :bobtarget++")
    reply = recv_privmsg_from(sock, "elixir_bot", 5_000)
    assert reply =~ "bobtarget now has"

    # Query karma
    send_raw(sock, "PRIVMSG #{@channel} :!karma bobtarget")
    reply = recv_privmsg_from(sock, "elixir_bot", 5_000)
    assert reply =~ "bobtarget has"
  end

  # --- Helpers ---

  defp send_raw(sock, msg) do
    :gen_tcp.send(sock, msg <> "\r\n")
  end

  defp assert_welcome(sock) do
    line = recv_line(sock, 10_000)
    assert line != nil, "No welcome from server"

    if String.contains?(line, " 001 ") do
      :ok
    else
      # Handle PING during login
      if String.starts_with?(line, "PING") do
        token = line |> String.trim() |> String.replace_prefix("PING ", "")
        send_raw(sock, "PONG #{token}")
      end

      assert_welcome(sock)
    end
  end

  defp drain_until(sock, code) do
    line = recv_line(sock, 5_000)

    if line && String.contains?(line, " #{code} ") do
      :ok
    else
      drain_until(sock, code)
    end
  end

  defp recv_privmsg_from(sock, sender, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_recv_privmsg_from(sock, sender, deadline)
  end

  defp do_recv_privmsg_from(sock, sender, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      nil
    else
      case :gen_tcp.recv(sock, 0, remaining) do
        {:ok, line} ->
          line = String.trim(line)

          # Handle PING
          if String.starts_with?(line, "PING") do
            token = String.replace_prefix(line, "PING ", "")
            send_raw(sock, "PONG #{token}")
            do_recv_privmsg_from(sock, sender, deadline)
          else
            case Regex.run(~r/^:(\S+)!\S+ PRIVMSG \S+ :(.*)/, line) do
              [_, ^sender, text] -> text
              _ -> do_recv_privmsg_from(sock, sender, deadline)
            end
          end

        {:error, :timeout} ->
          nil

        {:error, _} ->
          nil
      end
    end
  end

  defp recv_line(sock, timeout) do
    case :gen_tcp.recv(sock, 0, timeout) do
      {:ok, line} -> String.trim(line)
      _ -> nil
    end
  end
end
