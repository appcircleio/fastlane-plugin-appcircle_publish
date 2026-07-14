require 'fastlane/action'
require 'net/http'
require 'uri'
require 'json'

require 'fastlane/action'
require_relative '../helper/appcircle_publish_helper'

require_relative '../helper/auth_service'
require_relative '../helper/upload_service'

module Fastlane
  module Actions
    class AppcirclePublishAction < Action
      @@apiToken = nil
      @@authEndpoint = "https://auth.appcircle.io"
      @@apiEndpoint = "https://api.appcircle.io"

      FLOW_STEP_STATUS = {
        0 => 'Success', 1 => 'Failed', 2 => 'Cancelled', 3 => 'Timeout',
        90 => 'Waiting', 91 => 'Running', 92 => 'Completing', 99 => 'Unknown',
        100 => 'Skipped', 200 => 'Not Started', 201 => 'Stopped',
        202 => 'In Progress', 203 => 'Awaiting Response'
      }.freeze
      TERMINAL_STEP_STATUSES = [0, 1, 2, 3, 100, 201].freeze
      ACTIVE_STEP_STATUSES = [91, 92, 202].freeze

      def self.run(params)
        personalAPIToken = params[:personalAPIToken]
        personalAccessKey = params[:personalAccessKey]
        @@authEndpoint = params[:authEndpoint]
        @@apiEndpoint = params[:apiEndpoint]
        platform = params[:platform] && params[:platform].downcase
        publishProfile = params[:publishProfile]
        appPath = params[:appPath]
        upload = params[:upload]
        publish = params[:publish]

        # --- Validation ---
        if !upload && !publish
          UI.user_error!("Nothing to do: set 'upload' and/or 'publish' to true.")
        end

        if personalAPIToken.nil? && personalAccessKey.nil?
          UI.user_error!("Please provide either Personal API Token (personalAPIToken) or Personal Access Key (personalAccessKey) to authenticate connections to Appcircle services")
        elsif !personalAPIToken.nil? && !personalAccessKey.nil?
          UI.user_error!("Please provide only one authentication method: either Personal API Token (personalAPIToken) or Personal Access Key (personalAccessKey), not both")
        end

        if platform.nil? || (platform != "ios" && platform != "android")
          UI.user_error!("Please provide a valid platform for the Publish profile: 'ios' or 'android'")
        end

        if publishProfile.nil?
          UI.user_error!("Please provide the name of the Publish profile to target")
        end

        if upload
          UI.user_error!("Please specify 'appPath' when 'upload' is true. For iOS use a .ipa file; for Android use a .apk or .aab file") if appPath.nil?
          valid_extensions = ['.apk', '.aab', '.ipa']
          file_extension = File.extname(appPath).downcase
          unless valid_extensions.include?(file_extension)
            raise "Invalid file extension: #{file_extension}. For Android, use .apk or .aab. For iOS, use .ipa."
          end
        end

        # --- Auth + profile ---
        if personalAPIToken.nil?
          self.ac_login_with_pak(personalAccessKey)
        else
          self.ac_login_with_pat(personalAPIToken)
        end

        profileId = PublishUploadService.get_publish_profile_id(auth_token: @@apiToken, platform: platform, profile_name: publishProfile, api_endpoint: @@apiEndpoint)

        # Guard: never start a new publish if one is already running for the profile.
        if publish
          active = PublishUploadService.get_active_publish_count_for_profile(auth_token: @@apiToken, publish_profile_id: profileId, api_endpoint: @@apiEndpoint)
          if active > 0
            UI.user_error!("A publish is already in progress for profile '#{publishProfile}'. Not starting a new one.")
          end
        end

        appVersionId = nil

        # --- Upload ---
        if upload
          response = PublishUploadService.upload_artifact(token: @@apiToken, app: appPath, platform: platform, publish_profile_id: profileId, api_endpoint: @@apiEndpoint)
          self.checkTaskStatus(response["taskId"])
          appVersionId = PublishUploadService.get_latest_app_version_id(auth_token: @@apiToken, platform: platform, publish_profile_id: profileId, api_endpoint: @@apiEndpoint)
          UI.success("#{appPath} uploaded to the Appcircle Publish profile '#{publishProfile}' successfully")
        end

        # --- Publish ---
        if publish
          if upload && appVersionId
            PublishUploadService.mark_release_candidate(auth_token: @@apiToken, platform: platform, publish_profile_id: profileId, app_version_id: appVersionId, api_endpoint: @@apiEndpoint)
            UI.message("Marked the uploaded version as release candidate.")
          else
            appVersionId = PublishUploadService.get_release_candidate_version_id(auth_token: @@apiToken, platform: platform, publish_profile_id: profileId, api_endpoint: @@apiEndpoint)
          end

          publishId = PublishUploadService.get_publish_id(auth_token: @@apiToken, platform: platform, publish_profile_id: profileId, app_version_id: appVersionId, api_endpoint: @@apiEndpoint)
          PublishUploadService.start_publish(auth_token: @@apiToken, platform: platform, publish_profile_id: profileId, publish_id: publishId, api_endpoint: @@apiEndpoint)
          UI.success("Publish flow started for profile '#{publishProfile}'.")
          success = self.poll_publish_status(platform, profileId, appVersionId)
          UI.user_error!("Publish flow failed.") unless success
        end
      end

      def self.ac_login_with_pat(accessToken)
        user = AuthService.get_ac_token(pat: accessToken, auth_endpoint: @@authEndpoint)
        UI.success("Login is successful.")
        @@apiToken = user.accessToken
      rescue StandardError => e
        UI.error("Login failed: #{e.message}")
        raise e
      end

      def self.ac_login_with_pak(personalAccessKey)
        user = AuthService.get_ac_token_with_pak(personal_access_key: personalAccessKey, auth_endpoint: @@authEndpoint)
        UI.success("Login is successful.")
        @@apiToken = user.accessToken
      rescue StandardError => e
        UI.error("Login failed: #{e.message}")
        raise e
      end

      def self.checkTaskStatus(taskId)
        uri = URI.parse("#{@@apiEndpoint}/task/v1/tasks/#{taskId}")

        response = self.send_request(uri, @@apiToken)
        if response.kind_of?(Net::HTTPSuccess)
          stateValue = JSON.parse(response.body)["stateValue"]
          if stateValue == 1
            sleep(1)
            return checkTaskStatus(taskId)
          end
          if stateValue == 3
            return true
          else
            taskStatus = { 0 => "Unknown", 1 => "Begin", 2 => "Canceled", 3 => 'Completed' }
            UI.user_error!("#{taskId} id upload request failed with status #{taskStatus[stateValue]}.")
          end
        else
          UI.user_error!("Upload failed with response code #{response.code} and message '#{response.message}'.")
        end
      end

      # Poll the publish status until it terminates (status 0=success, 1=failed,
      # anything else = running). Logs each step's start / await / terminal once,
      # with status icons.
      def self.poll_publish_status(platform, profileId, appVersionId, interval: 5, max_attempts: 240)
        step_state = {}
        max_attempts.times do
          data = PublishUploadService.get_publish_object(auth_token: @@apiToken, platform: platform, publish_profile_id: profileId, app_version_id: appVersionId, api_endpoint: @@apiEndpoint)
          (data['steps'] || []).each do |step|
            id = step['id'] || step['name']
            next if id.nil?
            st = (step_state[id] ||= {})
            status = step['status']
            if TERMINAL_STEP_STATUSES.include?(status) && !st[:done]
              st[:done] = true
              UI.message("#{step_icon(status)} #{step['name']} — #{step_status_name(status)}")
            elsif status == 203 && !st[:awaiting] && !st[:done]
              st[:awaiting] = true
              UI.message("#{step_icon(status)} #{step['name']} — #{step_status_name(status)}")
            elsif ACTIVE_STEP_STATUSES.include?(status) && !st[:started] && !st[:done]
              st[:started] = true
              UI.message("#{step_icon(status)} #{step['name']} — #{step_status_name(status)}")
            end
          end
          status = data['status'].is_a?(Numeric) ? data['status'] : 99
          return true if status == 0
          return false if status == 1
          sleep(interval)
        end
        UI.user_error!("Publish status polling timed out.")
      end

      def self.step_status_name(status)
        FLOW_STEP_STATUS[status] || "Unknown (#{status})"
      end

      def self.step_icon(status)
        case status
        when 0 then '✅'
        when 1 then '❌'
        when 2 then '🚫'
        when 3 then '⌛'
        when 100 then '⏭️'
        when 201 then '⏹️'
        when 203 then '⏸️'
        else '▶️'
        end
      end

      def self.send_request(uri, access_token)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        request = Net::HTTP::Get.new(uri.request_uri)
        request["Authorization"] = "Bearer #{access_token}"
        http.request(request)
      end

      def self.description
        "Upload a binary to an Appcircle Publish profile and/or trigger its publish flow"
      end

      def self.authors
        ["Burak Yıldırım"]
      end

      def self.return_value
      end

      def self.details
        "Uploads an application binary to an existing Appcircle Publish profile and/or triggers the profile's publish flow. Upload and publish are independent options: enable either or both. When both are enabled, the uploaded version is marked as release candidate and published; a new publish is never started if one is already in progress for the profile."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :personalAPIToken,
                                       env_name: "AC_PERSONAL_API_TOKEN",
                                       description: "Provide Personal API Token to authenticate Appcircle services (use either personalAPIToken or personalAccessKey)",
                                       optional: true,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :personalAccessKey,
                                       env_name: "AC_PERSONAL_ACCESS_KEY",
                                       description: "Provide Personal Access Key to authenticate Appcircle services (use either personalAPIToken or personalAccessKey)",
                                       optional: true,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :authEndpoint,
                                       env_name: "AC_AUTH_ENDPOINT",
                                       description: "Optional: Authentication endpoint URL for self-hosted Appcircle installations. Defaults to the Appcircle cloud",
                                       optional: true,
                                       default_value: "https://auth.appcircle.io",
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :apiEndpoint,
                                       env_name: "AC_API_ENDPOINT",
                                       description: "Optional: API endpoint URL for self-hosted Appcircle installations. Defaults to the Appcircle cloud",
                                       optional: true,
                                       default_value: "https://api.appcircle.io",
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :platform,
                                       env_name: "AC_PLATFORM",
                                       description: "Target platform of the Publish profile: 'ios' or 'android'",
                                       optional: false,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :publishProfile,
                                       env_name: "AC_PUBLISH_PROFILE",
                                       description: "Name of the Publish profile to target. Profile names are unique per platform",
                                       optional: false,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :upload,
                                       env_name: "AC_UPLOAD",
                                       description: "Upload the binary at 'appPath' as a new app version. At least one of 'upload' or 'publish' must be true",
                                       optional: true,
                                       default_value: false,
                                       is_string: false,
                                       type: Boolean),

          FastlaneCore::ConfigItem.new(key: :publish,
                                       env_name: "AC_PUBLISH",
                                       description: "Trigger the profile's publish flow. When combined with upload, the uploaded version is marked release candidate and published; otherwise the profile's current release candidate is published",
                                       optional: true,
                                       default_value: false,
                                       is_string: false,
                                       type: Boolean),

          FastlaneCore::ConfigItem.new(key: :appPath,
                                       env_name: "AC_APP_PATH",
                                       description: "Path to the application file. Required when 'upload' is true. For iOS use a .ipa file; for Android use a .apk or .aab file",
                                       optional: true,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
