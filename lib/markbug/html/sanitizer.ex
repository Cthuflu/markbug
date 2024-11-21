defmodule Markbug.HTML.Sanitizer do
  @moduledoc """
  TODO: Sanitizer Behavior/Protocol
  """

  def init(html_state = %{opts: _nil}) do
    %{html_state | opts: %{
        tags: %{
          mode: :allow,
          allowlist: ~w[b i a p u br span div link
                        table thead tbody tfoot th tr td article blockquote caption
                        center col colgroup details figcaption figure optgroup option
                        hr h1 h2 h3 h4 h5 h6 ol ul li strike],
          denylist: ~w[script style iframe object header html head title body footer frame]
        },
        attributes: %{
          mode: :allow,
          allowlist: ~w[class style rel target],
          denylist: []
        }
      }
    }
  end

  def check_tag(%{opts: %{tags: opts}}, tag)  do
    check_mode(opts, tag)
  end

  def check_attribute(%{opts: %{attributes: opts}}, attr) do
    check_mode(opts, attr)
  end

  @compile {:inline, check_mode: 2}
  defp check_mode(opts, check) do
    case opts.mode do
      :allow ->
        check in opts.allowlist

      :deny ->
        check in opts.denylist
    end
    |> if do
      {:ok, check}
    else
      {:error, :not_allowed}
    end
  end

end
