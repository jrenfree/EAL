% Test the reading of external depth via UDP packets

clear

u = udpport("datagram", "IPV4", 'LocalPort', 53306);
configureMulticast(u, '224.1.2.3');

pause(10)

save('test_udp.mat', "u")

clear u