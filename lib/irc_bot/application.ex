defmodule IrcBot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        IrcBotWeb.Telemetry,
        IrcBot.Repo,
        {Ecto.Migrator,
         repos: Application.fetch_env!(:irc_bot, :ecto_repos), skip: skip_migrations?()},
        {DNSCluster, query: Application.get_env(:irc_bot, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: IrcBot.PubSub},
        IrcBot.IRC.MessageBuffer,
        IrcBot.Plugin.Registry
      ] ++
        maybe_irc_client() ++
        [IrcBotWeb.Endpoint]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: IrcBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    IrcBotWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end

  defp maybe_irc_client do
    if Application.get_env(:irc_bot, :irc) do
      [IrcBot.IRC.Client]
    else
      []
    end
  end
end
