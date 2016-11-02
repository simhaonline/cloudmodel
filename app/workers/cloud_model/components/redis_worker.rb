module CloudModel
  module Components
    class RedisWorker < BaseWorker
      def build build_path
        puts "        Install Redis"

        chroot! build_path, "apt-get install redis-server redis-sentinel -y", "Failed to install Redis"
      end
    end
  end
end




