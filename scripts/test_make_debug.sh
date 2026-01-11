wget https://raw.githubusercontent.com/URV-teacher/insight-docker/master/data/Mastermind.tar.bz2 -O /tmp/Mastermind.tar.bz2
tar -xjf /tmp/Mastermind.tar.bz2
rm /tmp/Mastermind.tar.bz2

cd Mastermind
make clean
make

make debug  # Implicitly uses
