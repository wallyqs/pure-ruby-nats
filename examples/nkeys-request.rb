require 'nats/io/client'

nats = NATS::IO::Client.new
nats.on_error do |e|
  p e
end

# Requires the NKEY seed to be able to sign nonces sent by the server.
seed = "SUAEL6RU3BSDAFKOHNTEOK5Q6FTM5FTAMWVIKBET6FHPO4JRII3CYELVNM"
nats.connect(servers: ["nats://127.0.0.1:4222"], nkeys: seed, name: "synadia.account", account: 'synadia')
puts "Connected to #{nats.connected_server}"

# -----------------------------------------------------------

nats.subscribe("_SECRET_INBOX") do |msg, reply, subject|
  puts "Received on secret inbox! #{msg}"
  nats.publish(reply, "well done!") if reply
end

nats.subscribe("synadia.requests") do |msg, reply, subject|
  puts "Received on '#{subject} #{reply}': #{msg}"

  # Sending a reply with an inbox, then will cause the server
  # to reserve a small subject route that will never expire.
  # nats.publish(reply, "A", "AAA#{rand(1000)}") if reply

  # Account with the exported service that is imported by another account,
  # could send in the response another reply inbox that the remote can use
  # and that would be translated from account to account.
  nats.publish(reply, "A", "_SECRET_INBOX") if reply

  # These replies will all be discarded.
  # nats.publish(reply, "B", "BBB") if reply
  # nats.publish(reply, "C", "CCC") if reply
end

total = 0
payload = "from synadia"
loop do
  # begin
  #   # Request which waits until given a response or a timeout
  #   msg = nats.request("synadia.requests", "hi from synadia account! n##{total}")
  #   puts "Received on '#{msg.subject} #{msg.reply}': #{msg.data}"
  
  #   total += 1
  # rescue NATS::IO::Timeout
  #   puts "ERROR: timeout"
  # end

  sleep 1
end
