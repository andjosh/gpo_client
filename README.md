# GPOClient

This package gives a nice client interface for the Goverment Publications Office XML data/sitemaps/bulkdata.

## Usage

~~~elixir
# For example, find all recorded votes for House-originated new laws in 2017
GPOClient.bills("115","hjres", ~r/law/i)
  |> elem(1)
  |> Enum.map(fn(x) -> Map.get(x, :bill) end)
  |> Enum.map(fn(x) -> Map.get(x, :id) end)
  |> Enum.map(&(Task.async(fn -> GPOClient.bill_status(&1) end)))
  |> Enum.map(&Task.await/1)
  |> Enum.map(fn(x) -> elem(x, 1) end)
  |> Quinn.find(:recordedVote)
~~~

## Installation

[Available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `gpo_client` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:gpo_client, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/gpo_client](https://hexdocs.pm/gpo_client).

