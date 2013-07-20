#!/usr/bin/env ruby

# A tool for summarizing outbound and inbound TCP connections.
# If you don't have a 256 color terminal I feel bad for you son, 
# I got 99 problems and an 8 color terminal ain't one.

PROCESS_NAME_COLOR = 27
PORT_COLOR = 110
CONNECTED_COLOR = 36
WAITING_TO_BE_CLOSED_COLOR = 181
CLOSED_COLOR = 244
LISTENING_COLOR = 69

def print_color(connection_state)
  if connection_state == '(established)'
    print("\x1b[38;5;#{CONNECTED_COLOR}m")
  elsif connection_state == '(close_wait)'
    print("\x1b[38;5;#{WAITING_TO_BE_CLOSED_COLOR}m")
  elsif connection_state == '(closed)'
    print("\x1b[38;5;#{CLOSED_COLOR}m")
  else
    print("\x1b[38;5;#{LISTENING_COLOR}m")
  end
end

def plural_or_singular(number)
  if number == 1
    "connection"
  else 
    "connections"
  end
end

lsof_result = `sudo lsof +c 0 -i -P | grep TCP`
lines = lsof_result.lines.collect { |line| line.split(' ') }
lines_grouped = lines.group_by { |line| line[0] }

connected_count = 0
waiting_to_be_closed_count = 0
closed_count = 0
listening_count = 0

lines_grouped.each do |process_name, process_connections|
  print("\x1b[38;5;#{PROCESS_NAME_COLOR}m")
  print("#{process_name} (#{process_connections[0][1]})")
  print("\x1b[0m\r\n")
 
  process_connections.sort! do |a,b|
    a[-2] <=> b[-2]
  end

  process_connections.each do |process_connection|
    # unpack the list 
    process_name, pid, user_name, 
    file_descripter, ip_type, device_id,
    size, node_type, connections, 
    connection_state = process_connection

    connection_state = connection_state.downcase()

    connections = process_connection[-2]
    if connections.include? "->"
      from, from_port, to, to_port = connections.split(/\:|\-\>/)
     
      # ignore connections from localhost to localhost from the same process
      if from.include? 'localhost' and to.include? 'localhost'
        next
      end

      if connection_state == '(established)'
        connected_count += 1
      elsif connection_state == '(close_wait)'
        waiting_to_be_closed_count += 1
      elsif connection_state == '(closed)'
        closed_count += 1
      end

      print_color(connection_state)
      print("  localhost")
      print("\x1b[0m")
      print(":")
      print_color(connection_state)
      print(from_port)
      print("\x1b[0m")

      print("\x1b[38;5;249m")
      print(" -> ")

      print_color(connection_state)
      print(to)
      print("\x1b[0m")
      print(":")
      print_color(connection_state)
      print(to_port)
      print("\x1b[0m")
      
      puts ""
    else
      listening_count += 1

      host_name, port = connections.split(':')

      print("\x1b[38;5;#{LISTENING_COLOR}m")
      print("  #{host_name}")
      print("\x1b[0m")
      print(":")
      print("\x1b[38;5;#{LISTENING_COLOR}m")
      print(port)
      print("\x1b[0m")
      
      #print("\x1b[38;5;#{CLOSED_COLOR}m")
      #print(" #{connection_state}".downcase)
      #print("\x1b[0m")
      
      print("\r\n")
    end
  end
end

puts ""
puts "Summary:"
puts "  \x1b[38;5;#{CONNECTED_COLOR}m#{connected_count} active (established) #{plural_or_singular(connected_count)}\x1b[0m"
puts "  \x1b[38;5;#{WAITING_TO_BE_CLOSED_COLOR}m#{waiting_to_be_closed_count} #{plural_or_singular(waiting_to_be_closed_count)} waiting to be closed (close_waiting)\x1b[0m"
puts "  \x1b[38;5;#{CLOSED_COLOR}m#{closed_count} recently (closed) #{plural_or_singular(closed_count)}\x1b[0m"
puts "  \x1b[38;5;#{LISTENING_COLOR}m#{listening_count} ports (listening) for #{plural_or_singular(listening_count)}\x1b[0m"
puts ""

