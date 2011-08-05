#!/usr/bin/env ruby

# Copyright (c) 2005, 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'socket'
require 'optparse'
require 'digest'

OPTIONS = {
	:Host => nil,
	:Port => 30000,
	:RunAs => nil
}

ARGV.options do |o|
	script_name = File.basename($0)

	o.set_summary_indent('  ')
	o.banner = "Usage: #{script_name} [options]"
	o.define_head "A simple UDP network tester. Start a server somewhere, and then use the client to connect.\nThis will continually send packets through the network and stop when an error is detected."

	o.on("--server [port]", String, "Start a server on port (default 30000)") do |port|
		OPTIONS[:RunAs] = :server
		OPTIONS[:Port] = port || OPTIONS[:Port]
	end

	o.on("--client [hostname]", String, "Start a client connecting to the hostname specified.") do |hostname|
		OPTIONS[:RunAs] = :client
		host, port = hostname.split(":")

		OPTIONS[:Port] = port || OPTIONS[:Port]
		OPTIONS[:Host] = host || OPTIONS[:Host]
	end
end.parse!

$stdout.sync = true

def seq_digest s
	return Digest::MD5.hexdigest(s.to_s)
end

class UDPServer
	def initialize(port)
		@port = port
		@clients = {}
	end

	def start
		puts "Server starting on port #{@port.inspect}"

		@socket = UDPSocket.new
		@socket.bind(0, @port)

		while true
			packet, addr = @socket.recvfrom(1024)

			$stdout.write("+")

			# Decode the information
			packet = Marshal.load(packet)

			if packet[0] == "BEGIN"
			  puts
				puts "New connection from #{addr.inspect}"

				@clients[addr] = {:seq => packet[1].to_i}
				cmd = ["OKAY", packet[1]]
				@socket.send(Marshal.dump(cmd), 0, addr[3], addr[1])
			elsif packet[0] == "CHECK"
				cksum = seq_digest(@clients[addr][:seq])

				cmd = nil
				if cksum != packet[1]
					$stderr.puts "Checksum sequence mismatch from client #{addr.inspect}: #{packet[1].dump} != #{cksum.dump}"
					cmd = ["ERROR", @clients[addr][:seq]]
				else
					@clients[addr][:seq] += 1
					cksum = seq_digest(@clients[addr][:seq])
					cmd = ["NEXT", cksum]
				end

				@socket.send(Marshal.dump(cmd), 0, addr[3], addr[1])
			end
		end
	end
end

class UDPClient
	def initialize(host, port)
		@host = host
		@port = port
		@seq = (rand * 1024).to_i
	end

	def start
		@socket = UDPSocket.open
		@socket.connect(@host, @port)

		send_sequence_begin

		cksum_next = seq_digest(@seq)
		while true
			cksum = cksum_next
			cmd = ["CHECK", cksum]
			@socket.send(Marshal.dump(cmd), 0)

			packet, addr = @socket.recvfrom(1024)
			packet = Marshal.load(packet)

			cksum_next = seq_digest(@seq + 1)
			if (packet[0] == "NEXT" && packet[1] == cksum_next)
				@seq += 1
				$stdout.write("+")
			else
				$stderr.puts "Error communicating with server: #{cksum} != #{packet[1]}"
				exit(2)
			end

			sleep 0.25
		end
	end

	private
	def send_sequence_begin
		cmd = ["BEGIN", @seq]

		@socket.send(Marshal.dump(cmd), 0)
		packet, addr = @socket.recvfrom(1024)
		packet = Marshal.load(packet)

		if (packet == ["OKAY", @seq])
			puts "Connection okay..."
		else
			puts "Connection failed!"
			exit(1)
		end
	end
end

begin
  if OPTIONS[:RunAs] == :client
  	client = UDPClient.new(OPTIONS[:Host], OPTIONS[:Port])
  	client.start
  elsif OPTIONS[:RunAs] == :server
  	server = UDPServer.new(OPTIONS[:Port])
  	server.start
  end
rescue Interrupt
  puts
  puts "Exiting..."
end
