defmodule AlertsUI.Schema do
  @moduledoc """
  Use in place of Ecto.Schema to automatically have UUID ids as the primary key,
  and set timestamps options.
  """
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @timestamps_opts [type: :utc_datetime, inserted_at: :created_at]
    end
  end
end
