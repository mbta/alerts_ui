defmodule Test.Support.Helpers do
  @moduledoc """
  Test helpers
  """

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint AlertsUIWeb.Endpoint

  defmacro reassign_env(app, var, value) do
    quote do
      old_value = Application.get_env(unquote(app), unquote(var))
      Application.put_env(unquote(app), unquote(var), unquote(value))

      on_exit(fn ->
        if old_value == nil do
          Application.delete_env(unquote(app), unquote(var))
        else
          Application.put_env(unquote(app), unquote(var), old_value)
        end
      end)
    end
  end

  defmacro set_log_level(log_level) do
    quote do
      old_log_level = Logger.level()

      on_exit(fn ->
        Logger.configure(level: old_log_level)
      end)

      Logger.configure(level: unquote(log_level))
    end
  end

  def fixture_path(path) do
    fixture_path = Path.expand("./fixtures", __DIR__)
    Path.expand(path, fixture_path)
  end

  # Useful in e2e testing
  def get_to_submission_page(conn, view, mode, effect) do
    view
    |> element("#service_type_buttons button", mode)
    |> render_click()

    {:ok, new_view, _html} =
      view
      |> element("#effect_buttons button", effect)
      |> render_click()
      |> follow_redirect(conn)

    new_view
  end

  def open_review_modal(view) do
    view
    |> element("button#review", "Review and submit")
    |> render_click()
  end

  def submit_alert(view) do
    view
    |> element("#review-modal-container button", "Submit")
    |> render_click()
  end

  def dismiss_prediction_warning(view) do
    view
    |> element("button", "Yes, continue")
    |> render_click()
  end

  def fill_out_form(view, form_section, params) do
    view
    |> element(form_section)
    |> render_change(params)
  end

  def parse_alert_created_output(view) do
    flash = assert_redirect(view, "/")

    alert_id =
      flash["info"]
      |> String.replace("New alert #", "")
      |> String.replace(" created", "")

    AlertsUI.Alerts.get_by_alert_id(alert_id)
  end

  def document_has_element?(document, selector) do
    !(Floki.find(document, selector) |> Enum.empty?())
  end
end
