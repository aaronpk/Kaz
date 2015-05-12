class Conference

  # Return the SID of the current conference
  # The first time, fetches from Twilio, then caches in the DB
  # Returns a Twilio conference object
  def self.current_conference(room)
    if room[:conference_sid]
      room[:conference_sid]
      conference = TwilioClient.account.conferences.get(room[:conference_sid])
      if conference.status != 'in-progress'
        DB[:rooms].where(:id => room[:id]).update(:conference_sid => nil)
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
        DB[:rooms].where(:id => room[:id]).update(:conference_sid => conferences[0].sid)
        conferences[0]
      else
        DB[:rooms].where(:id => room[:id]).update(:conference_sid => nil)
        nil
      end
    end
  end

end