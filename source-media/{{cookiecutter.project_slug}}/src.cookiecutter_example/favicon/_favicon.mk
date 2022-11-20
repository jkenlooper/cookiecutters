# Build a dist/favicon.ico from multiple source files.

.PHONY : all clean

intermediate_files = .tmp/favicon/.favicon-48x48.png .tmp/favicon/.favicon-64x64.png

objects = $(shell cat src/favicon/_favicon.manifest) $(intermediate_files)

all : $(objects)

clean :
	echo $(objects) | xargs rm -f

.tmp/favicon/.favicon-48x48.png : src/favicon/example-icon.svg
	mkdir -p $$(dirname $@)
	convert +antialias $< -background white -resize 48x48 $@;

.tmp/favicon/.favicon-64x64.png :  src/favicon/example-icon.svg
	mkdir -p $$(dirname $@)
	convert +antialias $< -background white -resize 64x64 $@;

dist/favicon.ico : src/favicon/favicon-16x16.png src/favicon/favicon-32x32.png $(intermediate_files)
	convert $^ $@;
