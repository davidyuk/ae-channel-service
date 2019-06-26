defmodule Signer do
  require Logger

  def sign_transaction(to_sign, authenticator, state, method: method, logstring: logstring) do
    {enc_signed_create_tx, nonce_map} = sign_transaction_perform(to_sign, state, authenticator)
    response = %{jsonrpc: "2.0", method: method, params: %{tx: enc_signed_create_tx}}
    Logger.debug("=>#{inspect(logstring)} : #{inspect(response)} #{inspect(self())}", state.color)
    {response, nonce_map}
  end

  defp sign_transaction_perform(
         to_sign,
         state,
         verify_hook \\ fn _tx, _state -> {:unsecure, nil} end
       ) do
    {:ok, create_bin_tx} = :aeser_api_encoder.safe_decode(:transaction, to_sign)
    # returns #aetx
    tx = :aetx.deserialize_from_binary(create_bin_tx)

    case verify_hook.(tx, state) do
      {:unsecure, nonce_map} ->
        {"", nonce_map}

      {:ok, nonce_map} ->
        # bin = :aetx.serialize_to_binary(tx)
        bin = create_bin_tx
        bin_for_network = <<state.network_id::binary, bin::binary>>
        result_signed = :enacl.sign_detached(bin_for_network, state.priv_key)
        signed_create_tx = :aetx_sign.new(tx, [result_signed])

        {:aeser_api_encoder.encode(
           :transaction,
           :aetx_sign.serialize_to_binary(signed_create_tx)
         ), nonce_map}
    end
  end
end