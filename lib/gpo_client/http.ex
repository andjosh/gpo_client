defmodule GPOClient.HTTP do
  use HTTPoison.Base
  @moduledoc """
  Documentation for GPOClient.HTTP
  """

  @base_url "https://www.gpo.gov"

  def process_url(url) do
    @base_url <> url
  end

  def process_response_body(body) do
    body
    |> Quinn.parse
  end
end
