describe Fastlane::Actions::AppcirclePublishAction do
  describe '#run' do
    context 'when personalAPIToken and personalAccessKey are both nil' do
      it 'raises an error for missing authentication' do
        params = {
          personalAPIToken: nil,
          personalAccessKey: nil,
          platform: 'ios',
          publishProfile: 'My Profile',
          appPath: 'test.ipa'
        }

        expect do
          Fastlane::Actions::AppcirclePublishAction.run(params)
        end.to raise_error(FastlaneCore::Interface::FastlaneError)
      end
    end

    context 'when both personalAPIToken and personalAccessKey are provided' do
      it 'raises an error for multiple authentication methods' do
        params = {
          personalAPIToken: 'test_token',
          personalAccessKey: 'test_key',
          platform: 'ios',
          publishProfile: 'My Profile',
          appPath: 'test.ipa'
        }

        expect do
          Fastlane::Actions::AppcirclePublishAction.run(params)
        end.to raise_error(FastlaneCore::Interface::FastlaneError)
      end
    end

    context 'when appPath has invalid extension' do
      it 'raises an error for invalid file extension' do
        params = {
          personalAPIToken: 'test_token',
          personalAccessKey: nil,
          platform: 'ios',
          publishProfile: 'My Profile',
          appPath: 'test.txt'
        }

        expect do
          Fastlane::Actions::AppcirclePublishAction.run(params)
        end.to raise_error(RuntimeError, /Invalid file extension/)
      end
    end

    context 'when platform is invalid' do
      it 'raises an error for invalid platform' do
        params = {
          personalAPIToken: 'test_token',
          personalAccessKey: nil,
          platform: 'windows',
          publishProfile: 'My Profile',
          appPath: 'test.ipa'
        }

        expect do
          Fastlane::Actions::AppcirclePublishAction.run(params)
        end.to raise_error(FastlaneCore::Interface::FastlaneError)
      end
    end

    context 'when publishProfile is missing' do
      it 'raises an error for missing publish profile' do
        params = {
          personalAPIToken: 'test_token',
          personalAccessKey: nil,
          platform: 'ios',
          publishProfile: nil,
          appPath: 'test.ipa'
        }

        expect do
          Fastlane::Actions::AppcirclePublishAction.run(params)
        end.to raise_error(FastlaneCore::Interface::FastlaneError)
      end
    end
  end

  describe '.description' do
    it 'returns a description' do
      expect(Fastlane::Actions::AppcirclePublishAction.description).to eq("Upload an application binary to an Appcircle Publish profile")
    end
  end

  describe '.authors' do
    it 'returns the authors' do
      expect(Fastlane::Actions::AppcirclePublishAction.authors).to eq(["Burak Yıldırım"])
    end
  end

  describe '.is_supported?' do
    it 'returns true for all platforms' do
      expect(Fastlane::Actions::AppcirclePublishAction.is_supported?(:ios)).to be true
      expect(Fastlane::Actions::AppcirclePublishAction.is_supported?(:android)).to be true
    end
  end

  describe '.available_options' do
    it 'returns available options' do
      options = Fastlane::Actions::AppcirclePublishAction.available_options
      expect(options).not_to be_empty
      expect(options.map(&:key)).to include(:personalAPIToken, :personalAccessKey, :platform, :publishProfile, :appPath)
    end
  end
end
