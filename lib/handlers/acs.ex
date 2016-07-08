defmodule ACS.Handlers.ACS do
  @moduledoc """
  Handles CWMP requests coming in over the CWMP southbound interface.

  Requests are parsed as SOAP CWMP envelopes and then used for the basis
  of the current provisioning tree. There are several possible request types
  as defined in the TR-069 specification. These are all just handled by
  the custom logic module.

  Some are part of basic ACS functionality and are handled here.

  This is the main ACS server loop corresponding to the old acs3.pm
  """
  require Logger
  use Plug.Builder

  plug Plug.Parsers, parsers: [ACS.CWMP.Parser]
  plug :dispatch

  @encryptor Cryptex.MessageEncryptor.new(
    Cryptex.KeyGenerator.generate(Application.fetch_env!(:acs_ex,:crypt_keybase), Application.fetch_env!(:acs_ex,:crypt_cookie_salt)),
    Cryptex.KeyGenerator.generate(Application.fetch_env!(:acs_ex,:crypt_keybase), Application.fetch_env!(:acs_ex,:crypt_signed_cookie_salt)))

  def dispatch(conn, _params) do
    cookies = fetch_cookies(conn).req_cookies

    did = case Map.has_key?(cookies,"session") do
      false -> Logger.debug("no cookie set in the request - should be an Inform then #{inspect(cookies)}")
        case conn.body_params do
          %{cwmp_version: _cwmp_ver, entries: entries, header: _header} ->
            # Something that was parseable by cwmp_ex.
            case hd(Enum.map(entries,fn(entry) -> if(Map.has_key?(entry,:device_id), do: entry.device_id) end)) do
              nil -> Logger.debug( "Cant find device_id in request nor cookie, bogus!" )
                     %{}
              didstruct -> Logger.debug( "device_id in the body - must be Inform, start session" )
                     extended_deviceid=Map.merge(Map.from_struct(didstruct), %{ip: to_string(:inet_parse.ntoa(conn.remote_ip))})
                     ACS.Session.Supervisor.start_session(extended_deviceid,conn.body_params)
                     extended_deviceid
            end # has device_id
          _ -> # unparseable body and no cookie, bogus
               Logger.debug( "Cant find cwmp output in request nor cookie, bogus!" )
               %{}
        end # conn.body_params
      true ->
        Logger.debug("session cookie in the request, must be decoded into did")
        case Cryptex.MessageEncryptor.decrypt_and_verify(@encryptor,cookies["session"]) do
          {:ok,json} -> case Poison.decode(json,keys: :atoms!) do
            {:ok,decoded_did} -> # check that the IP in the decoded_did is in fact the remote_ip
                                 if decoded_did.ip == to_string(:inet_parse.ntoa(conn.remote_ip)) do
                                   decoded_did
                                 else
                                   %{} # Triggering a 400 Bad Request
                                 end
            {:error,_} -> Logger.debug("Error decoding cookie")
                          %{}
          end # Poison.decode(json)
          _ -> Logger.debug("session cookie decryption failed - send Fault");
               # %{} triggers 400 Bad Request - TODO: maybe Fault instead?
               %{}
        end # Cryptex
    end # fetch_cookies

    {code,resp} = case Map.has_key?(did,:serial_number) do
       true -> Logger.debug( "active session - send message into session" )
               ACS.Session.process_message( did, conn.body_params )
       false -> Logger.debug("cant find device_id anywhere, bogus!")
               {400, "Bad request, no session"}
    end

    if resp == "", do: ACS.Session.Supervisor.end_session(did)

    conn
      |> put_resp_content_type("text/xml")
      |> put_resp_cookie("session",
              Cryptex.MessageEncryptor.encrypt_and_sign(@encryptor,Poison.encode(did)),
              [{:path, '/'}])
      |> send_resp(code,resp)
  end

end
