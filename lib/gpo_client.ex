defmodule GPOClient do
  @moduledoc """
  Documentation for GPOClient.
  """

  @bill_types ["hjres", "sjres", "hconres", "sconres", "hres", "sres", "hr", "s"]

  @doc """
  Determine the current congressional session

  ## Examples

      iex> GPOClient.current_session
      {:ok, "115"}
  """
  def current_session do
    case GPOClient.HTTP.get "/smap/bulkdata/BILLSTATUS/sitemapindex.xml" do
      {:ok, %HTTPoison.Response{body: body}} ->
        session =
          Quinn.find(body, :loc)
          |> Enum.map(fn(x) -> Map.get(x, :value) end)
          |> Enum.map(&List.first/1)
          |> Enum.map(fn(x) -> String.split(x, ["BILLSTATUS/"]) end)
          |> Enum.map(&List.last/1)
          |> Enum.map(fn(x) -> String.split(x, @bill_types) end)
          |> Enum.map(&List.first/1)
          |> Enum.max
        {:ok, session}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  List all bills in the provided session

  ## Examples

      iex> GPOClient.bills("114") |> elem(0)
      :ok

      iex> GPOClient.bills("114") |> elem(1) |> List.first
      "114hjres75"
  """
  def bills(session) do
    bills =
      @bill_types
      |> Enum.map(&(Task.async(fn -> bills(session, &1) end)))
      |> Enum.map(&Task.await/1)
      |> Enum.map(fn(x) -> elem(x, 1) end)
      |> List.flatten
    {:ok, bills}
  end

  @doc """
  List all bills of type in the provided session

  ## Examples

      iex> GPOClient.bills("114", "hjres") |> elem(0)
      :ok

      iex> GPOClient.bills("114", "hjres") |> elem(1) |> List.first
      "114hjres75"
  """
  def bills(session, type) do
    case GPOClient.HTTP.get "/smap/bulkdata/BILLSTATUS/#{session}#{type}/sitemap.xml" do
      {:ok, %HTTPoison.Response{body: body}} ->
        session =
          Quinn.find(body, :loc)
          |> Enum.map(fn(x) -> Map.get(x, :value) end)
          |> Enum.map(&List.first/1)
          |> Enum.map(fn(x) -> String.split(x, ["BILLSTATUS-"]) end)
          |> Enum.map(&List.last/1)
          |> Enum.map(fn(x) -> String.split(x, [".xml"]) end)
          |> Enum.map(&List.first/1)
        {:ok, session}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  List all bills with status matching regex
  and of type in the provided session

  ## Examples

      iex> GPOClient.bills("114", "hjres", ~r/law/i)
      {:ok, [%{bill: %{number: "10", session: "114", type: "hjres"}, date: "2015-04-07", text: "Became Public Law No: 114-9."}, %{bill: %{number: "76", session: "114", type: "hjres"}, date: "2015-12-18", text: "Became Public Law No: 114-108."}, %{bill: %{number: "78", session: "114", type: "hjres"}, date: "2015-12-16", text: "Became Public Law No: 114-100."}]}
  """
  def bills(session, type, regex) do
    case bills(session, type) do
      {:ok, bills} -> 
        matching =
          Enum.map(bills, &(Task.async(fn -> bill_latest_action(&1) end)))
          |> Enum.map(&Task.await/1)
          |> Enum.map(fn(x) -> elem(x, 1) end)
          |> Enum.filter(fn(x) -> Map.get(x, :text) |> String.match?(regex) end)
        {:ok, matching}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get details for a bill

  ## Examples

      iex> GPOClient.bill_status("113", "sjres", "11") |> elem(0)
      :ok

      iex> GPOClient.bill_status("113", "sjres", "11") |> elem(1) |> Map.get(:name)
      :billStatus
  """
  def bill_status(session, type, number) do
    url = "/fdsys/bulkdata/BILLSTATUS/#{session}/#{type}/BILLSTATUS-#{session}#{type}#{number}.xml"
    case GPOClient.HTTP.get url do
      {:ok, %HTTPoison.Response{body: body}} ->
        billStatus = Quinn.find(body, :billStatus)
        {:ok, List.first(billStatus)}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Get details for a bill

  ## Examples

      iex> GPOClient.bill_status("113sjres11") |> elem(0)
      :ok

      iex> GPOClient.bill_status("113sjres11") |> elem(1) |> Map.get(:name)
      :billStatus
  """
  def bill_status(id) do
    parsed = parse_bill_id(id)
    bill_status(Map.get(parsed, :session), Map.get(parsed, :type), Map.get(parsed, :number))
  end

  @doc """
  Split bill id into session, type, number

  ## Examples

      iex> GPOClient.parse_bill_id("113sjres11")
      %{ session: "113", type: "sjres", number: "11" }
  """
  def parse_bill_id(id) do
    args =
      @bill_types
      |> Enum.map(fn(x) -> List.insert_at(String.split(id, x), 1, x) end)
      |> Enum.find(fn(x) -> Enum.count(x) > 2 end)
    %{ session: Enum.at(args, 0), type: Enum.at(args, 1), number: Enum.at(args, 2) }
  end

  @doc """
  Get the latest action (conventionally, the status) of a bill

  ## Examples

      iex> GPOClient.bill_latest_action("113sjres11")
      {:ok, %{bill: %{number: "11", session: "113", type: "sjres"}, date: "2013-03-13", text: "Read twice and referred to the Committee on the Judiciary."}}
  """
  def bill_latest_action(id) do
    case bill_status(id) do
      {:ok, status} ->
        action =
          Quinn.find(status, :bill)
          |> List.first
          |> Map.get(:value)
          |> Enum.find(fn(x) -> Map.get(x, :name) == :latestAction end)
          |> Map.get(:value)
        {:ok, %{
          date: Quinn.find(action, :actionDate) |> List.first |> Map.get(:value) |> List.first,
          text: Quinn.find(action, :text) |> List.first |> Map.get(:value) |> List.first,
          bill: Map.put(parse_bill_id(id), :id, id)
        }}
      {:error, reason} ->
        {:error, reason}
    end
  end

end
