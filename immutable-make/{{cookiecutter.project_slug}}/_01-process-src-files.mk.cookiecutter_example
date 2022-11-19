# Copy over any txt files at the top level to the dist/ directory

.PHONY : all clean

objects = $(patsubst src/%, dist/%, $(shell find src/ -depth -mindepth 1 -maxdepth 1 -type f -name '*.txt'))

all : $(objects)

clean :
	printf '%s\0' $(objects) | xargs -0 rm -r -f
	find dist/ -depth -mindepth 1 -type f -not -name '.gitkeep' -delete
	find dist/ -depth -mindepth 1 -type d -empty -delete

dist/% : src/%
	cp $< $@
	touch $@
