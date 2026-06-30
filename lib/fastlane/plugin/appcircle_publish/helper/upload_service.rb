require 'net/http'
require 'uri'
require 'json'
require 'rest-client'

BASE_URL = "https://api.appcircle.io"

module UploadService
  def self.put_with_retry(url, body, headers, max_retries: 5)
    attempt = 0
    delay = 1.0

    begin
      RestClient.put(url, body, headers)
    rescue => e
      status = e.respond_to?(:http_code) ? e.http_code : nil
      retryable = status == 503 ||
                  e.is_a?(RestClient::ServerBrokeConnection) ||
                  e.is_a?(Errno::ECONNRESET) ||
                  (defined?(RestClient::Exceptions::OpenTimeout) && e.is_a?(RestClient::Exceptions::OpenTimeout)) ||
                  (defined?(RestClient::Exceptions::ReadTimeout) && e.is_a?(RestClient::Exceptions::ReadTimeout))

      raise e if !retryable || attempt >= max_retries

      attempt += 1
      sleep(delay + rand(0.3)) # backoff + jitter (0-300ms)
      delay *= 2
      retry
    end
  end

  # Resolve a publish profile id from its name for the given platform.
  # Profile names are unique per (organization, platform), so the match is exact.
  def self.get_publish_profile_id(auth_token:, platform:, profile_name:, api_endpoint: BASE_URL)
    url = "#{api_endpoint}/publish/v2/profiles/#{platform}"
    headers = { Authorization: "Bearer #{auth_token}", accept: 'application/json' }

    profiles = JSON.parse(RestClient.get(url, headers).body)
    profile = (profiles || []).find { |p| p['name'] == profile_name }
    if profile.nil?
      UI.user_error!("Publish profile '#{profile_name}' not found for platform '#{platform}'.")
    end
    profile['id']
  rescue RestClient::ExceptionWithResponse => e
    raise e
  end

  def self.upload_artifact(token:, app:, platform:, publish_profile_id:, api_endpoint: BASE_URL)
    file_path = app
    file_name = File.basename(file_path)
    file_size = File.size(file_path)
    auth_header = { Authorization: "Bearer #{token}", accept: 'application/json' }
    # Profile listing is v2, but the signed-URL upload/commit actions live on v1.
    base = "#{api_endpoint}/publish/v1/profiles/#{platform}/#{publish_profile_id}/app-versions"

    begin
      info_uri = URI(base)
      info_uri.query = URI.encode_www_form({ action: 'uploadInformation', fileName: file_name, fileSize: file_size })
      upload_info = JSON.parse(RestClient.get(info_uri.to_s, auth_header).body)
      file_id = upload_info['fileId']
      upload_url = upload_info['uploadUrl']
      configuration = upload_info['configuration']
      http_method = (configuration && configuration['httpMethod']) ? configuration['httpMethod'].to_s.upcase : 'PUT'

      if http_method == 'POST'
        sign_parameters = configuration['signParameters'] || {}
        payload = {}
        sign_parameters.each { |key, value| payload[key] = value }
        payload['file'] = File.new(file_path, 'rb') # the 'file' field MUST be last
        RestClient.post(upload_url, payload)
      else
        put_with_retry(upload_url, File.binread(file_path), { content_type: 'application/octet-stream' })
      end

      commit_uri = URI(base)
      commit_uri.query = URI.encode_www_form({ action: 'commitFileUpload' })

      commit_payload = { fileId: file_id, fileName: file_name }.to_json
      commit_headers = { Authorization: "Bearer #{token}", content_type: :json, accept: 'application/json' }
      JSON.parse(RestClient.post(commit_uri.to_s, commit_payload, commit_headers).body)
    rescue RestClient::ExceptionWithResponse => e
      raise e
    rescue StandardError => e
      raise e
    end
  end
end
