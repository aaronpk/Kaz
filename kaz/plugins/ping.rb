module Bot
  class Ping
    include Cinch::Plugin

    match /^ping$/, use_prefix: false
    def execute(m)
      m.reply "pong"
    end

  end
end