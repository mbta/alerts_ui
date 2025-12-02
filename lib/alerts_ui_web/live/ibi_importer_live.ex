defmodule AlertsUIWeb.IBIImporterLive do
  @moduledoc """
  LV for managing legacy alert imports.
  """
  use AlertsUIWeb, :live_view

  alias AlertsUI.IBIImportWorker

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
      {:ok, _job} -> {:noreply, assign(socket, import_id: id)}
      _ -> nil
    end
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
