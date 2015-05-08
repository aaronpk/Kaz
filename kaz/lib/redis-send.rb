module Bot

  R = Module.new do
    class << self
      extend Forwardable
      def_delegator :redis, :with
      def redis &block
        @redis ||= ConnectionPool.new do
          ::Redis::Namespace.new CONFIG[:irc][:nick], redis: Redis.new(driver: :celluloid)
        end
      end
      def multi &block
        with {|_r| _r.multi {|r| block[r]}}
      end
      def method_missing m, *a
        with {|r| r.__send__ m, *a}
      end
    end
  end

end