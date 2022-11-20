# Copy over any files at the top level to the dist/ directory

.PHONY : all clean

objects = $(patsubst src/%, dist/%, $(shell find src/ -depth -mindepth 1 -maxdepth 1 -type f ! -name '*.mk'))

all : $(objects)

clean :
	echo $(objects) | xargs rm -f

dist/% : src/%
	cp $< $@

