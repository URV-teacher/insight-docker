wget https://raw.githubusercontent.com/URV-teacher/insight-docker/master/data/Mastermind.tar.bz2 -O /tmp/Mastermind.tar.bz2
tar -xjf /tmp/Mastermind.tar.bz2
rm /tmp/Mastermind.tar.bz2

cd Mastermind
make clean
make

# Being in the same working directory as the project root that we are debugging is important to let insight see the
# source code.
desmume --gdbport=1024 Mastermind.nds &
insight Mastermind.elf  # Also gdb-multiarch or arm-none-eabi-gdb should work
