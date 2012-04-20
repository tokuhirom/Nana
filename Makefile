test:
	PERL5LIB=./util/:\$PERL5LIB  prove -l --source TRA --source EGTRA --source TCC -r -Ilib t/ t/*/*/*.tcc t/*/*/*.egtra
# t/*/*.tra

.PHONY: test
