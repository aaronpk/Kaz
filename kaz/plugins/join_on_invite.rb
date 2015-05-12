module Bot
  class JoinOnInvite
    include Cinch::Plugin

    listen_to :invite
    def listen(m)
      # Works with passworded channels too:
      # /invite Kaz #channel password
      Bot.Channel(m.target).join
    end

  end
end