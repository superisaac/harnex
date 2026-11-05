defmodule Harnex.SubscriberTest do
  use ExUnit.Case, async: false

  test "invalid subscribers do not crash a run" do
    assert {:ok, %{text: "ok"}} =
             Harnex.run("hello",
               adapter: Harnex.Model.Scripted.new([%{text: "ok"}]),
               subscriber: :invalid_subscriber
             )
  end

  test "subscribe rejects invalid subscribers" do
    assert {:error, :invalid_subscriber} = Harnex.subscribe("missing", :not_a_pid)
  end

  test "unsubscribe rejects invalid subscribers" do
    assert {:error, :invalid_subscriber} = Harnex.unsubscribe("missing", :not_a_pid)
  end

  test "a subscriber that exits does not break the run" do
    subscriber =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    send(subscriber, :stop)

    assert {:ok, %{text: "ok"}} =
             Harnex.run("hello",
               adapter: Harnex.Model.Scripted.new([%{text: "ok"}]),
               subscriber: subscriber
             )
  end
end
