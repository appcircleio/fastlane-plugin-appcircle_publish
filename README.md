## Appcircle Publish

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-appcircle_publish)

Upload an application binary (`.ipa`, `.apk`, or `.aab`) directly to an Appcircle **Publish** profile from your Fastlane pipeline. The uploaded binary becomes a new app version on the target Publish profile, ready for the profile's configured app store publishing flow.

Learn more about [Appcircle Publish](https://appcircle.io/publish-to-stores?utm_source=fastlane&utm_medium=plugin&utm_campaign=publish).

## System Requirements

**Compatible Agents:**

- macOS 14.2, 14.5

**Supported Version:**

- Fastlane 2.222.0
- Ruby 3.2.2

Note: Both **Appcircle Cloud** and **self-hosted** Appcircle installations are supported. See [Self-Hosted Appcircle](#self-hosted-appcircle) below to configure custom endpoints.

### Generating/Managing the Personal API Tokens

To generate a Personal API Token:

1. Go to the My Organization screen (second option at the bottom left).
2. Find the Personal API Token section in the top right corner.
3. Press the "Generate Token" button to generate your first token.

![Token Generation](<https://cdn.appcircle.io/docs/assets/image%20(164).png>)

### Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `appcircle_publish`, add it to your project by running:

```bash
fastlane add_plugin appcircle_publish
```

The action uploads a binary to an **existing** Publish profile. Create the Publish profile in Appcircle first, then reference it by name. Publish profile names are unique per platform. After adding the plugin, configure your Fastfile as follows:

```ruby
  lane :upload_to_publish do
    appcircle_publish(
      personalAPIToken: "$(AC_PERSONAL_API_TOKEN)",
      platform: "$(AC_PLATFORM)", # "ios" or "android"
      publishProfile: "$(AC_PUBLISH_PROFILE)",
      appPath: "$(AC_APP_PATH)"
    )
  end
```

- `personalAPIToken` / `personalAccessKey`: The Appcircle Personal API Token (or Personal Access Key) is used to authenticate and secure access to Appcircle services. Provide exactly one of them.
- `platform`: Target platform of the Publish profile. Must be `ios` or `android`.
- `publishProfile`: Name of the Publish profile to upload the binary to. The name is resolved to the profile for the selected platform.
- `appPath`: Indicates the file path to the application that will be uploaded. For iOS use a `.ipa` file; for Android use an `.apk` or `.aab` file.

### Self-Hosted Appcircle

If you run a self-hosted Appcircle installation, point the action to your own endpoints with the optional `authEndpoint` and `apiEndpoint` parameters. Both default to the Appcircle cloud, so existing cloud users do not need to set them.

- `authEndpoint` (optional): Authentication endpoint URL. Defaults to `https://auth.appcircle.io`.
- `apiEndpoint` (optional): API endpoint URL. Defaults to `https://api.appcircle.io`.

```ruby
    appcircle_publish(
      personalAPIToken: "$(AC_PERSONAL_API_TOKEN)",
      platform: "$(AC_PLATFORM)",
      publishProfile: "$(AC_PUBLISH_PROFILE)",
      appPath: "$(AC_APP_PATH)",
      authEndpoint: "https://auth.my-appcircle.example.com",
      apiEndpoint: "https://api.my-appcircle.example.com"
    )
```

**Ensure that this action is added after build steps have been completed.**

> **Self-signed or private CA certificates:** If your self-hosted Appcircle server uses a self-signed certificate (or one issued by a private/internal CA), requests will fail certificate validation. The plugin does not disable TLS verification. Trust the server's CA on the machine running Fastlane — add it to the system certificate store, or point the `SSL_CERT_FILE` environment variable at a PEM bundle that includes it.

### Leveraging Environment Variables

Utilize environment variables seamlessly by substituting the parameters with $(VARIABLE_NAME) in your task inputs. The plugin automatically retrieves values from the specified environment variables within your pipeline.

If you would like to learn more about this plugin and how to utilize it in your projects, please [contact us](https://appcircle.io/contact?utm_source=fastlane&utm_medium=plugin&utm_campaign=publish)

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

### Reference

For more detailed instructions and support, visit the [Appcircle Publish documentation](https://docs.appcircle.io/publish-to-stores-module).
