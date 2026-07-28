## Appcircle Publish

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-appcircle_publish)

Upload an application binary to an Appcircle **Publish** profile and/or trigger
its publish flow (app store publishing) directly from your Fastlane lane.

Appcircle's **Publish to Stores** module gives you:

- **Centralized Store Publishing:** Manage App Store, Google Play, Huawei AppGallery, and Microsoft Intune releases from a single hub instead of navigating each platform separately.
- **Custom Publish Flows:** Automate your release cycle with repeatable publish flows and ready-to-use integrations tailored to your organization's needs.
- **Approval Gates:** Add manual approval steps to your publish flow to keep every release under control before it goes live.
- **Auto Re-sign:** Automatically apply updated signing credentials and versioning to uploaded binaries, keeping releases properly signed without a new build.
- **Audit and Reporting:** Track every publishing step with audit trails and publish reports for full transparency and compliance.

Learn more about [Appcircle Publish to Stores](https://appcircle.io/publish-to-stores?utm_source=fastlane&utm_medium=plugin&utm_campaign=publish).

## System Requirements

**Compatible Agents:**

- macOS 14.2, 14.5

**Supported Version:**

- Fastlane 2.222.0
- Ruby 3.2.2

Note: Both **Appcircle Cloud** and **self-hosted** Appcircle installations are supported. See [Self-Hosted Appcircle](#self-hosted-appcircle) below to configure custom endpoints.

### Generating/Managing the Personal API Tokens

To generate a Personal API Token:

1. Open the **My Organization** screen from your profile avatar at the bottom left.
2. Go to the **Security** section and find the **Personal Access Key** card.
3. Press **Generate Key** to generate your token.

![Token Generation](https://raw.githubusercontent.com/appcircleio/fastlane-plugin-appcircle_publish/main/images/PAT.png)

## What the action does

The action has two independent switches, `upload` and `publish`, both default
to `false`. **You must enable at least one.** Create the Publish profile in
Appcircle first; the action targets it by name (profile names are unique per
platform).

| `upload` | `publish` | Behavior |
|:--------:|:---------:|----------|
| `true`  | `false` | Upload `appPath` as a new app version on the profile. |
| `false` | `true`  | Trigger the publish flow for the profile's **current release candidate**. |
| `true`  | `true`  | Upload `appPath`, **mark the new version as release candidate**, then trigger the publish flow for it. |
| `false` | `false` | Error: nothing to do. |

**Rules:**

- **In-progress guard:** if a publish is already running for the target profile, the action does **not** start a new one and fails fast.
- **Release candidate:** when both `upload` and `publish` are `true`, the freshly uploaded version is automatically marked as the release candidate before it is published. In publish-only mode, the profile's existing release candidate is published.
- **Progress:** while publishing, the action polls the publish status and prints step-by-step progress (with status icons) until the flow succeeds or fails.

> **Manual-approval steps:** if the profile's publish flow contains a manual step (e.g. "Get Approval via Email"), the flow waits for that action and the plugin keeps polling until it completes or the poll times out. For CI use, prefer publish flows without manual gates.

### Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `appcircle_publish`, add it to your project by running:

```bash
fastlane add_plugin appcircle_publish
```

**Upload only:**

```ruby
  lane :upload_to_publish do
    appcircle_publish(
      personalAPIToken: "$(AC_PERSONAL_API_TOKEN)",
      platform: "$(AC_PLATFORM)", # "ios" or "android"
      publishProfile: "$(AC_PUBLISH_PROFILE)",
      upload: true,
      appPath: "$(AC_APP_PATH)"
    )
  end
```

**Publish only (publishes the profile's current release candidate):**

```ruby
  lane :trigger_publish do
    appcircle_publish(
      personalAPIToken: "$(AC_PERSONAL_API_TOKEN)",
      platform: "$(AC_PLATFORM)",
      publishProfile: "$(AC_PUBLISH_PROFILE)",
      publish: true
    )
  end
```

**Upload and publish (uploads, marks it release candidate, then publishes):**

```ruby
  lane :upload_and_publish do
    appcircle_publish(
      personalAPIToken: "$(AC_PERSONAL_API_TOKEN)",
      platform: "$(AC_PLATFORM)",
      publishProfile: "$(AC_PUBLISH_PROFILE)",
      upload: true,
      publish: true,
      appPath: "$(AC_APP_PATH)"
    )
  end
```

- `personalAPIToken` / `personalAccessKey`: Provide exactly one to authenticate with Appcircle services. Providing both, or neither, fails with a descriptive error.
- `platform`: Target platform of the Publish profile: `ios` or `android`.
- `publishProfile`: Name of the Publish profile to target.
- `upload` (default `false`): Upload `appPath` as a new app version.
- `publish` (default `false`): Trigger the profile's publish flow.
- `appPath`: Path to the application file. Required when `upload` is `true`. For iOS use a `.ipa` file; for Android use a `.apk` or `.aab` file.

### Self-Hosted Appcircle

If you run a self-hosted Appcircle installation, point the action to your own endpoints with the optional `authEndpoint` and `apiEndpoint` parameters. Both default to the Appcircle cloud, so existing cloud users do not need to set them.

- `authEndpoint` (optional): Authentication endpoint URL. Defaults to `https://auth.appcircle.io`.
- `apiEndpoint` (optional): API endpoint URL. Defaults to `https://api.appcircle.io`.

```ruby
    appcircle_publish(
      personalAPIToken: "$(AC_PERSONAL_API_TOKEN)",
      platform: "$(AC_PLATFORM)",
      publishProfile: "$(AC_PUBLISH_PROFILE)",
      publish: true,
      authEndpoint: "https://auth.my-appcircle.example.com",
      apiEndpoint: "https://api.my-appcircle.example.com"
    )
```

> **Self-signed or private CA certificates:** If your self-hosted Appcircle server uses a self-signed certificate (or one issued by a private/internal CA), requests will fail certificate validation. The plugin does not disable TLS verification. Trust the server's CA on the machine running Fastlane: add it to the system certificate store, or point the `SSL_CERT_FILE` environment variable at a PEM bundle that includes it.

### Leveraging Environment Variables

Utilize environment variables seamlessly by substituting the parameters with $(VARIABLE_NAME) in your task inputs. The plugin automatically retrieves values from the specified environment variables within your pipeline.

If you would like to learn more about this plugin and how to utilize it in your projects, please [contact us](https://appcircle.io/contact?utm_source=fastlane&utm_medium=plugin&utm_campaign=publish)

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

### Reference

For more detailed instructions and support, visit the [Appcircle Publish to Stores documentation](https://docs.appcircle.io/marketplace/fastlane/publish-to-stores).
