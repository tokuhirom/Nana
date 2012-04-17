test:
	PERL5LIB=./util/:\$PERL5LIB  prove -l --source TCC -r -Ilib t/ t/*/*/*.tcc

.PHONY: test
