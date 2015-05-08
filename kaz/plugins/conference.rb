module Bot
  class Conference
    include Cinch::Plugin

    # Use a lambda for the prefix so that if the bot nick changes it can still match it
    set :prefix, lambda{|m| Regexp.new("^" + Regexp.escape(m.bot.nick) + "[:,] ")}

    match /hello$/, method: :greet
    def greet(m)
      m.reply "Hello to you, too, #{m.user.nick}."
    end

    match /([^ ]+) is ([^ ]+)$/i, method: :set_user
    def set_user(m, arg)
      puts "SETTING USER #{arg}"
    end

  end
end