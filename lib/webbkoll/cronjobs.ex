defmodule Webbkoll.CronJobs do
  require Logger
  alias Webbkoll.Sites

  def find_and_remove_stuck_records do
    Logger.info("Checking for stuck records")
    sites_processing = Sites.get_sites_by(%{status: "processing"})
    max_attempts = Application.get_env(:webbkoll, :max_attempts)

    Enum.each(sites_processing, fn {id, site} ->
      if System.system_time(:microsecond) - site.updated_at > 40_000_000 &&
           site.try_count >= max_attempts do
        Sites.update_site(id, %{
          status: "failed",
          status_message: "Server error on our side."
        })
      end
    end)
  end

  def download_geoip_if_necessary do
    with [] <- Geolix.Database.Loader.loaded_databases() do
      Logger.info("GeoIP DB missing; trying to download.")
      update_geoip()
    end
  end

  def update_geoip do
    db_file = Application.get_env(:geolix, :databases) |> hd |> Map.get(:source)
    db_url = Application.get_env(:webbkoll, :geoip_db_url)
    db_md5_url = Application.get_env(:webbkoll, :geoip_db_md5_url)

    Application.app_dir(:webbkoll, "priv/GeoLite2-Country.mmdb.gz-tmp")
    |> geoip_clean_temp()
    |> geoip_download(db_url)
    |> geoip_check_md5(db_md5_url)
    |> geoip_move_db_file(Application.app_dir(:webbkoll, db_file))

    Geolix.reload_databases()
    Logger.info("GeoIP DB reloaded.")
  end

  defp geoip_clean_temp(tmp_db_path) do
    if File.exists?(tmp_db_path) do
      case File.rm(tmp_db_path) do
        :ok -> tmp_db_path
        {:error, reason} -> raise "GeoIP temp file removal of #{tmp_db_path} failed: #{reason}"
      end
    else
      tmp_db_path
    end
  end

  defp geoip_download(tmp_db_path, url) do
    case Download.from(url, path: tmp_db_path) do
      {:ok, tmp_db_path} ->
        Logger.info("GeoIP database downloaded to #{tmp_db_path}")
        tmp_db_path

      {:error, :unexpected_status_code, reason} ->
        raise "GeoIP DB md5 download failed: #{reason}"

      {:error, reason} ->
        raise "GeoIP database download failed: #{reason}"
    end
  end

  defp geoip_check_md5(tmp_db_path, url) do
    original_md5 =
      case HTTPoison.get(url) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          body

        {:ok, %HTTPoison.Response{status_code: status_code}} ->
          raise "GeoIP DB md5 download failed: #{status_code}"

        {:error, %{reason: reason}} ->
          raise "GeoIP DB md5 download failed: #{reason}"
      end

    actual_md5 =
      tmp_db_path
      |> File.stream!([], 2048)
      |> StreamGzip.gunzip()
      |> Enum.join()
      |> (&:crypto.hash(:md5, &1)).()
      |> Base.encode16()

    case String.upcase(original_md5) == actual_md5 do
      true -> tmp_db_path
      false -> raise "GeoIP DB update failed: mismatched MD5"
    end
  end

  defp geoip_move_db_file(tmp_db_path, new_path) do
    case File.rename(tmp_db_path, new_path) do
      :ok -> Logger.info("New GeoIP DB moved to #{new_path}")
      {:error, reason} -> raise "Failed moving new GeoIP db file: #{reason}"
    end
  end
end
