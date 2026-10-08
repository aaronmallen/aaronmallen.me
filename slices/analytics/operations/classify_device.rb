# frozen_string_literal: true

module Analytics
  module Operations
    class ClassifyDevice
      APPS = Regexp.union(
        /\bFB(?:AN|AV|_IAB)\b/, /\bInstagram\b/, /\bBarcelona\b/, /\bTwitter/, /\bLinkedInApp\b/, /\bReddit\b/,
        /\bBluesky\b/, /\bMastodon\b/, /\bIvory\b/, /\bIceCubes\b/, /\bTusky\b/, /\bMona\b/, /\bGraysky\b/,
        /\bSkeets\b/, /\bNarwhal\b/, /\bSnapchat\b/,
        /\bPinterest\b/, /\bMicroMessenger\b/, %r{\bLine/}, /\bmusical_ly\b/, /\bBytedanceWebview\b/, %r{\bGSA/},
        /; wv\)/, %r{\((?:iPhone|iPad|iPod)\b(?!.*\bSafari/).*\bAppleWebKit\b},
      )
      TABLETS = Regexp.union(
        /\biPad\b/, /\bTablet\b/i, /\bKindle\b/, %r{\bSilk/}, /\bPlayBook\b/, /\bAndroid\b(?!.*\bMobile\b)/,
      )
      PHONES = Regexp.union(
        /\bMobi/, /\biPhone\b/, /\biPod\b/, /\bAndroid\b/, /\bWindows Phone\b/, /\bBlackBerry\b/, /\bOpera Mini\b/,
      )

      def call(user_agent)
        case user_agent.to_s
          when APPS then Blog::Types::DeviceClass["in-app"]
          when TABLETS then Blog::Types::DeviceClass["tablet"]
          when PHONES then Blog::Types::DeviceClass["mobile"]
          else Blog::Types::DeviceClass["desktop"]
        end
      end
    end
  end
end
