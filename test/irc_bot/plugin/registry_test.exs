defmodule IrcBot.Plugin.RegistryTest do
  use ExUnit.Case, async: true

  alias IrcBot.IRC.Message
  alias IrcBot.Plugin.Registry

  setup do
    name = :"registry_#{System.unique_integer([:positive])}"
    pid = start_supervised!({Registry, plugins: [IrcBot.TestPlugin], name: name})
    %{registry: pid}
  end

  describe "list_plugins/1" do
    test "returns loaded plugins", %{registry: pid} do
      plugins = Registry.list_plugins(pid)
      assert length(plugins) == 1
      assert hd(plugins).name == "test_plugin"
      assert hd(plugins).description == "A plugin for testing"
      assert hd(plugins).module == IrcBot.TestPlugin
    end
  end

  describe "dispatch/2" do
    test "dispatches matching messages and returns replies", %{registry: pid} do
      message = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "!test")
      replies = Registry.dispatch(message, pid)
      assert [{_, reply}] = replies
      assert reply =~ "Hello alice!"
      assert reply =~ "count: 1"
    end

    test "returns empty list for non-matching messages", %{registry: pid} do
      message = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "hello")
      assert [] = Registry.dispatch(message, pid)
    end

    test "maintains plugin state across dispatches", %{registry: pid} do
      msg = Message.new(type: :privmsg, nick: "bob", channel: "#test", text: "!test")

      Registry.dispatch(msg, pid)
      [{_, reply}] = Registry.dispatch(msg, pid)

      assert reply =~ "count: 2"
    end
  end

  describe "empty plugin list" do
    setup do
      name = :"registry_empty_#{System.unique_integer([:positive])}"
      pid = start_supervised!({Registry, plugins: [], name: name}, id: :empty_registry)
      %{empty_registry: pid}
    end

    test "returns no plugins from list_plugins", %{empty_registry: pid} do
      assert [] = Registry.list_plugins(pid)
    end

    test "returns no replies on dispatch", %{empty_registry: pid} do
      message = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "!test")
      assert [] = Registry.dispatch(message, pid)
    end
  end

  describe "init with failing plugin" do
    defmodule FailPlugin do
      @behaviour IrcBot.Plugin
      def name, do: "fail_plugin"
      def description, do: "Always fails"
      def init(_), do: {:error, :boom}
      def handles?(_), do: false
      def handle_message(_, s), do: {:noreply, s}
    end

    test "skips plugins that fail to init" do
      stop_supervised!(Registry)
      name = :"registry_fail_#{System.unique_integer([:positive])}"
      pid = start_supervised!({Registry, plugins: [FailPlugin], name: name})
      assert [] = Registry.list_plugins(pid)
    end
  end
end
