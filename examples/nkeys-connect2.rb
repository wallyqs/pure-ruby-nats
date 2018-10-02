# Copyright 2016-2018 The NATS Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'nats/io/client'

nats = NATS::IO::Client.new

# Requires the NKEY seed to be able to sign nonces sent by the server.
seed = "SUADZTYQAKTY5NQM7XRB5XR3C24M6ROGZLBZ6P5HJJSSOFUGC5YXOOECOM"
nats.connect(servers: ["nats://127.0.0.1:4222"], nkeys: seed, name: "nats.account", account: 'nats')
puts "Connected to #{nats.connected_server}"

# -----------------------------------------------------------

# Does not work
# nats.subscribe("imports.>") do |msg, reply, subject|

# Does not work
# nats.subscribe("imports.nats.>") do |msg, reply, subject|

# Prefix matches so forwarded
nats.subscribe("imports.nats.synadia.>") do |msg, reply, subject|
  puts "Received on '#{subject} #{reply}': #{msg}"
  nats.publish(reply, "A" * 100) if reply
end

total = 0
payload = 'from nats.io'
loop do
  # nats.publish("hello.#{total}", payload)

  # begin
  #   nats.flush(1)
  # 
  #   # Request which waits until given a response or a timeout
  #   msg = nats.request("hello", "world")
  #   puts "Received on '#{msg.subject} #{msg.reply}': #{msg.data}"
  # 
  # rescue NATS::IO::Timeout
  #   puts "ERROR: flush timeout"
  # end

  total += 1
  sleep 1
end
