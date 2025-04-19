.ONESHELL:
MAKEFLAGS += --no-print-directory

.PHONI: docker-test

docker-test:
	@cd test && ./test.sh
