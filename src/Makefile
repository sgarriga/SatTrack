CXXFLAGS = -std=gnu++20 -pedantic -Wall -Wextra -g
INCL = -I ${HOME}/cpp-httplib
LIBS = -lsqlite3 -lpthread -ldl 

TARGET = sat-track-svr

.PHONY: all 
all: ${TARGET}

sat-track-svr: sat-track-svr.cpp handle.hpp sqlite3++.hpp glob.hpp
	@echo $@ cares about $<
	${CXX} ${CXXFLAGS} ${INCL} $< -o $@ ${LIBS}
ifneq ("$(wildcard ../$@.old)","")
	mv -f ../$@ ../$@.old
endif
	cp $@ ../

.PHONY: clean
clean:
	${RM} ${TARGET}

