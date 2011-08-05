#!/usr/bin/env ruby

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