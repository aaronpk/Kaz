IRC Bot
=======

Redis Interface
---------------

The bot can be controlled by sending messages to the Redis channel it listens on.
By default the bot listens to a channel named "input" with the namespace of its nick
defined in config.yml. This ends up being a string like "BotNick:input" as the redis channel.

### Commands

Commands are sent to the Redis channel as a JSON-encoded string.

#### Global

* `{"type":"join","channel":"#bot"}`
 * The bot will join the channel "#bot"
* `{"type":"part","channel":"#bot"}` or `{"type":"part","channel":"#bot","text":"bye!"}`
 * The bot will part the channel with an optional message
* `{"type":"oper","password":"****"}` or {"type":"oper","password":"****","user":"Bot"}`
 * The bot will attempt to become an oper using the given password and optional username
* `{"type":"mode","mode":"****"}`
 * Sets a mode on the bot
* `{"type":"unset_mode","mode":"****"}`
 * Unsets a mode on the bot
* `{"type":"nick","nick":"NewBot"}`
 * Sets the nick of the bot
* `{"type":"raw","cmd":"TOPIC #channel hello"}`
 * Sends a raw IRC command, useful in case you need to do something that isn't specifically handled here

#### Channel Commands
* `{"type":"text","text":"hello","channel":"#bot"}`
 * The bot will say "hello" in the channel "#bot"
* `{"type":"action","action":"waves","channel":"#bot"}`
 * The bot will send an action "/me waves" to the channel "#bot"
* `{"type":"topic","channel":"#bot","topic":"welcome to the channel"}`
 * Sets the topic for the given channel
* `{"type":"op","channel":"#bot","nick":"someuser"}`
 * The bot grants ops to the specified nick
* `{"type":"deop","channel":"#bot","nick":"someuser"}`
 * The bot de-ops the specified nick
* `{"type":"voice","channel":"#bot","nick":"someuser"}`
 * The bot grants voice to the specified nick
* `{"type":"devoice","channel":"#bot","nick":"someuser"}`
 * The bot de-voices the specified nick
* `{"type":"kick","channel":"#bot","nick":"someuser"}`
 * Kicks the specified nick from the channel

