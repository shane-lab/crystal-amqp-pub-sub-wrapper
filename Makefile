ifndef VERBOSE
.SILENT:
endif

SPEC_FILES = $(wildcard ./spec/*_spec.cr)

.PHONY: coverage
coverage: 
	if [ ! -z $(SPEC_FILES) ] ; \
	then \
		if [ -d ./coverage ] ; then echo rm -rf ./coverage; fi; \
		if [ -f ./bin/crystal-coverage ] ; \
		then \
			./bin/crystal-coverage $(SPEC_FILES); \
		else \
			echo 'Crystal coverage not found, try running "shards install"' ; \
		fi; \
	else \
		echo 'No spec files to run code coverage on'; \
	fi;

test:
	if [ ! -z $(SPEC_FILES) ] ; \
	then \
		crystal spec $(SPEC_FILES); \
	else \
		echo 'No spec files to run tests for'; \
	fi;