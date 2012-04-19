test:
	PERL5LIB=./util/:\$PERL5LIB  prove -l --source EGTRA --source TCC -r -Ilib t/ t/*/*/*.tcc t/*/*/*.egtra

.PHONY: test
