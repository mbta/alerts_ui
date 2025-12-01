defmodule AlertsUIWeb.IBIImporterLive do
  @moduledoc """
  LV for managing legacy alert imports.
  """
  use AlertsUIWeb, :live_view

  @bucket "mbta-alerts-ui-data-upload"

  @impl true
  def mount(params, _session, socket) do
    {:ok, assign(socket, upload_url: generate_upload_url, params: params)}
  end

  def handle_event("import", _params, socket) do
  end

  def generate_upload_url(filename) do
    with config <- ExAws.Config.new(:s3),
         {:ok, url} <- ExAws.presigned_url(config, :put, @bucket, filename) do
      url
    else
      {:error, message} -> raise message
    end
  end

  def generate_download_url(filename) do
    with config <- ExAws.Config.new(:s3),
         {:ok, url} <- ExAws.presigned_url(config, :get, @bucket, filename) do
      url
    else
      {:error, message} -> raise message
    end
  end
end
