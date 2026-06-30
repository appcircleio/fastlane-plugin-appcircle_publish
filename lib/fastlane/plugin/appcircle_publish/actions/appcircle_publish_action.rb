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

      def self.run(params)
        personalAPIToken = params[:personalAPIToken]
        personalAccessKey = params[:personalAccessKey]
        @@authEndpoint = params[:authEndpoint]
        @@apiEndpoint = params[:apiEndpoint]
        platform = params[:platform] && params[:platform].downcase
        publishProfile = params[:publishProfile]
        appPath = params[:appPath]

        valid_extensions = ['.apk', '.aab', '.ipa']

        file_extension = File.extname(appPath).downcase
        unless valid_extensions.include?(file_extension)
          raise "Invalid file extension: #{file_extension}. For Android, use .apk or .aab. For iOS, use .ipa."
        end

        if personalAPIToken.nil? && personalAccessKey.nil?
          UI.user_error!("Please provide either Personal API Token (personalAPIToken) or Personal Access Key (personalAccessKey) to authenticate connections to Appcircle services")
        elsif !personalAPIToken.nil? && !personalAccessKey.nil?
          UI.user_error!("Please provide only one authentication method: either Personal API Token (personalAPIToken) or Personal Access Key (personalAccessKey), not both")
        elsif appPath.nil?
          UI.user_error!("Please specify the path to your application file. For iOS, this can be a .ipa file path. For Android, specify the .apk or .aab file path")
        elsif platform.nil? || (platform != "ios" && platform != "android")
          UI.user_error!("Please provide a valid platform for the Publish profile: 'ios' or 'android'")
        elsif publishProfile.nil?
          UI.user_error!("Please provide the name of the Publish profile to upload the binary to")
        end

        if personalAPIToken.nil?
          self.ac_login_with_pak(personalAccessKey)
        else
          self.ac_login_with_pat(personalAPIToken)
        end
        self.uploadToPublishProfile(platform, publishProfile, appPath)
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
            taskStatus = {
              0 => "Unknown",
              1 => "Begin",
              2 => "Canceled",
              3 => 'Completed'
            }
            UI.user_error!("#{taskId} id upload request failed with status #{taskStatus[stateValue]}.")
          end
        else
          UI.user_error!("Upload failed with response code #{response.code} and message '#{response.message}'.")
        end
      end

      def self.uploadToPublishProfile(platform, publishProfile, appPath)
        profileId = UploadService.get_publish_profile_id(auth_token: @@apiToken, platform: platform, profile_name: publishProfile, api_endpoint: @@apiEndpoint)
        response = UploadService.upload_artifact(token: @@apiToken, app: appPath, platform: platform, publish_profile_id: profileId, api_endpoint: @@apiEndpoint)
        result = self.checkTaskStatus(response["taskId"])

        if result
          UI.success("#{appPath} uploaded to the Appcircle Publish profile '#{publishProfile}' successfully")
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
        "Upload an application binary to an Appcircle Publish profile"
      end

      def self.authors
        ["Burak Yıldırım"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        "Uploads an application binary (.ipa, .apk, or .aab) to an existing Appcircle Publish profile, creating a new app version on the target profile"
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
                                       description: "Name of the Publish profile to upload the binary to. Profile names are unique per platform",
                                       optional: false,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :appPath,
                                       env_name: "AC_APP_PATH",
                                       description: "Specify the path to your application file. For iOS, this can be a .ipa file path. For Android, specify the .apk or .aab file path",
                                       optional: false,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
