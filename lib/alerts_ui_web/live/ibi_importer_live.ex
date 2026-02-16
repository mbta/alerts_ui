defmodule AlertsUIWeb.IBIImporterLive do
  @moduledoc """
  LV for managing legacy alert imports.
  """
  use AlertsUIWeb, :live_view

  import Ecto.Query

  alias AlertsUI.IBIAlertImporter.IBIImportWorker
  alias AlertsUI.Models.Alert
  alias AlertsUI.Repo
  alias Ecto.Adapters.SQL
  alias Ecto.Changeset

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("put", _params, socket) do
    {:noreply, assign(socket, put: generate_put_url())}
  end

  @impl true
  def handle_event("get", _params, socket) do
    {:noreply, assign(socket, get: generate_get_url())}
  end

  @impl true
  def handle_event("import", _params, socket) do
    id = Ecto.UUID.generate()

    case IBIImportWorker.new(%{id: id}) |> Oban.insert() do
      {:ok, _job} ->
        Logger.info("[import #{id}] job queued")
        {:noreply, assign(socket, import_id: id)}

      {:error, %Changeset{} = error_changeset} ->
        error_string = inspect(error_changeset.errors)
        Logger.error("[import #{id}] invalid job: #{error_string}")
        {:noreply, assign(socket, import_error: error_string)}

      {:error, error} ->
        error_string = inspect(error)
        Logger.error("[import #{id}] other error: #{error_string}")
        {:noreply, assign(socket, import_error: error_string)}
    end
  end

  @impl true
  def handle_event("wipe", _params, socket) do
    Logger.warning("WIPING IMPORTED ALERTS!")
    SQL.query!(Repo, "TRUNCATE ibi_alerts")
    from(a in Alert, where: a.source == :IBI) |> Repo.delete_all(timeout: :infinity)
    {:noreply, socket}
  end

  def generate_put_url do
    with config <- ExAws.Config.new(:s3),
         bucket <- IBIImportWorker.bucket(),
         filename <- IBIImportWorker.filename(),
         {:ok, url} <- ExAws.S3.presigned_url(config, :put, bucket, filename) do
      url
    else
      {:error, message} -> raise message
    end
  end

  def generate_get_url do
    with config <- ExAws.Config.new(:s3),
         bucket <- IBIImportWorker.bucket(),
         filename <- IBIImportWorker.filename(),
         {:ok, url} <- ExAws.S3.presigned_url(config, :get, bucket, filename) do
      url
    else
      {:error, message} -> raise message
    end
  end
end
