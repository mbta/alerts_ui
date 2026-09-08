defmodule AlertsUI.Trapeze.SFTPTest do
  @moduledoc false
  alias AlertsUI.Trapeze.SFTP
  use AlertsUI.DataCase, async: false

  import Mock
  import Test.Support.Helpers

  test "source_description/1" do
    with_mock(AlertsUI, [:passthrough], config: fn a -> Atom.to_string(a) end) do
      assert %{
               host: "trapeze_sftp_host",
               port: 34,
               user: "trapeze_sftp_user",
               password: "trapeze_sftp_password",
               filename: "trapeze_sftp_filename"
             } =
               SFTP.source_description(%{
                 port: 34
               })
    end
  end

  test "turns Trapeze lines into WorkOrders" do
    with_mock(SFTPClient,
      connect: fn _args, connfn -> connfn.(:conn) end,
      stream_file!: fn conn, filename ->
        conn == :conn && ["#{filename}\r\n", "line2\r\nline3\r\n"]
      end,
      file_info!: fn _, _ -> %{mtime: {{2026, 2, 14}, {12, 0, 0}}} end
    ) do
      output =
        SFTP.fetch(%{
          filename: "FILENAME",
          host: "test.host",
          port: 44,
          user: "USER",
          password: "PASSWORD"
        })

      assert output == {["FILENAME", "line2", "line3"], ~N[2026-02-14T12:00:00]}
    end
  end

  describe "configuration" do
    setup do
      reassign_env(:alerts_ui, :trapeze_sftp_host, "test.host")
      reassign_env(:alerts_ui, :trapeze_sftp_port, "1234")
      reassign_env(:alerts_ui, :trapeze_sftp_user, "sftp-user")
      reassign_env(:alerts_ui, :trapeze_sftp_password, "rEaL_pAsSwOrD!")
      reassign_env(:alerts_ui, :trapeze_sftp_filename, "/path/to/file.data")
    end

    test "host" do
      assert SFTP.host() == "test.host"
    end

    test "port" do
      assert SFTP.port() == 1234
    end

    test "user" do
      assert SFTP.user() == "sftp-user"
    end

    test "password" do
      assert SFTP.password() == "rEaL_pAsSwOrD!"
    end

    test "filename" do
      assert SFTP.filename() == "/path/to/file.data"
    end
  end
end
