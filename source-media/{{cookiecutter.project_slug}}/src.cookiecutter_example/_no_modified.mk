# Copy over any files at the top level to the media/ directory

.PHONY : all clean

objects = $(patsubst src/%, media/%, $(shell find src/ -depth -mindepth 1 -maxdepth 1 -type f ! -name '*.mk'))

all : $(objects)

clean :
	echo $(objects) | xargs rm -f

media/% : src/%
	cp $< $@

