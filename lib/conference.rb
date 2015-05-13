class ConfHelper

  # Return the SID of the current conference
  # The first time, fetches from Twilio, then caches in the DB
  # Returns a Twilio conference object
  def self.current_conference(db, room)
    begin
      if room[:conference_sid]
        room[:conference_sid]
        conference = TwilioClient.account.conferences.get(room[:conference_sid])
        if conference.status != 'in-progress'
          db[:rooms].where(:id => room[:id]).update(:conference_sid => nil)
          nil
        else
          conference
        end
      else
        conferences = TwilioClient.account.conferences.list(
          :FriendlyName => room[:dial_code],
          :Status => 'in-progress'
        )
        if conferences[0]
          db[:rooms].where(:id => room[:id]).update(:conference_sid => conferences[0].sid)
          conferences[0]
        else
          db[:rooms].where(:id => room[:id]).update(:conference_sid => nil)
          nil
        end
      end
    rescue => e
      e
    end
  end

  # Retrieve a caller record given a name, either a nick or phone ident
  def self.caller_for_name(db, room_id, name)
    caller = db[:callers]
      .where(:room_id => room_id)
      .where(:ident => name)
      .first
    return caller if caller

    caller = db[:callers]
      .where(:room_id => room_id)
      .where(:nick => name)
      .first
    return caller if caller

    return nil
  end

  # Retrieve the room record given a channel name
  def self.room_for_channel(db, m)
    room = db[:rooms]
      .where(:ircserver_id => CONFIG[:irc][:server_id])
      .where(:irc_channel => m.channel.name)
      .first
    if !room
      m.reply "Sorry, I don't see a conference code configured for this IRC channel"
    end
    room
  end

  def self.mute(db, conference, caller_sid)
    begin
      participant = conference.participants.get(caller_sid)
      participant.mute()
      true
    rescue => e
      e
    end
  end

  def self.unmute(db, conference, caller_sid)
    begin
      participant = conference.participants.get(caller_sid)
      participant.unmute()
      true
    rescue => e
      e
    end
  end

end