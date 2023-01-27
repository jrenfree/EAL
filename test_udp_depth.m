% Test the reading of external depth via UDP packets

clear

u = udpport("byte", "IPV4", 'LocalPort', 53306);
configureMulticast(u, '224.1.2.3');

pause(10)

udp_params = get(u);

datagramInfo = [];
if u.NumDatagramsAvailable > 0
    datagramInfo = read(u, u.NumDatagramsAvailable, 'char');
end

save('test_udp.mat', "udp_params", "datagramInfo")

clear u
