CXX = $(shell fltk-config --cxx)
CXXFLAGS = $(shell fltk-config --cxxflags ) -I.
LDFLAGS = $(shell fltk-config --ldflags )
LDSTATIC = $(shell fltk-config --ldstaticflags )
LINK = $(CXX)

.SUFFIXES: .o .cxx .c
%.o: %.cxx hl2.h
	$(CXX) $(CXXFLAGS) -c $<

hl2setup: hl2setup.o hl2.o discover.o
	$(LINK) -no-pie -o hl2setup hl2setup.o hl2.o discover.o $(LDSTATIC)

win:
	echo "Use visual c++ to make the project"

clean:
	rm -f *.o 2> /dev/null
	rm -f hl2setup 2> /dev/null
