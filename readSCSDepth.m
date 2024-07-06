SCS = tcpclient('10.48.23.223', 2006);

flush(SCS)
depth = str2double(readline(SCS));

clear SCS