UDP Test
========

* Author: Samuel G. D. Williams (<http://www.oriontransfer.co.nz>)
* Copyright (C) 2005, 2011 Samuel G. D. Williams.
* Released under the MIT license.

UDP Test is a simple script for testing network quality. UDP is an unreliable transport
protocol, but dropped packets generally indicate network cogestion or problems. Using
UDP Test you can track errors in transmission and dropped packets, which will give you
a general idea of end to end reliablility.

The main goal was to produce a very simple testing script that can be run at two different
points of a network to test the specific reliability of a physical network link.

For more information please see the [project page][1].

[1]: http://www.oriontransfer.co.nz/projects/admin-toolbox/udp-test

Usage
-----

One one machine run the following:

	$ ./udptest.rb --server
	Server starting on port 30000

On any number of other machines run the following:

	$ ./udptest.rb --client localhost
	Connection okay...
	++++++++++++++++++++++^C
	Exiting...

On the server machine you should see the following:

	$ ./udptest.rb --server
	Server starting on port 30000
	New connection from ["AF_INET", 54475, "localhost", "127.0.0.1"]
	++++++++++++++++++++++

If there are errors they will be printed out.

