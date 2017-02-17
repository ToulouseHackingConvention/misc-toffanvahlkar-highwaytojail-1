all: solve

tmp:
	mkdir -p tmp

export:
	mkdir -p export

res:
	-ln -s ../export res

solve: capture migration

capture: res tmp export
	bin/capture_extract

migration: tmp export
	bin/migration_receive

clean:
	rm -rf res
	rm -rf tmp

clean-all: clean
	rm -rf export

.PHONY: all solve capture migration clean clean-all
