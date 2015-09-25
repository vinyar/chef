require 'openssl'
class Chef
  class Util
    class FIPS
      def self.disable(&block)
        if Chef::Config.fips_mode
          OpenSSL.fips_mode = false
          val = block.call
          OpenSSL.fips_mode = true
          val
        else
          block.call
        end
      end
    end
  end
end
