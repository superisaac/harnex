defmodule Harnex.TUI.State do
  @moduledoc """
  State for the Harnex terminal interface.
  """

  @type mode :: :fullscreen | :scrollback
  @type status :: :idle | :working | :waiting_for_approval | :completed | :failed
  @type block :: %{kind: atom(), content: iodata(), metadata: map()}
  @type t :: %__MODULE__{
          mode: mode(),
          workspace: String.t(),
          model: String.t(),
          permission: String.t(),
          status: status(),
          blocks: [block()],
          draft: String.t(),
          cursor: non_neg_integer(),
          branch: String.t() | nil,
          session_id: String.t() | nil,
          context_used: non_neg_integer() | nil
        }

  defstruct mode: :fullscreen,
            workspace: ".",
            model: "default",
            permission: "workspace-write + on-request",
            branch: nil,
            status: :idle,
            blocks: [],
            draft: "",
            cursor: 0,
            session_id: nil,
            context_used: nil

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct!(__MODULE__, opts)
  end

  @spec append(t(), atom(), iodata(), map()) :: t()
  def append(state, kind, content, metadata \\ %{}) do
    %{state | blocks: state.blocks ++ [%{kind: kind, content: content, metadata: metadata}]}
  end

  @spec status(t(), status()) :: t()
  def status(state, value), do: %{state | status: value}

  @spec submit(t(), String.t()) :: t()
  def submit(state, prompt) do
    state
    |> append(:user_message, prompt)
    |> Map.put(:draft, "")
    |> status(:working)
  end
end
