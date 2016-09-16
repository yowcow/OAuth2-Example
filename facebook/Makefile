.PHONY: up

all: cpanfile.snapshot

cpanfile.snapshot: cpanfile
	carton install

up: cpanfile.snapshot app.psgi
	carton exec -- plackup
