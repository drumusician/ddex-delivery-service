defmodule DdexDeliveryService.Workers.ProcessDeliveryWorker do
  @moduledoc """
  Oban worker that processes a DDEX delivery.

  Flow:
  1. Parse XML via DdexDeliveryService.Parser.parse/1
  2. Validate identifiers (ISRC, UPC format)
  3. Map parsed data to Ash resource params
  4. Upsert Artists and Labels (find-or-create by name)
  5. Create Release + Tracks + Deals + TerritoryReleases
  6. Update delivery status -> :completed
  7. PubSub broadcast for real-time UI update
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  alias DdexDeliveryService.Parser
  alias DdexDeliveryService.Ingestion
  alias DdexDeliveryService.Ingestion.Persister

  require Logger

  defp system_actor, do: %DdexDeliveryService.Accounts.SystemActor{}

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"delivery_id" => delivery_id, "xml" => xml, "organization_id" => org_id}
      }) do
    tenant = org_id
    delivery = Ingestion.get_delivery_by_id!(delivery_id, actor: system_actor(), tenant: tenant)

    # Mark as processing
    update_delivery(delivery, %{status: :processing}, tenant)
    broadcast_status(delivery_id, :processing)

    case process(xml, delivery, tenant) do
      {:ok, release} ->
        update_delivery(delivery, %{
          status: :completed,
          completed_at: DateTime.utc_now()
        }, tenant)

        broadcast_status(delivery_id, :completed, %{release_id: release.id})
        :ok

      {:error, reason} ->
        error_msg = format_error(reason)
        Logger.error("Delivery #{delivery_id} failed: #{error_msg}")

        update_delivery(delivery, %{
          status: :failed,
          error_summary: error_msg
        }, tenant)

        broadcast_status(delivery_id, :failed, %{error: error_msg})
        {:error, error_msg}
    end
  end

  defp process(xml, delivery, tenant) do
    with {:ok, version} <- Parser.detect_version(xml),
         _ <- update_delivery(delivery, %{ern_version: version}, tenant),
         _ <- broadcast_status(delivery.id, :detecting_version, %{version: version}),
         {:ok, message} <- Parser.parse(xml, version),
         _ <- broadcast_status(delivery.id, :validating),
         :ok <- validate_message(message, delivery, tenant),
         _ <- broadcast_status(delivery.id, :parsing),
         _ <- broadcast_status(delivery.id, :persisting),
         {:ok, release} <- Persister.persist(message, delivery.id, tenant) do
      {:ok, release}
    end
  end

  defp validate_message(message, delivery, tenant) do
    alias DdexDeliveryService.Parser.Validators.IdentifierValidator

    errors = []

    # Validate main release UPC
    main = Enum.find(message.releases, & &1.is_main_release)

    errors =
      if main && main.icpn && main.icpn != "" && !IdentifierValidator.valid_upc?(main.icpn) do
        create_validation_result(
          delivery,
          :warning,
          "INVALID_UPC",
          "Invalid UPC: #{main.icpn}",
          nil,
          tenant
        )

        [{:warning, "Invalid UPC: #{main.icpn}"} | errors]
      else
        errors
      end

    # Validate ISRCs on sound recordings
    errors =
      Enum.reduce(message.sound_recordings, errors, fn sr, acc ->
        if sr.isrc && sr.isrc != "" && !IdentifierValidator.valid_isrc?(sr.isrc) do
          create_validation_result(
            delivery,
            :warning,
            "INVALID_ISRC",
            "Invalid ISRC: #{sr.isrc}",
            "isrc",
            tenant
          )

          [{:warning, "Invalid ISRC: #{sr.isrc}"} | acc]
        else
          acc
        end
      end)

    # Only block on errors, not warnings
    has_errors = Enum.any?(errors, fn {severity, _} -> severity == :error end)

    if has_errors do
      {:error, "Validation failed with errors"}
    else
      :ok
    end
  end

  defp create_validation_result(delivery, severity, rule_code, message, field_name, tenant) do
    DdexDeliveryService.Ingestion.ValidationResult
    |> Ash.Changeset.for_create(
      :create,
      %{
        delivery_id: delivery.id,
        severity: severity,
        rule_code: rule_code,
        message: message,
        field_name: field_name
      },
      actor: system_actor(),
      tenant: tenant
    )
    |> Ash.create!(actor: system_actor(), tenant: tenant)
  end

  defp update_delivery(delivery, params, tenant) do
    delivery
    |> Ash.Changeset.for_update(:update, params, actor: system_actor(), tenant: tenant)
    |> Ash.update!(actor: system_actor(), tenant: tenant)
  end

  defp broadcast_status(delivery_id, status, extra \\ %{}) do
    Phoenix.PubSub.broadcast(
      DdexDeliveryService.PubSub,
      "delivery:#{delivery_id}",
      {:delivery_status, Map.merge(%{status: status, delivery_id: delivery_id}, extra)}
    )
  end

  defp format_error({:parse_error, reason}), do: "Parse error: #{inspect(reason)}"
  defp format_error({:unsupported_version, v}), do: "Unsupported ERN version: #{v}"
  defp format_error(:unknown_version), do: "Could not detect ERN version"
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
