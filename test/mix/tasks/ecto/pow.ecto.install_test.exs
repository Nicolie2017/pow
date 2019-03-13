defmodule Mix.Tasks.Pow.Ecto.InstallTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Ecto.Install

  defmodule Repo do
    def __adapter__, do: true
    def config, do: [priv: "", otp_app: :pow]
  end

  @tmp_path Path.join(["tmp", inspect(Install)])
  @options  ["-r", inspect(Repo)]

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates files" do
    File.cd!(@tmp_path, fn ->
      Install.run(@options)

      assert File.ls!("lib/pow/users") == ["user.ex"]
      assert [_one] = File.ls!("migrations")
    end)
  end

  test "generates with schema name and table" do
    options = @options ++ ~w(Organizations.Organization organizations --extension PowResetPassword --extension PowEmailConfirmation)

    File.cd!(@tmp_path, fn ->
      Install.run(options)

      assert File.ls!("lib/pow/organizations") == ["organization.ex"]
      assert [one, two] = Enum.sort(File.ls!("migrations"))
      assert one =~ "_create_organizations.exs"
      assert two =~ "_add_pow_email_confirmation_to_organizations.exs"

      content = File.read!("migrations/#{one}")
      assert content =~ "table(:organizations)"

      content = File.read!("migrations/#{two}")
      assert content =~ "table(:organizations)"
    end)
  end

  test "generates with extensions" do
    options = @options ++ ~w(--extension PowResetPassword --extension PowEmailConfirmation)

    File.cd!(@tmp_path, fn ->
      Install.run(options)

      assert File.ls!("lib/pow/users") == ["user.ex"]
      assert [one, two] = Enum.sort(File.ls!("migrations"))
      assert one =~ "_create_users.exs"
      assert two =~ "_add_pow_email_confirmation_to_users.exs"
    end)
  end

  test "raises error in app with no ecto dep" do
    File.cd!(@tmp_path, fn ->
      File.write!("mix.exs", """
      defmodule MyApp.MixProject do
        use Mix.Project

        def project do
          [
            deps: [
              {:ecto_job, ">= 0.0.0"}
            ]
          ]
        end
      end
      """)

      Mix.Project.in_project(:my_app, ".", fn _ ->
        Mix.Tasks.Deps.Get.run([])

        # Insurance that we do test for top level ecto inclusion
        assert Enum.any?(deps(), fn
          %{app: :phoenix} -> true
          _ -> false
        end), "Ecto not loaded by dependency"

        assert_raise Mix.Error, "mix pow.ecto.install can only be run inside an application directory that has :ecto or :ecto_sql as dependency", fn ->
          Install.run([])
        end
      end)
    end)
  end

  describe "with `:namespace` environment config set" do
    setup do
      Application.put_env(:pow, :namespace, POW)
      on_exit(fn ->
        Application.delete_env(:pow, :namespace)
      end)
    end

    test "uses namespace for context module names" do
      File.cd!(@tmp_path, fn ->
        Install.run(@options)

        assert File.read!("lib/pow/users/user.ex") =~ "defmodule POW.Users.User do"
      end)
    end
  end

  # TODO: Refactor to just use Elixir 1.7 or higher by Pow 1.1.0
  defp deps() do
    case Kernel.function_exported?(Mix.Dep, :load_on_environment, 1) do
     true -> apply(Mix.Dep, :load_on_environment, [[]])
     false -> apply(Mix.Dep, :loaded, [[]])
    end
  end
end
