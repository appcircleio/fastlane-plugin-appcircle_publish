describe Fastlane::Actions::AppcirclePublishAction do
  let(:action) { described_class }

  before do
    action.class_variable_set(:@@apiToken, 'root-token')
    action.class_variable_set(:@@authEndpoint, 'https://auth.example.test')
    action.class_variable_set(:@@apiEndpoint, 'https://api.example.test')
  end

  describe '.ac_switch_sub_organization' do
    it 'keeps the root token when no name is given' do
      expect(AuthService).not_to receive(:switch_to_sub_organization)

      [nil, '', '   '].each { |name| action.ac_switch_sub_organization(name, 'my-pat', nil) }

      expect(action.class_variable_get(:@@apiToken)).to eq('root-token')
    end

    it 'switches to the sub-organization token with the PAT' do
      expect(AuthService).to receive(:switch_to_sub_organization).with(
        root_token: 'root-token', name: 'PlugInTest', pat: 'my-pat',
        auth_endpoint: 'https://auth.example.test', api_endpoint: 'https://api.example.test'
      ).and_return('sub-token')

      action.ac_switch_sub_organization(' PlugInTest ', 'my-pat', nil)

      expect(action.class_variable_get(:@@apiToken)).to eq('sub-token')
    end

    it 'switches to the sub-organization token with the personal access key' do
      expect(AuthService).to receive(:switch_to_sub_organization).with(
        root_token: 'root-token', name: 'PlugInTest', pat: 'my-pak',
        auth_endpoint: 'https://auth.example.test', api_endpoint: 'https://api.example.test'
      ).and_return('sub-token')

      action.ac_switch_sub_organization('PlugInTest', nil, 'my-pak')

      expect(action.class_variable_get(:@@apiToken)).to eq('sub-token')
    end

    it 'fails the lane and keeps no root fallback when the switch fails' do
      message = "Sub-organization 'Missing' could not be found or is not accessible with this token."
      allow(AuthService).to receive(:switch_to_sub_organization).and_raise(RuntimeError, message)

      expect do
        action.ac_switch_sub_organization('Missing', 'my-pat', nil)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, message)
    end
  end

  describe '.available_options' do
    it 'offers an optional subOrganizationName option' do
      option = action.available_options.find { |item| item.key == :subOrganizationName }

      expect(option).not_to be_nil
      expect(option.env_name).to eq('AC_SUB_ORGANIZATION_NAME')
      expect(option.optional).to be(true)
    end
  end

  describe '.run' do
    it 'switches to the sub-organization after login and before the profile lookup' do
      params = {
        personalAPIToken: nil,
        personalAccessKey: 'my-pak',
        subOrganizationName: 'PlugInTest',
        platform: 'ios',
        publishProfile: 'Example Publish Profile',
        upload: false,
        publish: true,
        authEndpoint: 'https://auth.example.test',
        apiEndpoint: 'https://api.example.test'
      }
      expect(action).to receive(:ac_login_with_pak).with('my-pak').ordered
      expect(action).to receive(:ac_switch_sub_organization).with('PlugInTest', nil, 'my-pak').ordered
      expect(PublishUploadService).to receive(:get_publish_profile_id).ordered.and_raise(RuntimeError, 'stop after the profile lookup')

      expect { action.run(params) }.to raise_error(RuntimeError, 'stop after the profile lookup')
    end

    it 'looks up the profile with the sub-organization token after a PAT login' do
      params = {
        personalAPIToken: 'my-pat',
        personalAccessKey: nil,
        subOrganizationName: 'PlugInTest',
        platform: 'ios',
        publishProfile: 'Example Publish Profile',
        upload: false,
        publish: true,
        authEndpoint: 'https://auth.example.test',
        apiEndpoint: 'https://api.example.test'
      }
      expect(action).to receive(:ac_login_with_pat).with('my-pat').ordered
      expect(AuthService).to receive(:switch_to_sub_organization)
        .with(hash_including(root_token: 'root-token', name: 'PlugInTest', pat: 'my-pat')).ordered.and_return('sub-token')
      expect(PublishUploadService).to receive(:get_publish_profile_id)
        .with(hash_including(auth_token: 'sub-token')).ordered.and_raise(RuntimeError, 'stop after the profile lookup')

      expect { action.run(params) }.to raise_error(RuntimeError, 'stop after the profile lookup')
    end

    it 'does not look up the profile when the sub-organization switch fails' do
      params = {
        personalAPIToken: 'my-pat',
        personalAccessKey: nil,
        subOrganizationName: 'Missing',
        platform: 'ios',
        publishProfile: 'Example Publish Profile',
        upload: false,
        publish: true,
        authEndpoint: 'https://auth.example.test',
        apiEndpoint: 'https://api.example.test'
      }
      allow(action).to receive(:ac_login_with_pat)
      allow(AuthService).to receive(:switch_to_sub_organization).and_raise(RuntimeError, 'not found')
      expect(PublishUploadService).not_to receive(:get_publish_profile_id)

      expect { action.run(params) }.to raise_error(FastlaneCore::Interface::FastlaneError, 'not found')
    end

    it 'stops before the login when only one endpoint is self-hosted' do
      params = {
        personalAPIToken: nil,
        personalAccessKey: 'my-pak',
        platform: 'ios',
        publishProfile: 'Example Publish Profile',
        upload: false,
        publish: true,
        authEndpoint: nil,
        apiEndpoint: 'https://api.example.test'
      }
      expect(action).not_to receive(:ac_login_with_pak)

      expect { action.run(params) }.to raise_error(FastlaneCore::Interface::FastlaneError, 'Set both authEndpoint and apiEndpoint for a self-hosted Appcircle server, or leave both empty for the Appcircle cloud.')
    end

    it 'uses the cloud endpoints when the endpoint options are empty' do
      params = {
        personalAPIToken: 'my-pat',
        personalAccessKey: nil,
        platform: 'ios',
        publishProfile: 'Example Publish Profile',
        upload: false,
        publish: true,
        authEndpoint: '',
        apiEndpoint: ' '
      }
      allow(action).to receive(:ac_login_with_pat)
      allow(PublishUploadService).to receive(:get_publish_profile_id).and_raise(RuntimeError, 'stop after the profile lookup')

      expect { action.run(params) }.to raise_error(RuntimeError, 'stop after the profile lookup')
      expect(action.class_variable_get(:@@authEndpoint)).to eq('https://auth.appcircle.io')
      expect(action.class_variable_get(:@@apiEndpoint)).to eq('https://api.appcircle.io')
    end
  end
end
